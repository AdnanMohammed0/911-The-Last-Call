## Real ENet host/client ballot replication for P2-14.
extends GutTest

const VoteScript := preload("res://autoload/vote_manager.gd")


func _wait_for(condition: Callable) -> void:
	for _i: int in 120:
		if condition.call():
			return
		await get_tree().process_frame


func test_approach_vote_opens_casts_and_closes_on_both_peers() -> void:
	var old_state: NetManager.State = NetManager.state
	var old_roster: Dictionary[int, Dictionary] = NetManager.roster.duplicate(true)
	var server_root: Node = Node.new()
	server_root.name = "VoteServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "VoteClient"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49391, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49391), OK)
	client_api.multiplayer_peer = client_peer
	var host: Node = VoteScript.new()
	host.name = "VoteManager"
	server_root.add_child(host)
	var client: Node = VoteScript.new()
	client.name = "VoteManager"
	client_root.add_child(client)
	await _wait_for(func() -> bool: return server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1)
	assert_eq(server_api.get_peers().size(), 1)
	var client_id: int = client_api.get_unique_id()
	NetManager.state = NetManager.State.HOSTING
	NetManager.roster = {1: {"name": "Host", "class_id": &"breacher"}, client_id: {"name": "Client", "class_id": &"tech"}}
	var vote_id: int = host.call(&"open_approach_vote", {"call_id": &"call_x"})
	await _wait_for(func() -> bool: return client.call(&"get_active_vote_id", &"approach") == vote_id)
	assert_eq(str(client.call(&"get_active_vote_id", &"approach")).to_int(), vote_id)
	client.call(&"cast_vote", vote_id, &"silent")
	await _wait_for(func() -> bool:
		var current_tally: Dictionary = host.call(&"get_tally", vote_id)
		return current_tally.get(&"silent", 0) == 1)
	var tally: Dictionary = host.call(&"get_tally", vote_id)
	assert_eq(str(tally.get(&"silent", 0)).to_int(), 1)
	host.call(&"cast_vote", vote_id, &"code_3")
	await _wait_for(func() -> bool: return client.call(&"get_active_vote_id", &"approach") == 0)
	assert_eq(str(host.call(&"get_active_vote_id", &"approach")).to_int(), 0)
	assert_eq(str(client.call(&"get_active_vote_id", &"approach")).to_int(), 0)
	client_peer.close()
	server_peer.close()
	NetManager.state = old_state
	NetManager.roster = old_roster
