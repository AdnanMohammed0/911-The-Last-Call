## A client ability request is validated by the host and replicated to both peers.
extends GutTest


func _wait_for(condition: Callable) -> void:
	for _i: int in 120:
		if condition.call():
			return
		await get_tree().process_frame


func test_client_drone_request_is_validated_and_replicated() -> void:
	var saved_roster: Dictionary[int, Dictionary] = NetManager.roster.duplicate(true)
	var server_root: Node = Node.new()
	server_root.name = "AbilityServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "AbilityClient"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49393, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49393), OK)
	client_api.multiplayer_peer = client_peer
	await _wait_for(func() -> bool: return server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1)
	var client_id: int = client_api.get_unique_id()
	NetManager.roster[client_id] = {"name": "Client", "class_id": &"tech", "ready": true}
	LoadoutManager._player_loadouts[client_id] = {&"recon_drone": 1}
	var host_player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	host_player.name = "Player"
	host_player.peer_id = client_id
	host_player.apply_class(ClassCatalog.get_data(&"tech"))
	server_root.add_child(host_player)
	host_player.set_physics_process(false)
	var client_player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	client_player.name = "Player"
	client_player.peer_id = client_id
	client_player.apply_class(ClassCatalog.get_data(&"tech"))
	client_root.add_child(client_player)
	client_player.set_physics_process(false)
	var host_abilities: ClassAbilities = host_player.get_node(^"ClassAbilities") as ClassAbilities
	var client_abilities: ClassAbilities = client_player.get_node(^"ClassAbilities") as ClassAbilities
	client_abilities._request.rpc_id(1, 99)
	await wait_physics_frames(3)
	assert_null(host_abilities._drone)
	client_abilities._request.rpc_id(1, 0)
	await _wait_for(func() -> bool: return host_abilities._drone != null and client_abilities._drone != null)
	assert_not_null(host_abilities._drone)
	assert_not_null(client_abilities._drone)
	client_peer.close()
	server_peer.close()
	LoadoutManager._player_loadouts.erase(client_id)
	NetManager.roster = saved_roster


func test_client_shield_and_sedative_results_reach_both_peers() -> void:
	var saved_roster: Dictionary[int, Dictionary] = NetManager.roster.duplicate(true)
	var server_root: Node = Node.new()
	server_root.name = "AbilityServerTwo"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "AbilityClientTwo"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49396, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49396), OK)
	client_api.multiplayer_peer = client_peer
	await _wait_for(func() -> bool: return server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1)
	var client_id: int = client_api.get_unique_id()
	NetManager.roster[client_id] = {"name": "Client", "class_id": &"breacher", "ready": true}
	LoadoutManager._player_loadouts[client_id] = {&"ballistic_shield": 1}
	var scene: PackedScene = load("res://scenes/shared/player/player.tscn") as PackedScene
	var host_breacher: Player = scene.instantiate() as Player
	host_breacher.name = "Breacher"
	host_breacher.peer_id = client_id
	host_breacher.apply_class(ClassCatalog.get_data(&"breacher"))
	server_root.add_child(host_breacher)
	host_breacher.set_physics_process(false)
	var client_breacher: Player = scene.instantiate() as Player
	client_breacher.name = "Breacher"
	client_breacher.peer_id = client_id
	client_breacher.apply_class(ClassCatalog.get_data(&"breacher"))
	client_root.add_child(client_breacher)
	client_breacher.set_physics_process(false)
	var host_shield: ClassAbilities = host_breacher.get_node(^"ClassAbilities") as ClassAbilities
	var client_shield: ClassAbilities = client_breacher.get_node(^"ClassAbilities") as ClassAbilities
	client_shield._request.rpc_id(1, 0)
	await _wait_for(func() -> bool: return host_shield.shield_raised and client_shield.shield_raised)
	assert_true(host_shield.shield_raised)
	assert_true(client_shield.shield_raised)
	assert_not_null(client_breacher.get_node_or_null(^"ShieldVisual"))
	host_breacher.queue_free()
	client_breacher.queue_free()
	await wait_physics_frames(2)
	NetManager.roster[client_id]["class_id"] = &"medic"
	LoadoutManager._player_loadouts[client_id] = {&"sedatives": 1}
	var host_medic: Player = scene.instantiate() as Player
	host_medic.name = "Medic"
	host_medic.peer_id = client_id
	host_medic.apply_class(ClassCatalog.get_data(&"medic"))
	server_root.add_child(host_medic)
	host_medic.set_physics_process(false)
	host_medic.sanity = 50.0
	var client_medic: Player = scene.instantiate() as Player
	client_medic.name = "Medic"
	client_medic.peer_id = client_id
	client_medic.apply_class(ClassCatalog.get_data(&"medic"))
	client_root.add_child(client_medic)
	client_medic.set_physics_process(false)
	(host_medic.get_node(^"HostSync") as MultiplayerSynchronizer).set_visibility_for(client_id, true)
	var client_medic_abilities: ClassAbilities = client_medic.get_node(^"ClassAbilities") as ClassAbilities
	client_medic_abilities._request.rpc_id(1, 0)
	await _wait_for(func() -> bool: return is_equal_approx(client_medic.sanity, 85.0) and client_medic_abilities.sedated_until_msec > Time.get_ticks_msec())
	assert_almost_eq(host_medic.sanity, 85.0, 0.01)
	assert_almost_eq(client_medic.sanity, 85.0, 0.01)
	assert_gt(client_medic_abilities.sedated_until_msec, Time.get_ticks_msec())
	client_peer.close()
	server_peer.close()
	LoadoutManager._player_loadouts.erase(client_id)
	NetManager.roster = saved_roster
