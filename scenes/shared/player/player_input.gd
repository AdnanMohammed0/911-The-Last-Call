## Samples local input for the owning peer. Will be replicated by a MultiplayerSynchronizer (P1-07).
## Authority: OWNING PEER
class_name PlayerInput
extends Node

var move: Vector2 = Vector2.ZERO        # x = strafe, y = forward(-) / back(+)
var sprint: bool = false
var crouch_held: bool = false
var crouch_just_pressed: bool = false
var lean: float = 0.0                   # -1 = left, +1 = right
var interact_just_pressed: bool = false
var door_peek_just_pressed: bool = false
var door_kick_just_pressed: bool = false
var flashlight_just_pressed: bool = false
var fire_held: bool = false
var fire_just_pressed: bool = false
var aim_held: bool = false
var reload_just_pressed: bool = false
var weapon_primary_just_pressed: bool = false
var weapon_sidearm_just_pressed: bool = false
var weapon_swap_just_pressed: bool = false

## False while a menu is open: sample() reports no input and the mouse is left alone.
var enabled: bool = true

var _look_delta: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_delta += (event as InputEventMouseMotion).screen_relative
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Called once per physics tick by the owning Player.
func sample() -> void:
	if not enabled:
		move = Vector2.ZERO
		sprint = false
		crouch_just_pressed = false
		lean = 0.0
		interact_just_pressed = false
		door_peek_just_pressed = false
		door_kick_just_pressed = false
		flashlight_just_pressed = false
		fire_held = false
		fire_just_pressed = false
		aim_held = false
		reload_just_pressed = false
		weapon_primary_just_pressed = false
		weapon_sidearm_just_pressed = false
		weapon_swap_just_pressed = false
		return
	move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	sprint = Input.is_action_pressed(&"sprint")
	crouch_held = Input.is_action_pressed(&"crouch")
	crouch_just_pressed = Input.is_action_just_pressed(&"crouch")
	lean = Input.get_axis(&"lean_left", &"lean_right")
	interact_just_pressed = Input.is_action_just_pressed(&"interact")
	door_peek_just_pressed = Input.is_action_just_pressed(&"door_peek")
	door_kick_just_pressed = Input.is_action_just_pressed(&"door_kick")
	flashlight_just_pressed = Input.is_action_just_pressed(&"flashlight")
	# Mouse buttons only count once the mouse is captured (the first click just captures it).
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	fire_held = captured and Input.is_action_pressed(&"fire")
	fire_just_pressed = captured and Input.is_action_just_pressed(&"fire")
	aim_held = captured and Input.is_action_pressed(&"aim")
	reload_just_pressed = Input.is_action_just_pressed(&"reload")
	weapon_primary_just_pressed = Input.is_action_just_pressed(&"weapon_primary")
	weapon_sidearm_just_pressed = Input.is_action_just_pressed(&"weapon_sidearm")
	weapon_swap_just_pressed = Input.is_action_just_pressed(&"weapon_swap")


## Returns the mouse movement accumulated since the last call and resets it.
func consume_look() -> Vector2:
	var delta: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return delta
