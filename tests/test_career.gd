## Progression: XP, ranks, rank-locked armory gear, promotions and the shout → surrender → arrest chain.
extends GutTest

var _world: Node3D


func _player(class_id: StringName) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.apply_class(ClassCatalog.get_data(class_id))
	_world.add_child(player)
	player.set_physics_process(false)
	player.get_weapons().set_physics_process(false)
	return player


func _hostile(archetype_id: StringName, at: Vector3) -> HostileAgent:
	var hostile: HostileAgent = (load("res://scenes/field/enemies/hostile.tscn") as PackedScene).instantiate() as HostileAgent
	hostile.archetype = load("res://data/ai/archetypes/%s.tres" % archetype_id) as ArchetypeData
	_world.add_child(hostile)
	hostile.runner.enabled = false
	hostile.set_physics_process(false)
	hostile.global_position = at
	return hostile


func before_each() -> void:
	Career.persist = false
	Career.reset()
	MissionDirector.reset()
	MissionDirector.scene_changes_enabled = false
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	Career.reset()
	MissionDirector.reset()
	MissionDirector.scene_changes_enabled = true


# --- Ranks ---------------------------------------------------------------------------------

func test_ranks_climb_with_xp() -> void:
	assert_eq(Career.rank_for_xp(0), 0)
	assert_eq(Career.rank_name(0), "Rookie")
	assert_eq(Career.rank_for_xp(250), 1)
	assert_eq(Career.rank_for_xp(249), 0)
	assert_eq(Career.rank_for_xp(999999), Career.RANKS.size() - 1)
	assert_eq(Career.rank_name(Career.RANKS.size() - 1), "Captain")


func test_award_tracks_stats_and_never_goes_negative() -> void:
	Career.award(1, 120, "Suspect neutralized", "kills")
	assert_eq(Career.xp, 120)
	var kills: int = Career.stats.get("kills", 0)
	assert_eq(kills, 1)
	Career.award(1, -500, "Unlawful kill")
	assert_eq(Career.xp, 0, "XP floors at zero")


func test_promotion_reports_unlocked_gear() -> void:
	var promotions: Array[String] = []
	var unlocked: Array[String] = []
	Career.promoted.connect(func(_rank: int, rank_title: String, unlocks: PackedStringArray) -> void:
		promotions.append(rank_title)
		unlocked.append_array(unlocks))
	Career.award(1, 260, "Shift complete")
	assert_eq(promotions, ["Officer"] as Array[String])
	assert_true(unlocked.has("Pump Shotgun"), "the shotgun unlocks at Officer: %s" % str(unlocked))
	assert_true(unlocked.has("Ballistic vest"))


func test_rank_bounds_for_the_xp_bar() -> void:
	Career.award(1, 300, "test")
	var bounds: Vector2i = Career.rank_bounds()
	assert_eq(bounds.x, 250)
	assert_eq(bounds.y, 700)


# --- Rank-locked armory --------------------------------------------------------------------

func test_armory_locks_gear_behind_rank() -> void:
	var breacher: Player = _player(&"breacher")
	var rifle: ArmoryItem = ArmoryItem.new()
	rifle.kind = ArmoryItem.Kind.WEAPON
	rifle.weapon_id = &"rifle"
	_world.add_child(rifle)
	var pistol: ArmoryItem = ArmoryItem.new()
	pistol.kind = ArmoryItem.Kind.WEAPON
	pistol.weapon_id = &"pistol"
	_world.add_child(pistol)
	assert_true(pistol._can_interact(1), "a rookie can always draw a pistol")
	assert_false(rifle._can_interact(1), "the rifle needs rank")
	assert_string_contains(rifle.get_prompt_text(), "requires rank")
	var needed: int = Career.RANKS[Career.required_rank(&"rifle")][0]
	Career.award(1, needed, "test")
	Career.report_rank()
	assert_true(rifle._can_interact(1))
	rifle._on_interact(1)
	assert_eq(breacher.get_weapons().primary_id, &"rifle")


func test_dropped_weapons_are_never_rank_locked() -> void:
	_player(&"breacher")
	var pickup_name: String = WorldItems.spawn_weapon(&"rifle", 30, 90, Vector3.ZERO, 0.0)
	var pickup: WeaponPickup = WorldItems.find(pickup_name)
	assert_true(pickup._can_interact(1), "field pickups ignore rank")
	WorldItems.remove(pickup_name)
	await wait_frames(2)


# --- Shout → surrender → arrest ------------------------------------------------------------

func test_shout_makes_an_unarmed_caller_give_up_and_be_arrested() -> void:
	var officer: Player = _player(&"breacher")
	officer.global_position = Vector3.ZERO
	var prankster: HostileAgent = _hostile(&"prankster", Vector3(0, 0, -4))
	assert_false(prankster.archetype.armed, "prank callers carry nothing")
	await wait_physics_frames(2)
	assert_eq(officer.host_shout(1), 1, "the suspect heard us")
	assert_true(prankster.negotiated, "they are ready to give up")
	assert_true(prankster.cond_should_surrender(prankster.runner.blackboard))
	prankster.act_surrender(prankster.runner.blackboard)
	assert_true(prankster.is_surrendered)
	var arrest: HostileArrest = prankster.get_node("Arrest") as HostileArrest
	assert_string_contains(arrest.get_prompt_text(), "Arrest")
	var arrested: Array[int] = []
	EventBus.suspect_arrested.connect(func(_h: Node, by: int) -> void: arrested.append(by))
	assert_true(arrest._can_interact(1))
	arrest._on_interact(1)
	assert_true(prankster.is_arrested)
	assert_false(prankster.is_active(), "an arrested suspect is out of the fight")
	assert_eq(arrested, [1] as Array[int])
	assert_false(arrest._can_interact(1), "cannot arrest twice")


func test_shout_needs_line_of_sight_and_range() -> void:
	var officer: Player = _player(&"breacher")
	officer.global_position = Vector3.ZERO
	var far_away: HostileAgent = _hostile(&"thug", Vector3(0, 0, -40))
	await wait_physics_frames(2)
	assert_eq(officer.host_shout(1), 0, "too far to hear")
	far_away.global_position = Vector3(0, 0, -6)
	officer._host_next_shout_msec = 0   # skip the anti-spam cooldown
	await wait_physics_frames(2)
	var morale_before: float = far_away.morale
	assert_eq(officer.host_shout(1), 1)
	assert_lt(far_away.morale, morale_before, "shouting breaks their nerve")


func test_killing_a_surrendered_suspect_is_unlawful() -> void:
	var prankster: HostileAgent = _hostile(&"prankster", Vector3(0, 0, -3))
	prankster.morale = 0.0
	prankster.negotiated = true
	prankster.act_surrender(prankster.runner.blackboard)
	prankster.take_damage(500.0, HealthComponent.HitZone.TORSO, 1)
	assert_true(prankster.is_dead)
	assert_true(prankster.killed_unlawfully, "shooting someone who gave up is recorded")


func test_fanatics_ignore_the_shout() -> void:
	var officer: Player = _player(&"breacher")
	officer.global_position = Vector3.ZERO
	var zealot: HostileAgent = _hostile(&"zealot", Vector3(0, 0, -5))
	await wait_physics_frames(2)
	var morale_before: float = zealot.morale
	officer.host_shout(1)
	assert_eq(zealot.morale, morale_before, "a fanatic does not care")
	assert_false(zealot.cond_should_surrender(zealot.runner.blackboard))
