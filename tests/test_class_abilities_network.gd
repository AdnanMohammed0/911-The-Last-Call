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
