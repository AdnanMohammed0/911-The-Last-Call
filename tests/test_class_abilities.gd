extends GutTest


func after_each() -> void:
	LoadoutManager._player_loadouts.erase(1)


func _player(class_id: StringName) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.peer_id = 1
	player.apply_class(ClassCatalog.get_data(class_id))
	add_child_autofree(player)
	player.set_physics_process(false)
	player.set_process(false)
	return player


func test_each_class_has_distinct_field_slots() -> void:
	assert_eq(ClassAbilities.ability_label(&"tech", 0), "Recon drone")
	assert_eq(ClassAbilities.ability_label(&"profiler", 0), "Megaphone")
	assert_eq(ClassAbilities.ability_label(&"breacher", 0), "Ballistic shield")
	assert_eq(ClassAbilities.ability_label(&"medic", 2), "Reverse tone")
	assert_eq(ClassAbilities.ability_label(&"tech", 2), "")


func test_medic_sedative_consumes_charge_without_refund() -> void:
	var medic: Player = _player(&"medic")
	var abilities: ClassAbilities = medic.get_node(^"ClassAbilities") as ClassAbilities
	LoadoutManager._player_loadouts[1] = {&"sedatives": 1}
	medic.sanity = 50.0
	var budget: int = LoadoutManager.get_budget()
	assert_true(abilities.host_use(0))
	assert_eq(medic.sanity, 85.0)
	var remaining: int = LoadoutManager.get_player_loadout(1).get(&"sedatives", 0)
	assert_eq(remaining, 0)
	assert_eq(LoadoutManager.get_budget(), budget)
	assert_false(abilities.host_use(0), "Charge and cooldown prevent replay")


func test_shield_blocks_only_front_bullets_and_breaks() -> void:
	var breacher: Player = _player(&"breacher")
	var abilities: ClassAbilities = breacher.get_node(^"ClassAbilities") as ClassAbilities
	LoadoutManager._player_loadouts[1] = {&"ballistic_shield": 1}
	assert_true(abilities.host_use(0))
	assert_true(abilities.shield_raised)
	assert_true(abilities.blocks_bullet(breacher.global_position + Vector3(0, 0, -4)))
	assert_false(abilities.blocks_bullet(breacher.global_position + Vector3(0, 0, 4)))
	var hp: float = breacher.get_health().hp
	assert_eq(breacher.get_health().apply_damage(20.0, HealthComponent.HitZone.TORSO, 0, breacher.global_position + Vector3(0, 0, -4)), 0.0)
	assert_eq(breacher.get_health().hp, hp)
	assert_gt(breacher.get_health().apply_damage(20.0, HealthComponent.HitZone.TORSO, 0, breacher.global_position + Vector3(0, 0, 4)), 0.0)
	abilities.absorb_bullet(580.0)
	assert_eq(abilities.shield_hp, 0.0)
	assert_false(abilities.shield_raised)


func test_tech_drone_requires_gear_and_respects_cooldown() -> void:
	var tech: Player = _player(&"tech")
	var abilities: ClassAbilities = tech.get_node(^"ClassAbilities") as ClassAbilities
	assert_false(abilities.host_use(0))
	LoadoutManager._player_loadouts[1] = {&"recon_drone": 1}
	assert_true(abilities.host_use(0))
	assert_not_null(abilities._drone)
	assert_false(abilities.host_use(0))


func test_breacher_kick_has_a_host_cooldown() -> void:
	var breacher: Player = _player(&"breacher")
	var abilities: ClassAbilities = breacher.get_node(^"ClassAbilities") as ClassAbilities
	assert_true(abilities.spend_kick())
	assert_false(abilities.spend_kick())
	abilities._next_kick_msec = 0
	assert_true(abilities.spend_kick())


func test_medic_gadgets_exist_only_for_medic() -> void:
	var medic: Player = _player(&"medic")
	var medic_abilities: ClassAbilities = medic.get_node(^"ClassAbilities") as ClassAbilities
	assert_not_null(medic_abilities._salt)
	assert_not_null(medic_abilities._tone)
	var tech: Player = _player(&"tech")
	var tech_abilities: ClassAbilities = tech.get_node(^"ClassAbilities") as ClassAbilities
	assert_null(tech_abilities._salt)
	assert_null(tech_abilities._tone)


func test_medic_salt_barrier_expires_with_its_visual() -> void:
	var medic: Player = _player(&"medic")
	var abilities: ClassAbilities = medic.get_node(^"ClassAbilities") as ClassAbilities
	var salt: SaltCanister = abilities._salt
	salt.line_duration = 0.05
	LoadoutManager._player_loadouts[1] = {&"salt_canister": 1}
	assert_true(abilities.host_use(1), "the first deployment is available immediately")
	var line: Node = salt._active_line
	assert_not_null(line)
	var barrier: Node = line.get_node_or_null(^"SaltBarrier")
	assert_not_null(barrier)
	await wait_physics_frames(8)
	assert_false(is_instance_valid(line), "the salt visual expires")
	assert_false(is_instance_valid(barrier), "the anomaly barrier expires with it")
