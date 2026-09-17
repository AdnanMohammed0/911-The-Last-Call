## Shovel — tool for digging/burial objectives (GAMEPLAY_MECHANICS §10.2).
## Authority: OWNING PEER (input), HOST (validates interaction).
class_name ShovelTool
extends Node3D

signal dig_started()
signal dig_progress(progress: float)
signal dig_completed()

@export var dig_time: float = 4.0
@export var dig_radius: float = 2.0
@export var cooldown: float = 1.0

var _owner: Player = null
var _digging: bool = false
var _dig_start_time: float = 0.0
var _dig_target: Node = null
var _last_dig_msec: int = 0


func _ready() -> void:
	_owner = get_parent() as Player


func _physics_process(delta: float) -> void:
	if not _digging:
		return
	
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _dig_start_time
	var progress: float = elapsed / dig_time
	progress = clampf(progress, 0.0, 1.0)
	
	dig_progress.emit(progress)
	
	# Check for interruption
	if _owner != null:
		var moved: float = _owner.global_position.distance_to(_dig_start_pos)
		if moved > 1.0:
			_interrupt_dig(false)
			return
		if not _owner.get_health().is_alive():
			_interrupt_dig(false)
			return
	
	if progress >= 1.0:
		_complete_dig()


## Starts digging at the target location.
## Returns true if digging started.
func start_dig(target: Node) -> bool:
	if _digging:
		return false
	if _owner == null or not _owner.get_health().is_alive():
		return false
	
	var now: int = Time.get_ticks_msec()
	if now - _last_dig_msec < cooldown * 1000:
		return false
	
	_digging = true
	_dig_start_time = Time.get_ticks_msec() / 1000.0
	_dig_target = target
	_last_dig_msec = now
	
	dig_started.emit()
	EventBus.noise_event.emit(global_position, 3.0, _owner.peer_id)
	
	return true


func _complete_dig() -> void:
	_digging = false
	dig_progress.emit(1.0)
	dig_completed.emit()
	
	if _dig_target != null and _dig_target.has_method("on_bones_buried"):
		_dig_target.on_bones_buried()
	
	EventBus.noise_event.emit(global_position, 3.0, _owner.peer_id)


func _interrupt_dig(success: bool) -> bool:
	_digging = false
	dig_progress.emit(0.0)
	dig_completed.emit()
	return success


## Returns true if currently digging
func is_digging() -> bool:
	return _digging


## Gets remaining dig time
func get_remaining_time() -> float:
	if not _digging:
		return 0.0
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _dig_start_time
	return maxf(0.0, dig_time - elapsed)