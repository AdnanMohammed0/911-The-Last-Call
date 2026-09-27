extends SceneTree

var passed: int = 0
var failed: int = 0

func _init() -> void:
	print("\n================== RUNNING DOOR TESTS ==================")
	_run_all_tests()
	print("========================================================")
	print("Results: %d passed, %d failed\n" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _run_all_tests() -> void:
	_test_initial_state()
	_test_toggle_open_and_close()
	_test_swing_direction()
	_test_peek()
	_test_locked_door_blocks_open()
	_test_unlock_door()
	_test_kick_breaches_locked_door()
	_test_reinforced_door_resists_kick()
	_test_distance_validation()
	_test_double_door()


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] %s" % msg)
	else:
		failed += 1
		printerr("  [FAIL] %s" % msg)


func _create_door() -> Door:
	var scene := load("res://scenes/shared/door/door.tscn") as PackedScene
	var door := scene.instantiate() as Door
	root.add_child(door)
	door.position = Vector3.ZERO
	return door


func _test_initial_state() -> void:
	print("Test: Initial state")
	var door := _create_door()
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Door starts closed")
	_assert_true(is_zero_approx(door.target_angle_deg), "Target angle starts at 0")
	root.remove_child(door)
	door.free()


func _test_toggle_open_and_close() -> void:
	print("Test: Toggle open and close")
	var door := _create_door()
	var player_front := Vector3(0, 0, -1.5) # In front of door (-Z is forward)
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_front)
	_assert_true(door.current_state == Door.DoorState.OPEN, "Door state is OPEN after toggle")
	_assert_true(is_equal_approx(door.target_angle_deg, 90.0), "Target angle is 90 deg")

	# Second toggle should close it
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_front)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Door state is CLOSED after second toggle")
	_assert_true(is_zero_approx(door.target_angle_deg), "Target angle is back to 0")
	root.remove_child(door)
	door.free()


func _test_swing_direction() -> void:
	print("Test: Swing direction (one-way and two-way)")
	var door := _create_door()
	var player_behind := Vector3(0, 0, 1.5) # Behind the door (+Z is backward)

	# One-way swing (default: always opens to fixed direction 1.0)
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_behind)
	_assert_true(door.swing_direction == 1.0, "One-way swing always uses fixed direction (1.0)")
	_assert_true(is_equal_approx(door.target_angle_deg, 90.0), "Target angle is 90 deg in one-way mode")

	# Two-way swing mode
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_behind) # Close it
	door.one_way_swing = false
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_behind) # Open from behind
	_assert_true(door.swing_direction == -1.0, "Two-way swing swings away (-1.0) when approached from behind")
	_assert_true(is_equal_approx(door.target_angle_deg, -90.0), "Target angle is -90 deg in two-way mode")

	root.remove_child(door)
	door.free()


func _test_peek() -> void:
	print("Test: Peek cracks door 15 degrees")
	var door := _create_door()
	var player_pos := Vector3(0, 0, -1.5)
	door.interact(Door.DoorAction.PEEK, player_pos)
	_assert_true(door.current_state == Door.DoorState.PEEK, "Door state is PEEK")
	_assert_true(is_equal_approx(door.target_angle_deg, 15.0), "Target angle is 15 deg")

	# Peeking again closes the crack
	door.interact(Door.DoorAction.PEEK, player_pos)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Door state is CLOSED after closing peek")
	root.remove_child(door)
	door.free()


func _test_locked_door_blocks_open() -> void:
	print("Test: Locked door blocks opening and peeking")
	var door := _create_door()
	door.is_locked = true
	var player_pos := Vector3(0, 0, -1.5)

	var signal_received: Array[bool] = [false]
	door.locked_interacted.connect(func(_peer: int) -> void: signal_received[0] = true)

	door.interact(Door.DoorAction.TOGGLE_OPEN, player_pos)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Locked door remains CLOSED on open attempt")
	_assert_true(signal_received[0], "locked_interacted signal emitted")

	door.interact(Door.DoorAction.PEEK, player_pos)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Locked door remains CLOSED on peek attempt")
	root.remove_child(door)
	door.free()


func _test_unlock_door() -> void:
	print("Test: Unlocking allows door to open")
	var door := _create_door()
	door.is_locked = true
	var signal_received: Array[bool] = [false]
	door.door_unlocked.connect(func(_peer: int) -> void: signal_received[0] = true)

	door.interact(Door.DoorAction.UNLOCK, Vector3.ZERO)
	_assert_true(not door.is_locked, "Door is unlocked")
	_assert_true(signal_received[0], "door_unlocked signal emitted")

	door.interact(Door.DoorAction.TOGGLE_OPEN, Vector3(0, 0, -1.5))
	_assert_true(door.current_state == Door.DoorState.OPEN, "Unlocked door now opens")
	root.remove_child(door)
	door.free()


func _test_kick_breaches_locked_door() -> void:
	print("Test: Kick breaches door and breaks lock")
	var door := _create_door()
	door.is_locked = true
	var signal_received: Array[bool] = [false]
	door.door_kicked.connect(func(_peer: int, was_locked: bool) -> void:
		if was_locked:
			signal_received[0] = true
	)

	door.interact(Door.DoorAction.KICK, Vector3(0, 0, -1.5))
	_assert_true(door.current_state == Door.DoorState.KICKED, "Door state is KICKED")
	_assert_true(not door.is_locked, "Lock was broken by kick")
	_assert_true(is_equal_approx(door.target_angle_deg, 90.0), "Door breached open to 90 deg")
	_assert_true(signal_received[0], "door_kicked signal received with was_locked = true")
	root.remove_child(door)
	door.free()


func _test_reinforced_door_resists_kick() -> void:
	print("Test: Reinforced door resists normal kick")
	var door := _create_door()
	door.is_reinforced = true
	door.interact(Door.DoorAction.KICK, Vector3(0, 0, -1.5))
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Reinforced door stays CLOSED after kick")
	root.remove_child(door)
	door.free()


func _test_distance_validation() -> void:
	print("Test: Interaction rejected if player is beyond max distance")
	var door := _create_door()
	var far_away_player := Vector3(0, 0, 15.0)
	door.request_interact(Door.DoorAction.TOGGLE_OPEN, far_away_player)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Door ignores interaction beyond max distance")
	root.remove_child(door)
	door.free()


func _test_double_door() -> void:
	print("Test: Double door station model synchronization and dual swing")
	var scene := load("res://scenes/shared/door/door_double.tscn") as PackedScene
	var door := scene.instantiate() as Door
	root.add_child(door)
	door._ready()

	_assert_true(door.is_double_door, "Door is configured as double door")
	_assert_true(door.hinge != null, "Left hinge found")
	_assert_true(door.hinge_right != null, "Right hinge found")
	_assert_true(door.mesh_leaf_left != null, "Left visual leaf L_2 found")
	_assert_true(door.mesh_leaf_right != null, "Right visual leaf R_2_2 found")

	var player_front := Vector3(0, 0, -1.5)
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_front)
	_assert_true(door.current_state == Door.DoorState.OPEN, "Double door opened")

	# Simulate physics/process lerp (2 seconds)
	for i in range(120):
		door._process(1.0 / 60.0)

	_assert_true(is_equal_approx(door.mesh_leaf_left.rotation_degrees.y, -90.0), "Left leaf swung out to -90 deg")
	_assert_true(is_equal_approx(door.mesh_leaf_right.rotation_degrees.y, 90.0), "Right leaf swung out to +90 deg")
	_assert_true(is_equal_approx(door.hinge.rotation_degrees.y, -90.0), "Left collider hinge followed to -90 deg")
	_assert_true(is_equal_approx(door.hinge_right.rotation_degrees.y, 90.0), "Right collider hinge followed to +90 deg")

	# Close double door
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_front)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Double door closed")

	for i in range(120):
		door._process(1.0 / 60.0)

	_assert_true(is_zero_approx(door.mesh_leaf_left.rotation_degrees.y), "Left leaf returned to 0 deg")
	_assert_true(is_zero_approx(door.mesh_leaf_right.rotation_degrees.y), "Right leaf returned to 0 deg")

	# Approach from behind (+Z): should open away to -Z (opposite side from player)
	var player_behind := Vector3(0, 0, 1.5)
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_behind)
	_assert_true(door.current_state == Door.DoorState.OPEN, "Double door opened from behind")
	_assert_true(door.swing_direction == -1.0, "Swing direction is -1.0 (away to opposite side)")

	for i in range(120):
		door._process(1.0 / 60.0)

	_assert_true(is_equal_approx(door.mesh_leaf_left.rotation_degrees.y, 90.0), "Left leaf swung to +90 deg (-Z, opposite side)")
	_assert_true(is_equal_approx(door.mesh_leaf_right.rotation_degrees.y, -90.0), "Right leaf swung to -90 deg (-Z, opposite side)")

	# Close
	door.interact(Door.DoorAction.TOGGLE_OPEN, player_behind)
	_assert_true(door.current_state == Door.DoorState.CLOSED, "Double door closed after behind test")

	root.remove_child(door)
	door.free()
