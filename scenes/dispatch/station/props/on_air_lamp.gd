## "ON AIR" lamp for the dispatch consoles and video wall: lit while a 911 call is ringing or connected,
## pulsing faster while it rings. Shows the child "Lit" mesh and drives the optional "Glow" light.
## Authority: LOCAL (reads the replicated CallDirector state)
class_name OnAirLamp
extends Node3D

var _lit: Node3D
var _glow: Light3D
var _energy: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	_lit = get_node_or_null(^"Lit") as Node3D
	_glow = get_node_or_null(^"Glow") as Light3D
	if _glow != null:
		_energy = _glow.light_energy


func _process(delta: float) -> void:
	_time += delta
	var state: CallDirector.CallState = CallDirector.current_state
	var ringing: bool = state == CallDirector.CallState.RINGING
	var active: bool = ringing or state == CallDirector.CallState.CONNECTED or state == CallDirector.CallState.ASSESSMENT
	var pulse: float = 0.5 + 0.5 * sin(_time * (9.0 if ringing else 2.5))
	if _lit != null:
		_lit.visible = active and (not ringing or pulse > 0.35 or GameSettings.reduce_flashing)
	if _glow != null:
		_glow.visible = active
		_glow.light_energy = _energy * (0.8 if GameSettings.reduce_flashing else 0.55 + 0.45 * pulse)
