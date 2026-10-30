## Default gamepad bindings shared by desktop controllers and Steam Deck.
## Installed at runtime so user key bindings and the existing project input map remain intact.
class_name GamepadControls
extends RefCounted

const LOOK_PIXELS_PER_SECOND: float = 1050.0


static func install_defaults() -> void:
	_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis(&"move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis(&"look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis(&"look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis(&"look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis(&"look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis(&"aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_axis(&"fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button(&"jump", JOY_BUTTON_A)
	_button(&"crouch", JOY_BUTTON_B)
	_button(&"interact", JOY_BUTTON_X)
	_button(&"reload", JOY_BUTTON_Y)
	_button(&"sprint", JOY_BUTTON_LEFT_STICK)
	_button(&"door_peek", JOY_BUTTON_LEFT_SHOULDER)
	_button(&"door_kick", JOY_BUTTON_RIGHT_SHOULDER)
	_button(&"flashlight", JOY_BUTTON_DPAD_UP)
	_button(&"shout", JOY_BUTTON_DPAD_LEFT)
	_button(&"weapon_swap", JOY_BUTTON_DPAD_RIGHT)
	_button(&"drop_weapon", JOY_BUTTON_DPAD_DOWN)
	_button(&"voice_ptt", JOY_BUTTON_BACK)
	_button(&"radio_ptt", JOY_BUTTON_RIGHT_STICK)
	_button(&"ui_cancel", JOY_BUTTON_START)


static func _axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing: InputEvent in InputMap.action_get_events(action):
		var motion: InputEventJoypadMotion = existing as InputEventJoypadMotion
		if motion != null and motion.axis == axis and signf(motion.axis_value) == direction:
			return
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


static func _button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing: InputEvent in InputMap.action_get_events(action):
		var joy: InputEventJoypadButton = existing as InputEventJoypadButton
		if joy != null and joy.button_index == button:
			return
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
