## Faulty fluorescent fixture: steady most of the time, then a short burst of flickering every few seconds.
## Stays steady when the "Reduce flashing" accessibility option is on.
## Add as a child of a light fixture; it drives every Light3D and every "Tube*" mesh under that fixture.
## Authority: LOCAL (purely visual, unsynchronised on purpose)
class_name FlickerLight
extends Node

@export var min_gap: float = 4.0
@export var max_gap: float = 12.0

var _lights: Array[Light3D] = []
var _energy: Array[float] = []
var _tubes: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _wait: float = 0.0
var _burst: float = 0.0
var _toggle: float = 0.0
var _lit: bool = true


func _ready() -> void:
	_rng.randomize()
	var fixture: Node = get_parent()
	for node: Node in fixture.find_children("*", "Light3D", true, false):
		var light: Light3D = node as Light3D
		_lights.append(light)
		_energy.append(light.light_energy)
	for node: Node in fixture.find_children("Tube*", "Node3D", true, false):
		_tubes.append(node as Node3D)
	_wait = _rng.randf_range(min_gap, max_gap)


func _process(delta: float) -> void:
	if GameSettings.reduce_flashing:
		if not _lit:
			_set_lit(true)
		_burst = 0.0
		return
	if _burst <= 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_burst = _rng.randf_range(0.25, 1.1)
		return
	_burst -= delta
	_toggle -= delta
	if _toggle <= 0.0:
		_toggle = _rng.randf_range(0.03, 0.12)
		_set_lit(not _lit)
	if _burst <= 0.0:
		_set_lit(true)
		_wait = _rng.randf_range(min_gap, max_gap)


func _set_lit(lit: bool) -> void:
	_lit = lit
	for i: int in _lights.size():
		_lights[i].light_energy = _energy[i] if lit else _energy[i] * 0.08
	for tube: Node3D in _tubes:
		tube.visible = lit
