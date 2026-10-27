## Station wall clock: the hour and minute hands follow the night-shift clock (CallDirector), the second
## hand ticks once per real second. Hands are children named HourHand / MinuteHand / SecondHand that turn
## about the local Z axis (the face looks down +Z).
## Authority: LOCAL (reads the replicated shift clock, writes nothing)
class_name AnalogClock
extends Node3D

var _hour: Node3D
var _minute: Node3D
var _second: Node3D


func _ready() -> void:
	_hour = get_node_or_null(^"HourHand") as Node3D
	_minute = get_node_or_null(^"MinuteHand") as Node3D
	_second = get_node_or_null(^"SecondHand") as Node3D


func _process(_delta: float) -> void:
	var minutes: int = CallDirector.shift_clock_minutes
	if _hour != null:
		_hour.rotation.z = -TAU * (float(minutes % 720) / 720.0)
	if _minute != null:
		_minute.rotation.z = -TAU * (float(minutes % 60) / 60.0)
	if _second != null:
		var seconds: int = (Time.get_ticks_msec() / 1000) % 60
		_second.rotation.z = -TAU * (float(seconds) / 60.0)
