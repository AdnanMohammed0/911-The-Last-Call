extends GutTest


func after_each() -> void:
	TraitSystem.reset_player(1)


func _player(class_id: StringName) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.peer_id = 1
	player.apply_class(ClassCatalog.get_data(class_id))
	add_child_autofree(player)
	player.set_physics_process(false)
	player.set_process(false)
	return player


func test_bands_use_class_maximum() -> void:
	assert_eq(SanitySystem.band_for(100.0, 100.0), SanitySystem.Band.STEADY)
	assert_eq(SanitySystem.band_for(69.0, 100.0), SanitySystem.Band.UNEASY)
	assert_eq(SanitySystem.band_for(39.0, 100.0), SanitySystem.Band.PANICKED)
	assert_eq(SanitySystem.band_for(14.0, 100.0), SanitySystem.Band.BROKEN)
	assert_eq(SanitySystem.band_for(52.0, 130.0), SanitySystem.Band.UNEASY)


func test_class_drain_and_restore_clamp() -> void:
	var medic: Player = _player(&"medic")
	assert_eq(medic.max_sanity, 130.0)
	assert_eq(medic.sanity, 130.0)
	medic.apply_sanity_damage(10.0, &"anomaly")
	assert_almost_eq(medic.sanity, 123.0, 0.01)
	medic.restore_sanity(35.0)
	assert_eq(medic.sanity, 130.0)


func test_sfx_passes_through_local_panic_bus() -> void:
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	var panic: int = AudioServer.get_bus_index(&"Panic")
	assert_gt(sfx, panic)
	assert_eq(AudioServer.get_bus_send(sfx), &"Panic")
	assert_true(AudioServer.get_bus_effect(panic, 0) is AudioEffectLowPassFilter)
	assert_true(AudioServer.get_bus_effect(panic, 1) is AudioEffectReverb)


func test_only_marked_darkness_drains() -> void:
	assert_eq(SanitySystem._zone_at(Vector3.ZERO), 0)
	var zone: Area3D = Area3D.new()
	zone.name = "DarkTestZone"
	zone.add_to_group(&"light_zones")
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	shape.shape = box
	zone.add_child(shape)
	add_child_autofree(zone)
	assert_eq(SanitySystem._zone_at(Vector3.ZERO), -1)
	assert_eq(SanitySystem._zone_at(Vector3(10, 0, 0)), 0)
