## P3-13: tension from damage / sanity / scares, low-tension scare scheduling, high-tension suppression,
## and local-only hallucinations.
extends GutTest

var _world: Node3D
var _alice: Player
var _bob: Player


func _player(node_name: String, peer: int) -> Player:
	var player: Player = (load("res://scenes/shared/player/player.tscn") as PackedScene).instantiate() as Player
	player.name = node_name
	_world.add_child(player)
	player.peer_id = peer
	player.set_physics_process(false)
	player.set_process(false)
	player.get_health().setup(10000.0, 0.0)
	return player


func before_each() -> void:
	TensionDirector.enabled = false   # the test drives update() itself
	TensionDirector.reset()
	_world = Node3D.new()
	add_child_autofree(_world)
	_alice = _player("Alice", 1)
	_bob = _player("Bob", 2)
	_bob.global_position = Vector3(3, 0, 0)


func after_each() -> void:
	TensionDirector.enabled = true
	TensionDirector.reset()
	for node: Node in get_tree().get_nodes_in_group(Hallucination.GROUP):
		node.queue_free()


func _run(seconds: float) -> void:
	for i: int in int(seconds / 0.5):
		TensionDirector.update(0.5)


func test_calm_team_has_low_tension() -> void:
	_run(10.0)
	assert_lt(TensionDirector.tension, TensionDirector.LOW)


func test_damage_and_low_sanity_raise_tension() -> void:
	_alice.sanity = 20.0
	_bob.sanity = 30.0
	_alice.get_health().apply_damage(160.0)
	_run(6.0)
	assert_gt(TensionDirector.tension, TensionDirector.HIGH)


func test_high_tension_suppresses_manifestation_until_recovered() -> void:
	_alice.sanity = 5.0
	_bob.sanity = 5.0
	_alice.get_health().apply_damage(200.0)
	_run(6.0)
	assert_false(TensionDirector.can_manifest())
	assert_eq(TensionDirector.schedule_scare(), 0, "no scares while suppressed")
	_alice.sanity = 100.0
	_bob.sanity = 100.0
	_run(40.0)   # damage leaves the 20 s window, tension decays below 0.6
	assert_true(TensionDirector.can_manifest())


func test_ninety_seconds_of_calm_schedules_a_scare() -> void:
	var scares: Array[StringName] = []
	var on_scare: Callable = func(_peer: int, kind: StringName) -> void: scares.append(kind)
	TensionDirector.scare_scheduled.connect(on_scare)
	_run(80.0)
	assert_eq(scares.size(), 0)
	_run(12.0)
	TensionDirector.scare_scheduled.disconnect(on_scare)
	assert_eq(scares.size(), 1)
	assert_true(scares[0] in TensionDirector.KINDS)


func test_scare_plays_locally_for_the_victim() -> void:
	var seen: Array[StringName] = []
	var on_hallucination: Callable = func(kind: StringName, _at: Vector3) -> void: seen.append(kind)
	EventBus.hallucination.connect(on_hallucination)
	var victim: int = TensionDirector.schedule_scare(&"shadow_figure")
	EventBus.hallucination.disconnect(on_hallucination)
	assert_ne(victim, 0)
	assert_eq(seen, [&"shadow_figure"] as Array[StringName])
	assert_eq(get_tree().get_nodes_in_group(Hallucination.GROUP).size(), 1)


func test_hallucination_expires() -> void:
	TensionDirector.schedule_scare(&"shadow_figure")
	await wait_seconds(1.8)
	assert_eq(get_tree().get_nodes_in_group(Hallucination.GROUP).size(), 0)


func test_same_scare_kind_does_not_repeat_back_to_back() -> void:
	var kinds: Array[StringName] = []
	var on_scare: Callable = func(_peer: int, kind: StringName) -> void: kinds.append(kind)
	TensionDirector.scare_scheduled.connect(on_scare)
	for i: int in 12:
		TensionDirector.schedule_scare()
	TensionDirector.scare_scheduled.disconnect(on_scare)
	for i: int in range(1, kinds.size()):
		assert_ne(kinds[i], kinds[i - 1])


func test_low_sanity_players_are_picked_more_often() -> void:
	_alice.sanity = 5.0
	_bob.sanity = 100.0
	var alice_count: int = 0
	for i: int in 200:
		if TensionDirector._pick_victim() == _alice:
			alice_count += 1
	assert_gt(alice_count, 120, "weighted towards the scared player (%d/200)" % alice_count)
