## P3-12: StateMachine + Drowned Woman transitions, attacks and weaknesses.
extends GutTest

var _world: Node3D
var _woman: DrownedWoman
var _alice: Player
var _bob: Player


func _player(node_name: String, peer: int, at: Vector3) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.name = node_name
	_world.add_child(player)
	player.peer_id = peer
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = at
	player.get_health().setup(500.0, 0.0)
	return player


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	var zone: Area3D = Area3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 6, 40)
	shape.shape = box
	zone.add_child(shape)
	_world.add_child(zone)
	for i: int in 3:
		var dark: Marker3D = Marker3D.new()
		dark.add_to_group(Anomaly.DARK_NODES_GROUP)
		_world.add_child(dark)
		dark.global_position = Vector3(-10 + i * 10, 0, -15)
	_alice = _player("Alice", 1, Vector3(0, 0, 0))
	_bob = _player("Bob", 2, Vector3(3, 0, 0))
	_woman = (load("res://scenes/field/anomalies/drowned_woman.tscn") as PackedScene).instantiate() as DrownedWoman
	_woman.zone = zone
	_world.add_child(_woman)
	_woman.set_physics_process(false)
	_woman.retreat_cooldown = Vector2(1.0, 1.0)
	await wait_physics_frames(2)


func _step(seconds: float, dt: float = 0.1) -> void:
	for i: int in int(seconds / dt):
		_woman.fsm.update(dt)


func test_state_machine_transitions_and_timer() -> void:
	var fsm: StateMachine = StateMachine.new()
	var log: Array[String] = []
	fsm.add_state(&"a", func() -> void: log.append("enter a"), func(_d: float) -> StringName: return &"b" if fsm.time_in_state >= 1.0 else &"", func() -> void: log.append("exit a"))
	fsm.add_state(&"b", func() -> void: log.append("enter b"))
	fsm.start(&"a")
	fsm.update(0.5)
	assert_eq(fsm.current, &"a")
	fsm.update(0.6)
	assert_eq(fsm.current, &"b")
	assert_eq(log, ["enter a", "exit a", "enter b"] as Array[String])


func test_starts_dormant_and_invisible() -> void:
	assert_eq(_woman.fsm.current, DrownedWoman.DORMANT)
	assert_false(_woman.manifested)


func test_low_emf_does_not_wake_her_but_three_does() -> void:
	_woman.notify_emf(2)
	assert_eq(_woman.fsm.current, DrownedWoman.DORMANT)
	_woman.notify_emf(3)
	assert_eq(_woman.fsm.current, DrownedWoman.MANIFEST)
	assert_true(_woman.manifested)


func test_manifest_drains_sanity_in_sight_then_stalks() -> void:
	_woman.trigger()
	_woman.global_position = Vector3(0, 0, -6)
	_step(3.0)
	assert_lt(_alice.sanity, 100.0, "4 sanity / s with line of sight")
	_step(3.5)
	assert_eq(_woman.fsm.current, DrownedWoman.STALK)
	assert_false(_woman.manifested)


func test_stalk_targets_lowest_sanity_and_hunts_below_forty() -> void:
	_bob.sanity = 55.0
	_woman.trigger()
	_step(6.5)
	assert_eq(_woman.target, _bob)
	_bob.sanity = 35.0
	_step(0.2)
	assert_eq(_woman.fsm.current, DrownedWoman.HUNT)


func test_stalk_times_out_into_hunt() -> void:
	_alice.flashlight_on = true
	_woman.stalk_duration = 5.0
	_woman.trigger()
	_step(6.5)
	_step(5.5)
	assert_eq(_woman.fsm.current, DrownedWoman.HUNT)


func test_all_lights_off_for_twenty_seconds_remanifests() -> void:
	_woman.stalk_duration = 999.0
	_woman.trigger()
	_step(6.5)
	_step(21.0)
	assert_eq(_woman.fsm.current, DrownedWoman.MANIFEST)


func test_hunt_kills_flashlights_nearby_and_grabs_in_range() -> void:
	_woman.trigger()
	_step(6.5)
	_alice.sanity = 10.0
	_step(0.2)
	assert_eq(_woman.fsm.current, DrownedWoman.HUNT)
	_alice.flashlight_on = true
	_woman.global_position = _alice.global_position + Vector3(0, 0, -4)
	_step(0.1)
	assert_false(_alice.flashlight_on, "flashlight killed within 6 m")
	_woman.global_position = _alice.global_position + Vector3(0, 0, -1.5)
	_step(0.1)
	assert_eq(_woman.fsm.current, DrownedWoman.ATTACK)
	assert_true(_alice.grabbed_by_anomaly)


func test_grab_completes_for_60_damage_and_40_sanity() -> void:
	_woman.trigger()
	_step(6.5)
	_alice.sanity = 45.0
	_bob.sanity = 90.0
	_woman.stalk_duration = 0.1
	_step(0.3)
	_woman.global_position = _alice.global_position + Vector3(0, 0, -1.0)
	_step(0.1)
	assert_eq(_woman.fsm.current, DrownedWoman.ATTACK)
	var hp: float = _alice.get_health().hp
	_step(3.2)
	assert_eq(_woman.fsm.current, DrownedWoman.RETREAT)
	assert_almost_eq(_alice.get_health().hp, hp - 60.0, 0.01)
	assert_almost_eq(_alice.sanity, 5.0, 0.01)
	assert_false(_alice.grabbed_by_anomaly)


func test_teammate_flashlight_breaks_grab() -> void:
	_woman.trigger()
	_step(6.5)
	_alice.sanity = 10.0
	_step(0.2)
	_woman.global_position = _alice.global_position + Vector3(0, 0, -1.0)
	_step(0.1)
	assert_eq(_woman.fsm.current, DrownedWoman.ATTACK)
	var hp: float = _alice.get_health().hp
	# Bob stands behind Alice and shines his light at the woman.
	_bob.global_position = _alice.global_position + Vector3(0, 0, 4)
	_bob.rotation.y = 0.0
	_bob.flashlight_on = true
	_step(0.2)
	assert_eq(_woman.fsm.current, DrownedWoman.RETREAT)
	assert_eq(_alice.get_health().hp, hp, "no damage when rescued")


func test_reverse_tone_forces_retreat_and_cooldown_returns_to_stalk() -> void:
	_woman.trigger()
	_step(6.5)
	_alice.sanity = 10.0
	_step(0.2)
	_woman.on_reverse_tone_complete()
	assert_eq(_woman.fsm.current, DrownedWoman.RETREAT)
	_step(1.2)
	assert_eq(_woman.fsm.current, DrownedWoman.STALK)


func test_salt_line_sends_her_dormant_and_bones_banish_her() -> void:
	_woman.trigger()
	_step(6.5)
	_woman.on_salt_line()
	assert_eq(_woman.fsm.current, DrownedWoman.DORMANT)
	_woman.on_bones_buried()
	assert_eq(_woman.fsm.current, DrownedWoman.BANISHED)
	_woman.notify_emf(5)
	assert_eq(_woman.fsm.current, DrownedWoman.BANISHED, "banished for good")


func test_everyone_leaving_the_zone_makes_her_dormant() -> void:
	_woman.trigger()
	_step(6.5)
	_alice.global_position = Vector3(100, 0, 100)
	_bob.global_position = Vector3(100, 0, 103)
	_step(0.2)
	assert_eq(_woman.fsm.current, DrownedWoman.DORMANT)
