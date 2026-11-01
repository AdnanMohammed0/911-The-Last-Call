## Real ENet client intent reaches the host's weapon validator.
extends GutTest


func _wait_for(condition: Callable) -> void:
	for _i: int in 120:
		if condition.call():
			return
		await get_tree().process_frame


func test_client_forged_slot_cannot_spend_ammo_over_rpc() -> void:
	var saved_roster: Dictionary[int, Dictionary] = NetManager.roster.duplicate(true)
	var server_root: Node = Node.new()
	server_root.name = "WeaponServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "WeaponClient"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49392, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49392), OK)
	client_api.multiplayer_peer = client_peer
	await _wait_for(func() -> bool: return server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1)
	var client_id: int = client_api.get_unique_id()
	NetManager.roster[client_id] = {"name": "Client", "class_id": &"tech", "ready": true}
	var host_player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	host_player.name = "Player"
	host_player.peer_id = client_id
	host_player.apply_class(ClassCatalog.get_data(&"tech"))
	server_root.add_child(host_player)
	host_player.set_physics_process(false)
	host_player.get_weapons().set_physics_process(false)
	var client_player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	client_player.name = "Player"
	client_player.peer_id = client_id
	client_player.apply_class(ClassCatalog.get_data(&"tech"))
	client_root.add_child(client_player)
	client_player.set_physics_process(false)
	client_player.get_weapons().set_physics_process(false)
	var host_weapon: WeaponHolder = host_player.get_weapons()
	host_weapon.set_weapon(WeaponData.Slot.SIDEARM, &"pistol")
	var ammo_before: int = host_weapon.sidearm_mag
	client_player.get_weapons()._rpc_fire.rpc_id(1, 999, client_player.get_eye_position(), PackedVector3Array([Vector3.FORWARD]))
	await wait_physics_frames(3)
	assert_eq(host_weapon.sidearm_mag, ammo_before)
	assert_false(host_weapon.has_weapon(999))
	client_player.get_weapons()._rpc_fire.rpc_id(1, WeaponData.Slot.SIDEARM, client_player.get_eye_position(), PackedVector3Array([Vector3.FORWARD]))
	await _wait_for(func() -> bool: return host_weapon.sidearm_mag == ammo_before - 1)
	assert_eq(host_weapon.sidearm_mag, ammo_before - 1, "a valid client shot still reaches the host")
	client_peer.close()
	server_peer.close()
	NetManager.roster = saved_roster
