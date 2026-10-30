extends GutTest


func after_each() -> void:
	Input.action_release(&"look_right")
	Input.action_release(&"move_forward")
	Input.action_release(&"interact")
	GameSettings.reset_keybinds()


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var joy: InputEventJoypadButton = event as InputEventJoypadButton
		if joy != null and joy.button_index == button:
			return true
	return false


func test_default_controller_covers_movement_and_dispatch_interaction() -> void:
	assert_true(_has_button(&"interact", JOY_BUTTON_X))
	assert_true(_has_button(&"jump", JOY_BUTTON_A))
	assert_true(_has_button(&"crouch", JOY_BUTTON_B))
	assert_true(_has_button(&"ui_cancel", JOY_BUTTON_START))
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"look_left", &"look_right", &"look_up", &"look_down", &"fire", &"aim"]:
		assert_true(InputMap.has_action(action), String(action))
		assert_gt(InputMap.action_get_events(action).size(), 0, String(action))
	var old_count: int = InputMap.action_get_events(&"interact").size()
	GamepadControls.install_defaults()
	assert_eq(InputMap.action_get_events(&"interact").size(), old_count, "Installing twice must not duplicate bindings")


func test_keyboard_rebind_preserves_controller_interact() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_H
	GameSettings.rebind(&"interact", key)
	assert_eq(GameSettings.binding_text(&"interact"), "H")
	assert_true(_has_button(&"interact", JOY_BUTTON_X))


func test_right_stick_look_is_frame_rate_independent_and_pauses_with_input() -> void:
	var controller: PlayerInput = PlayerInput.new()
	add_child_autofree(controller)
	Input.action_press(&"look_right")
	var one_frame: Vector2 = controller.consume_look(1.0 / 30.0)
	var two_frames: Vector2 = controller.consume_look(1.0 / 60.0) + controller.consume_look(1.0 / 60.0)
	assert_almost_eq(one_frame.x, two_frames.x, 0.001)
	assert_gt(one_frame.x, 0.0)
	controller.enabled = false
	assert_eq(controller.consume_look(1.0), Vector2.ZERO)
