## P3-01: weapon data, ballistics, default loadouts, host-validated fire, reload, lag compensation.
extends GutTest

var _world: Node3D
var _player: Player
var _weapons: WeaponHolder


func _spawn_player(class_id: StringName) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.apply_class(ClassCatalog.get_data(class_id))
	_world.add_child(player)
	player.set_physics_process(false)
	player.get_weapons().set_physics_process(false)
	return player


func _hostile(at: Vector3) -> HostileAgent:
	var hostile: HostileAgent = (load("res://scenes/field/enemies/hostile.tscn") as PackedScene).instantiate() as HostileAgent
	hostile.archetype = load("res://data/ai/archetypes/thug.tres") as ArchetypeData
	_world.add_child(hostile)
	hostile.runner.enabled = false
	hostile.set_physics_process(false)
	hostile.global_position = at
	return hostile


## Unit direction from the player's eyes to a point `height` above `feet`.
func _aim_at(feet: Vector3, height: float) -> Vector3:
	return (feet + Vector3(0, height, 0) - _player.get_eye_position()).normalized()


func _fire(slot: int, directions: PackedVector3Array, rewind_msec: int = 0, sender: int = 1) -> bool:
	return _weapons.host_fire(sender, slot, _player.get_eye_position(), directions, rewind_msec)


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	_player = _spawn_player(&"tech")
	_weapons = _player.get_weapons()
	_weapons.give_loadout(WeaponCatalog.default_loadout(ClassCatalog.get_data(&"tech")))
	_weapons.active_slot = WeaponData.Slot.PRIMARY


# --- Data / maths ----------------------------------------------------------------------

func test_catalog_weapons_load() -> void:
	for id: StringName in WeaponCatalog.ids():
		var data: WeaponData = WeaponCatalog.get_data(id)
		assert_not_null(data, String(id))
		assert_eq(data.id, id)
		assert_gt(data.recoil_pattern.size(), 0, "%s has a recoil pattern" % id)


func test_damage_falloff() -> void:
	var rifle: WeaponData = WeaponCatalog.get_data(&"rifle")
	assert_eq(rifle.damage_at(1.0), rifle.damage)
	assert_almost_eq(rifle.damage_at(rifle.max_range), rifle.damage * rifle.falloff_min_ratio, 0.01)
	assert_lt(rifle.damage_at((rifle.falloff_start + rifle.max_range) * 0.5), rifle.damage)


func test_recoil_pattern_repeats() -> void:
	var smg: WeaponData = WeaponCatalog.get_data(&"smg")
	assert_eq(smg.recoil_for_shot(0), smg.recoil_for_shot(smg.recoil_pattern.size()))
	assert_ne(smg.recoil_for_shot(0), smg.recoil_for_shot(1))


func test_ray_capsule_hit_and_miss() -> void:
	var feet: Vector3 = Vector3(0, 0, -10)
	assert_almost_eq(Ballistics.ray_capsule(Vector3(0, 1.2, 0), Vector3.FORWARD, feet), 10.0 - Ballistics.TARGET_RADIUS, 0.02)
	assert_eq(Ballistics.ray_capsule(Vector3(1.0, 1.2, 0), Vector3.FORWARD, feet), INF, "passes beside")
	assert_eq(Ballistics.ray_capsule(Vector3(0, 2.5, 0), Vector3.FORWARD, feet), INF, "passes above")
	assert_eq(Ballistics.ray_capsule(Vector3(0, 1.2, 0), Vector3.BACK, feet), INF, "target behind")


func test_hit_zones() -> void:
	var feet: Vector3 = Vector3.ZERO
	assert_eq(Ballistics.zone_for_point(feet, Vector3(0, 1.65, 0), 0.0), HealthComponent.HitZone.HEAD)
	assert_eq(Ballistics.zone_for_point(feet, Vector3(0, 1.2, 0), 0.0), HealthComponent.HitZone.TORSO)
	assert_eq(Ballistics.zone_for_point(feet, Vector3(0.33, 1.2, 0), 0.0), HealthComponent.HitZone.ARM)
	assert_eq(Ballistics.zone_for_point(feet, Vector3(0, 0.4, 0), 0.0), HealthComponent.HitZone.LEG)


func test_spread_stays_inside_cone() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 200:
		var direction: Vector3 = Ballistics.spread_direction(Vector3.FORWARD, 3.0, rng)
		assert_true(direction.is_normalized())
		assert_lte(rad_to_deg(direction.angle_to(Vector3.FORWARD)), 3.001)


func test_default_loadouts_follow_class_access() -> void:
	var tech: StringName = WeaponCatalog.default_loadout(ClassCatalog.get_data(&"tech")).get(WeaponData.Slot.PRIMARY, &"")
	var breacher: StringName = WeaponCatalog.default_loadout(ClassCatalog.get_data(&"breacher")).get(WeaponData.Slot.PRIMARY, &"")
	assert_eq(tech, &"smg")
	assert_eq(breacher, &"shotgun")
	assert_false(WeaponCatalog.default_loadout(ClassCatalog.get_data(&"medic")).has(WeaponData.Slot.PRIMARY))
	assert_false(WeaponCatalog.get_data(&"smg").is_allowed_for(&"breacher"), "smg is tech only")
	assert_eq(_weapons.sidearm_id, &"pistol")
	assert_eq(_weapons.primary_id, &"smg")
	assert_eq(_weapons.primary_mag, WeaponCatalog.get_data(&"smg").magazine_size)
	assert_eq(_weapons.active_slot, WeaponData.Slot.PRIMARY)
	var fresh: Player = _spawn_player(&"breacher")
	assert_false(fresh.get_weapons().has_weapon(WeaponData.Slot.PRIMARY), "players spawn unarmed")
	assert_false(fresh.get_weapons().has_weapon(WeaponData.Slot.SIDEARM))


# --- Host validation ---------------------------------------------------------------------

func test_host_fire_hits_hostile_and_spends_ammo() -> void:
	var hostile: HostileAgent = _hostile(Vector3(0, 0, -8))
	var pistol: WeaponData = WeaponCatalog.get_data(&"pistol")
	assert_true(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([_aim_at(hostile.global_position, 1.2)])))
	assert_eq(_weapons.sidearm_mag, pistol.magazine_size - 1)
	assert_almost_eq(hostile.hp, 100.0 - pistol.damage, 0.01)


func test_headshot_doubles_damage() -> void:
	var hostile: HostileAgent = _hostile(Vector3(0, 0, -8))
	var pistol: WeaponData = WeaponCatalog.get_data(&"pistol")
	assert_true(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([_aim_at(hostile.global_position, 1.66)])))
	assert_almost_eq(hostile.hp, 100.0 - pistol.damage * 2.0, 0.01)


func test_hit_confirm_and_kill() -> void:
	var hostile: HostileAgent = _hostile(Vector3(0, 0, -6))
	hostile.hp = 10.0
	watch_signals(_weapons)
	assert_true(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([_aim_at(hostile.global_position, 1.2)])))
	assert_true(hostile.is_dead)
	assert_signal_emitted_with_parameters(_weapons, "hit_confirmed", [true, false])


func test_rejects_other_sender_bad_origin_and_pellets() -> void:
	var hostile: HostileAgent = _hostile(Vector3(0, 0, -8))
	var direction: PackedVector3Array = PackedVector3Array([_aim_at(hostile.global_position, 1.2)])
	assert_false(_fire(WeaponData.Slot.SIDEARM, direction, 0, 2), "not the owner")
	assert_false(_weapons.host_fire(1, WeaponData.Slot.SIDEARM, _player.get_eye_position() + Vector3(0, 0, -5), direction, 0), "origin far from eyes")
	assert_false(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([direction[0], direction[0]])), "pistol fires one pellet")
	assert_false(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([Vector3.BACK])), "shooting behind the view")
	assert_eq(hostile.hp, 100.0)
	assert_eq(_weapons.sidearm_mag, WeaponCatalog.get_data(&"pistol").magazine_size, "rejected shots cost nothing")


func test_rejects_faster_than_fire_rate() -> void:
	var direction: PackedVector3Array = PackedVector3Array([Vector3.FORWARD])
	assert_true(_fire(WeaponData.Slot.SIDEARM, direction))
	assert_false(_fire(WeaponData.Slot.SIDEARM, direction), "pistol interval 0.2 s")
	await wait_seconds(0.3)
	assert_true(_fire(WeaponData.Slot.SIDEARM, direction))


func test_empty_magazine_cannot_fire_and_medic_has_no_primary() -> void:
	_weapons.sidearm_mag = 0
	assert_false(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([Vector3.FORWARD])))
	var medic: Player = _spawn_player(&"medic")
	assert_false(medic.get_weapons().host_fire(1, WeaponData.Slot.PRIMARY, medic.get_eye_position(), PackedVector3Array([Vector3.FORWARD]), 0))


func test_walls_block_shots() -> void:
	var hostile: HostileAgent = _hostile(Vector3(0, 0, -8))
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_position = Vector3(0, 1, -4)
	await wait_physics_frames(2)
	assert_true(_fire(WeaponData.Slot.SIDEARM, PackedVector3Array([_aim_at(hostile.global_position, 1.2)])))
	assert_eq(hostile.hp, 100.0)


func test_shotgun_pellets_add_up() -> void:
	_weapons.set_weapon(WeaponData.Slot.PRIMARY, &"shotgun")
	var shotgun: WeaponData = WeaponCatalog.get_data(&"shotgun")
	var hostile: HostileAgent = _hostile(Vector3(0, 0, -5))
	hostile.hp = 1000.0
	var directions: PackedVector3Array = PackedVector3Array()
	for i: int in shotgun.pellets:
		directions.append(_aim_at(hostile.global_position, 1.1))
	assert_true(_fire(WeaponData.Slot.PRIMARY, directions))
	assert_almost_eq(hostile.hp, 1000.0 - shotgun.damage * shotgun.pellets, 0.1)


# --- Reload ------------------------------------------------------------------------------

func test_reload_moves_reserve_into_magazine() -> void:
	var smg: WeaponData = WeaponCatalog.get_data(&"smg")
	_weapons.primary_mag = 4
	assert_true(_weapons.host_reload(1, WeaponData.Slot.PRIMARY))
	assert_false(_fire(WeaponData.Slot.PRIMARY, PackedVector3Array([Vector3.FORWARD])), "no firing mid-reload")
	_weapons.host_tick(smg.reload_seconds * 0.5)
	assert_eq(_weapons.primary_mag, 4, "not done yet")
	_weapons.host_tick(smg.reload_seconds)
	assert_eq(_weapons.primary_mag, smg.magazine_size)
	assert_eq(_weapons.primary_reserve, smg.max_reserve - (smg.magazine_size - 4))
	assert_eq(_weapons.reloading_slot, WeaponHolder.NO_SLOT)


func test_reload_rules() -> void:
	assert_false(_weapons.host_reload(1, WeaponData.Slot.PRIMARY), "magazine already full")
	_weapons.primary_mag = 0
	_weapons.primary_reserve = 0
	assert_false(_weapons.host_reload(1, WeaponData.Slot.PRIMARY), "no reserve")
	_weapons.primary_reserve = 10
	assert_false(_weapons.host_reload(2, WeaponData.Slot.PRIMARY), "not the owner")
	assert_true(_weapons.host_reload(1, WeaponData.Slot.PRIMARY))
	_weapons.active_slot = WeaponData.Slot.SIDEARM
	_weapons.host_tick(0.1)
	assert_eq(_weapons.reloading_slot, WeaponHolder.NO_SLOT, "switching weapons cancels the reload")
	assert_eq(_weapons.primary_mag, 0)


# --- Lag compensation --------------------------------------------------------------------

func test_lag_compensation_rewinds_moving_target() -> void:
	var old_feet: Vector3 = Vector3(0, 0, -10)
	var hostile: HostileAgent = _hostile(Vector3(3, 0, -10))
	var now: int = Time.get_ticks_msec()
	LagCompensation._history[hostile.get_instance_id()] = [[now - 400, old_feet], [now - 200, old_feet], [now, hostile.global_position]]
	var direction: Vector3 = _aim_at(old_feet, 1.2)
	var present: Dictionary = _weapons.resolve_shot(_player.get_eye_position(), direction, 100.0, 0)
	assert_false(present.has("target"), "target has moved away now")
	var rewound: Dictionary = _weapons.resolve_shot(_player.get_eye_position(), direction, 100.0, 250)
	var target: Object = rewound.get("target")
	assert_eq(target, hostile, "the shooter saw it 250 ms ago")


func test_lag_compensation_interpolates_and_caps() -> void:
	var hostile: HostileAgent = _hostile(Vector3(4, 0, 0))
	var now: int = Time.get_ticks_msec()
	LagCompensation._history[hostile.get_instance_id()] = [[now - 200, Vector3.ZERO], [now, Vector3(4, 0, 0)]]
	var mid: Vector3 = LagCompensation.position_at(hostile, 100)
	assert_almost_eq(mid.x, 2.0, 0.6)
	assert_eq(LagCompensation.position_at(hostile, 0), hostile.global_position)
	assert_eq(LagCompensation.rewind_msec_for(multiplayer.get_unique_id()), 0, "host shots are not rewound")
