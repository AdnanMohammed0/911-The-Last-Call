extends GutTest

const DirectorScript := preload("res://autoload/call_director.gd")


func test_teammate_ping_and_handset_pass_replicate_over_enet() -> void:
	var saved_roster: Dictionary[int, Dictionary] = NetManager.roster.duplicate(true)
	var server_root: Node = Node.new()
	server_root.name = "PhoneServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "PhoneClient"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49371, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49371), OK)
	client_api.multiplayer_peer = client_peer
	var server_director: DirectorScript = DirectorScript.new()
	server_director.name = "CallDirector"
	server_root.add_child(server_director)
	var client_director: DirectorScript = DirectorScript.new()
	client_director.name = "CallDirector"
	client_root.add_child(client_director)
	for _i: int in 120:
		if server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1:
			break
		await get_tree().process_frame
	assert_eq(server_api.get_peers().size(), 1)
	var client_id: int = client_api.get_unique_id()
	NetManager.roster[1] = {"name": "Host", "class_id": &"tech"}
	NetManager.roster[client_id] = {"name": "Teammate", "class_id": &"profiler"}
	var graph: DialogueGraph = DialogueGraph.new()
	var root: DialogueNode = DialogueNode.new()
	root.id = &"root"
	var reply: DialogueChoice = DialogueChoice.new()
	reply.text = "Where are you?"
	root.choices = [reply]
	graph.initial_node_id = &"root"
	graph.nodes = [root]
	server_director.current_state = server_director.CallState.CONNECTED
	client_director.current_state = client_director.CallState.CONNECTED
	server_director.handset_owner_peer_id = 1
	client_director.handset_owner_peer_id = 1
	server_director.dialogue_runner.start(graph)
	client_director.request_ping_choice.rpc_id(1, 0)
	for _i: int in 120:
		if server_director._choice_pings_by_peer.get(client_id, -1) == 0:
			break
		await get_tree().process_frame
	var pinged_index: int = server_director._choice_pings_by_peer.get(client_id, -1)
	assert_eq(pinged_index, 0)
	server_director.request_pass_handset(client_id)
	for _i: int in 120:
		if client_director.handset_owner_peer_id == client_id:
			break
		await get_tree().process_frame
	assert_eq(client_director.handset_owner_peer_id, client_id)
	client_peer.close()
	server_peer.close()
	NetManager.roster = saved_roster
