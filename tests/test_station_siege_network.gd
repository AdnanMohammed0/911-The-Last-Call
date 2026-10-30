## Station Siege over a real ENet connection (host + client in one process): the client follows the host's
## siege state, gets the blackout and HUD, sees the power come back when it ends, and cannot start one.
extends GutTest

const SIEGE: PackedScene = preload("res://scenes/dispatch/siege/station_siege.tscn")
const THUG: ArchetypeData = preload("res://data/ai/archetypes/thug.tres")

var _shift_running_before: bool = false


func before_each() -> void:
	FlagSystem.reset()
	Career.persist = false
	_shift_running_before = CallDirector.shift_running


func after_each() -> void:
	FlagSystem.reset()
	CallDirector.shift_running = _shift_running_before
	Career.reset()


func _wait_until(condition: Callable) -> void:
	for _i: int in 120:
		if condition.call():
			return
		await get_tree().process_frame


func _station(root: Node) -> StationSiege:
	var lamps: Node3D = Node3D.new()
	lamps.name = "Lamps"
	lamps.add_child(OmniLight3D.new())
	root.add_child(lamps)
	var siege: StationSiege = SIEGE.instantiate() as StationSiege
	siege.auto_start = false
	siege.nav_sources = []
	siege.power_roots = [NodePath("../Lamps")]
	siege.doors_path = NodePath()
	var plan: SiegePlan = SiegePlan.new()
	var wave: SiegeWave = SiegeWave.new()
	wave.archetypes = [THUG]
	wave.counts = [1]
	wave.intermission_sec = 30.0
	plan.waves.append(wave)
	plan.waves.append(wave.duplicate() as SiegeWave)
	siege.plan = plan
	root.add_child(siege)
	return siege


func test_client_follows_the_host_siege() -> void:
	var server_root: Node = Node.new()
	server_root.name = "SiegeServer"
	add_child_autofree(server_root)
	var client_root: Node = Node.new()
	client_root.name = "SiegeClient"
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
	var host: StationSiege = _station(server_root)
	var client: StationSiege = _station(client_root)
	await _wait_until(func() -> bool: return server_api.get_peers().size() == 1 and client_api.get_unique_id() > 1)
	assert_eq(server_api.get_peers().size(), 1)

	assert_false(client.start(&"forged"), "clients cannot start a siege")
	assert_eq(host.state, StationSiege.State.IDLE)

	assert_true(host.start(&"test"))
	await _wait_until(func() -> bool: return client.state == StationSiege.State.INTERMISSION)
	assert_eq(client.state, StationSiege.State.INTERMISSION, "the client follows the host")
	assert_eq(client.wave_index, 0)
	assert_gt(client.countdown, 25.0)
	var client_lamp: OmniLight3D = client_root.get_node("Lamps").get_child(0) as OmniLight3D
	var client_hud: CanvasLayer = client.get_node("SiegeHud") as CanvasLayer
	assert_false(client_lamp.visible, "the blackout reaches the client")
	assert_true(client.emergency_lights.visible)
	assert_true(client_hud.visible)

	host._end(StationSiege.SURVIVED)
	await _wait_until(func() -> bool: return client.state == StationSiege.State.SURVIVED)
	assert_eq(client.state, StationSiege.State.SURVIVED)
	assert_true(client_lamp.visible, "power comes back on the client")
	assert_false(client_hud.visible)
	client_peer.close()
	server_peer.close()
