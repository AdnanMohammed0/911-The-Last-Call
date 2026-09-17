## Stage 2 loop: verdict → response, armory gear, armor, loadout carry-over, objective, extraction, wipe.
extends GutTest

var _world: Node3D


func _player(class_id: StringName, peer: int = 1) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.apply_class(ClassCatalog.get_data(class_id))
	player.peer_id = peer
	_world.add_child(player)
	player.set_physics_process(false)
	player.get_weapons().set_physics_process(false)
	return player


func _rack(kind: ArmoryItem.Kind, weapon: StringName = &"rifle") -> ArmoryItem:
	var item: ArmoryItem = ArmoryItem.new()
	item.kind = kind
	item.weapon_id = weapon
	_world.add_child(item)
	return item


func before_each() -> void:
	MissionDirector.reset()
	MissionDirector.scene_changes_enabled = false
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	MissionDirector.reset()
	MissionDirector.scene_changes_enabled = true
	GameState.reset()


func test_genuine_and_ambush_verdicts_open_a_response() -> void:
	EventBus.call_classified.emit(&"call_x", &"prank")
	assert_eq(MissionDirector.state, MissionDirector.State.IDLE, "pranks do not deploy")
	EventBus.call_classified.emit(&"call_x", &"genuine")
	assert_eq(MissionDirector.state, MissionDirector.State.RESPONSE)
	assert_string_contains(MissionDirector.objective_text, "armory")
	var genuine: float = MissionDirector.difficulty
	MissionDirector.reset()
	EventBus.call_classified.emit(&"call_y", &"ambush")
	assert_gt(MissionDirector.difficulty, genuine, "ambushes are tougher")


func test_deploy_requires_response() -> void:
	assert_false(MissionDirector.deploy())
	MissionDirector.start_response(&"call_x", &"genuine")
	assert_true(MissionDirector.deploy())
	assert_eq(MissionDirector.state, MissionDirector.State.DEPLOYED)
	assert_eq(GameState.phase, GameState.Phase.FIELD)


func test_weapon_rack_respects_class() -> void:
	var breacher: Player = _player(&"breacher")
	var rifle: ArmoryItem = _rack(ArmoryItem.Kind.WEAPON, &"rifle")
	var smg: ArmoryItem = _rack(ArmoryItem.Kind.WEAPON, &"smg")
	assert_true(rifle._can_interact(1))
	rifle._on_interact(1)
	assert_eq(breacher.get_weapons().primary_id, &"rifle")
	assert_eq(breacher.get_weapons().primary_mag, WeaponCatalog.get_data(&"rifle").magazine_size)
	assert_false(smg._can_interact(1), "SMG is Tech only")
	assert_string_contains(smg.get_prompt_text(), "only")


func test_ammo_crate_refills() -> void:
	var tech: Player = _player(&"tech")
	tech.get_weapons().primary_mag = 2
	tech.get_weapons().primary_reserve = 0
	_rack(ArmoryItem.Kind.AMMO)._on_interact(1)
	assert_eq(tech.get_weapons().primary_mag, 30)
	assert_eq(tech.get_weapons().primary_reserve, WeaponCatalog.get_data(&"smg").max_reserve)


func test_armor_absorbs_body_hits_not_head() -> void:
	var medic: Player = _player(&"medic")  # 5 % resistance
	var health: HealthComponent = medic.get_health()
	_rack(ArmoryItem.Kind.ARMOR)._on_interact(1)
	assert_eq(health.armor, HealthComponent.MAX_ARMOR)
	var taken: float = health.apply_damage(40.0, HealthComponent.HitZone.TORSO)
	assert_almost_eq(taken, 40.0 * 0.95 * (1.0 - HealthComponent.ARMOR_ABSORB), 0.01)
	assert_lt(health.armor, HealthComponent.MAX_ARMOR)
	var armor_before: float = health.armor
	health.apply_damage(10.0, HealthComponent.HitZone.HEAD)
	assert_eq(health.armor, armor_before, "head shots bypass the vest")


func test_loadout_survives_level_change() -> void:
	var breacher: Player = _player(&"breacher")
	breacher.get_weapons().set_weapon(WeaponData.Slot.PRIMARY, &"rifle")
	breacher.get_weapons().primary_mag = 11
	breacher.get_health().give_armor(60.0)
	MissionDirector.save_loadouts()
	breacher.free()
	var again: Player = _player(&"breacher")
	assert_eq(again.get_weapons().primary_id, &"rifle", "not the class default shotgun")
	assert_eq(again.get_weapons().primary_mag, 11)
	assert_eq(again.get_health().armor, 60.0)


func test_scaled_archetypes_are_harder_and_do_not_touch_the_original() -> void:
	var base: ArchetypeData = load("res://data/ai/archetypes/cultist_gunman.tres") as ArchetypeData
	var hard: ArchetypeData = EnemySpawner.scaled_archetype(base, 1.35)
	assert_ne(hard, base)
	assert_gt(hard.max_hp, base.max_hp)
	assert_gt(hard.accuracy, base.accuracy)
	assert_gt(hard.damage, base.damage)
	assert_eq(base.max_hp, 120.0)
	assert_eq(EnemySpawner.scaled_archetype(base, 1.0), base)


func test_objective_secured_then_extraction() -> void:
	MissionDirector.start_response(&"call_x", &"genuine")
	MissionDirector.deploy()
	MissionDirector.report_hostiles(3, 5)
	assert_eq(MissionDirector.hostiles_left, 3)
	assert_eq(MissionDirector.state, MissionDirector.State.DEPLOYED)
	assert_false(MissionDirector.extract(), "cannot leave before the area is secured")
	MissionDirector.report_hostiles(0, 5)
	assert_eq(MissionDirector.state, MissionDirector.State.SECURED)
	var trust: int = GameState.public_trust
	assert_true(MissionDirector.extract())
	assert_eq(GameState.public_trust, trust + MissionDirector.TRUST_SUCCESS)
	assert_eq(MissionDirector.state, MissionDirector.State.IDLE)
	assert_eq(GameState.phase, GameState.Phase.DISPATCH)


func test_mission_controller_extracts_team_at_van() -> void:
	var player: Player = _player(&"tech")
	var van: Marker3D = Marker3D.new()
	_world.add_child(van)
	van.global_position = Vector3(20, 0, 0)
	var controller: MissionController = MissionController.new()
	controller.extraction_point = van
	controller.start_response_if_idle = false
	_world.add_child(controller)
	MissionDirector.start_response(&"call_x", &"genuine")
	MissionDirector.deploy()
	MissionDirector.report_hostiles(0, 2)
	assert_false(controller._team_at_extraction())
	player.global_position = Vector3(19, 0, 1)
	assert_true(controller._team_at_extraction())


func test_team_wipe_fails_the_mission() -> void:
	var player: Player = _player(&"medic")
	MissionDirector.start_response(&"call_x", &"genuine")
	MissionDirector.deploy()
	player.get_health().apply_damage(1000.0)
	var trust: int = GameState.public_trust
	MissionDirector._process(MissionDirector.WIPE_GRACE_SEC + 0.1)
	assert_eq(MissionDirector.state, MissionDirector.State.FAILED)
	assert_eq(GameState.public_trust, trust + MissionDirector.TRUST_FAILURE)


func test_deploy_door_locked_until_response() -> void:
	var door: DeployDoor = DeployDoor.new()
	_world.add_child(door)
	assert_false(door._can_interact(1))
	assert_string_contains(door.get_prompt_text(), "locked")
	MissionDirector.start_response(&"call_x", &"genuine")
	assert_true(door._can_interact(1))
	door._on_interact(1)
	assert_eq(MissionDirector.state, MissionDirector.State.DEPLOYED)
