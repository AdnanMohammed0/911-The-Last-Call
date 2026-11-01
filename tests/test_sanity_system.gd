extends GutTest


func after_each() -> void:
	TraitSystem.reset_player(1)
	SanitySystem._on_session_ended("")


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


func test_recovery_resets_hallucination_delay() -> void:
	var player: Player = _player(&"medic")
	player.sanity = 20.0
	SanitySystem._hallucination_clock = 0.1
	SanitySystem._update_local_effects(0.05)
	assert_lt(SanitySystem._hallucination_clock, 0.1)
	player.sanity = player.max_sanity
	SanitySystem._update_local_effects(0.05)
	assert_eq(SanitySystem._hallucination_clock, 24.0)


func test_panic_audio_uses_only_local_sanity_and_resets_on_exit() -> void:
	var local: Player = _player(&"medic")
	var remote: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	remote.peer_id = 2
	remote.apply_class(ClassCatalog.get_data(&"tech"))
	add_child_autofree(remote)
	remote.set_physics_process(false)
	remote.set_process(false)
	var panic: int = AudioServer.get_bus_index(&"Panic")
	var lowpass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(panic, 0) as AudioEffectLowPassFilter
	var reverb: AudioEffectReverb = AudioServer.get_bus_effect(panic, 1) as AudioEffectReverb
	remote.sanity = 0.0
	SanitySystem._update_local_effects(2.0)
	assert_almost_eq(lowpass.cutoff_hz, 20000.0, 1.0, "another player's panic cannot muffle local SFX")
	assert_almost_eq(reverb.wet, 0.0, 0.001)
	local.sanity = 0.0
	SanitySystem._update_local_effects(2.0)
	assert_almost_eq(lowpass.cutoff_hz, 800.0, 1.0)
	assert_almost_eq(reverb.wet, 0.22, 0.001)
	SanitySystem._on_session_ended("test")
	assert_almost_eq(lowpass.cutoff_hz, 20000.0, 1.0, "menu audio recovers immediately")
	assert_almost_eq(reverb.wet, 0.0, 0.001)


func test_host_sanity_reaches_client_and_client_cannot_change_it() -> void:
	var server_root: Node = Node.new()
	server_root.name = "SanityServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "SanityClient"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49394, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49394), OK)
	client_api.multiplayer_peer = client_peer
	for _i: int in 120:
		if server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1:
			break
		await get_tree().process_frame
	assert_eq(server_api.get_peers().size(), 1)
	var client_id: int = client_api.get_unique_id()
	var host_player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	host_player.name = "Player"
	host_player.peer_id = client_id
	host_player.apply_class(ClassCatalog.get_data(&"medic"))
	server_root.add_child(host_player)
	host_player.set_physics_process(false)
	var client_player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	client_player.name = "Player"
	client_player.peer_id = client_id
	client_player.apply_class(ClassCatalog.get_data(&"medic"))
	client_root.add_child(client_player)
	client_player.set_physics_process(false)
	(host_player.get_node(^"HostSync") as MultiplayerSynchronizer).set_visibility_for(client_id, true)
	client_player.apply_sanity_damage(20.0, &"anomaly")
	assert_eq(client_player.sanity, 130.0)
	host_player.apply_sanity_damage(20.0, &"anomaly")
	assert_eq(host_player.sanity, 116.0)
	for _i: int in 120:
		if is_equal_approx(client_player.sanity, 116.0):
			break
		await get_tree().process_frame
	assert_almost_eq(client_player.sanity, 116.0, 0.01)
	client_peer.close()
	server_peer.close()
