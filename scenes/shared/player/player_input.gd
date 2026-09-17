## Samples local input for the owning peer. Will be replicated by a MultiplayerSynchronizer (P1-07).
## Authority: OWNING PEER
class_name PlayerInput
extends Node

var move: Vector2 = Vector2.ZERO        # x = strafe, y = forward(-) / back(+)
var sprint: bool = false
var crouch_held: bool = false
var crouch_just_pressed: bool = false
var lean: float = 0.0                   # -1 = left, +1 = right

var _look_delta: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_delta += (event as InputEventMouseMotion).screen_relative
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Called once per physics tick by the owning Player.
func sample() -> void:
	move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	sprint = Input.is_action_pressed(&"sprint")
	crouch_held = Input.is_action_pressed(&"crouch")
	crouch_just_pressed = Input.is_action_just_pressed(&"crouch")
	lean = Input.get_axis(&"lean_left", &"lean_right")


## Returns the mouse movement accumulated since the last call and resets it.
func consume_look() -> Vector2:
	var delta: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return delta
