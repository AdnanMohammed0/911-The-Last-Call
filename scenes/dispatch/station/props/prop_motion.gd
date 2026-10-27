## Ambient prop animation for the station dressing (ceiling fans, desk fans, panning cameras): spins around
## a local axis or sweeps back and forth around the parent's Y axis.
## Authority: LOCAL (purely visual; every peer animates its own copy)
class_name PropMotion
extends Node3D

enum Mode { SPIN, SWEEP }

@export var mode: Mode = Mode.SPIN
## SPIN: local rotation axis and speed in degrees per second.
@export var axis: Vector3 = Vector3.UP
@export var speed: float = 90.0
## SWEEP: half-angle in degrees and seconds per full back-and-forth.
@export var sweep_degrees: float = 25.0
@export var sweep_period: float = 8.0
## Seconds added to the clock so neighbouring props do not move in lockstep.
@export var phase: float = 0.0

var _base: Basis
var _time: float = 0.0


func _ready() -> void:
	_base = basis
	_time = phase


func _process(delta: float) -> void:
	_time += delta
	match mode:
		Mode.SPIN:
			var angle: float = deg_to_rad(fmod(speed * _time, 360.0))
			basis = _base * Basis(axis.normalized(), angle)
		Mode.SWEEP:
			var swing: float = deg_to_rad(sweep_degrees) * sin(TAU * _time / sweep_period)
			basis = Basis(Vector3.UP, swing) * _base
