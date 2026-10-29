## FlagSystem replication over a real ENet connection (host + client in one process): host flags and events
## reach the client, a late joiner gets the full snapshot, and clients cannot change flags.
extends GutTest

const FlagSystemScript := preload("res://autoload/flag_system.gd")


func _wait_until(condition: Callable) -> void:
	for _i: int in 120:
		if condition.call():
			return
		await get_tree().process_frame


func test_flags_and_events_replicate_and_late_joiners_get_a_snapshot() -> void:
	var server_root: Node = Node.new()
	server_root.name = "FlagServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "FlagClient"
	add_child_autofree(client_root)
	var server_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(49381, 2), OK)
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", 49381), OK)
	client_api.multiplayer_peer = client_peer
	var host: FlagSystemScript = FlagSystemScript.new()
	host.name = "FlagSystem"
	server_root.add_child(host)
	var client: FlagSystemScript = FlagSystemScript.new()
	client.name = "FlagSystem"
	client_root.add_child(client)
	await _wait_until(func() -> bool: return server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1)
	assert_eq(server_api.get_peers().size(), 1)

	# State that existed before the client was "in the game" arrives with the join snapshot.
	host.flags[&"closet_teen_dead"] = true
	host.events.append({"id": &"call_ignored", "t": 40, "shift": 1, "payload": {"call": &"closet_monster"}})
	host._on_peer_joined(client_api.get_unique_id(), "Teammate")
	await _wait_until(func() -> bool: return client.has_flag(&"closet_teen_dead"))
	var dead: bool = client.get_flag(&"closet_teen_dead", false)
	assert_true(dead, "late joiner receives existing flags")
	assert_true(client.has_event(&"call_ignored", &"closet_monster"), "and the event log")

	host.set_flag(&"lake_house_cleared", true)
	host.record_event(&"mission_success", {"call": &"lake_house"})
	await _wait_until(func() -> bool: return client.has_event(&"mission_success"))
	var cleared: bool = client.get_flag(&"lake_house_cleared", false)
	assert_true(cleared, "host flag changes reach the client")
	assert_true(client.has_event(&"mission_success", &"lake_house"), "and new events")

	client.set_flag(&"forged", true)
	client.record_event(&"forged_event")
	await get_tree().process_frame
	assert_false(client.has_flag(&"forged"), "clients cannot write flags")
	assert_false(host.has_flag(&"forged"))
	assert_false(host.has_event(&"forged_event"))
	client_peer.close()
	server_peer.close()
