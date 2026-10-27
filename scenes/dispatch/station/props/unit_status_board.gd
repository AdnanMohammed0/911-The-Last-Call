## Dispatch video-wall status list: cycles the county units through radio statuses every few seconds so the
## board never looks frozen. Decorative only; the real call state lives in CallDirector.
## Authority: LOCAL (purely visual)
class_name UnitStatusBoard
extends Label3D

const UNITS: PackedStringArray = ["4-ADAM-12", "4-ADAM-15", "4-LINCOLN-3", "4-KING-7", "4-MARY-2", "MEDIC-41", "ENGINE-9"]
const STATES: PackedStringArray = ["AVAILABLE", "EN ROUTE", "ON SCENE", "TRAFFIC STOP", "OUT OF SERVICE", "AT HOSPITAL", "REPORTS"]

@export var interval: float = 3.5

var _states: PackedInt32Array = PackedInt32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	for i: int in UNITS.size():
		_states.append(_rng.randi_range(0, STATES.size() - 1))
	_render()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < interval:
		return
	_timer = 0.0
	var unit: int = _rng.randi_range(0, UNITS.size() - 1)
	_states[unit] = _rng.randi_range(0, STATES.size() - 1)
	_render()


func _render() -> void:
	var lines: PackedStringArray = []
	for i: int in UNITS.size():
		lines.append("%s   ·   %s" % [UNITS[i], STATES[_states[i]]])
	text = "\n".join(lines)
