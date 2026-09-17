## Spectral Tone Emitter — emits reverse-frequency tone to banish anomalies (GAMEPLAY_MECHANICS §9).
## 8-second channel, 2 uses per mission. Medic only. Authority: HOST (validates channel), OWNING PEER (input).
class_name SpectralToneEmitter
extends Node3D

signal channel_started(duration: float)
signal channel_progress(progress: float)
signal channel_completed(success: bool)
signal anomaly_banished(anomaly_id: StringName)

@export var channel_duration: float = 8.0
@export var effective_range: float = 10.0
@export var channel_interrupt_threshold: float = 1.5  # meters movement to interrupt

var _owner: Player = null
var _channeling: bool = false
var _channel_start_time: float = 0.0
var _channel_start_pos: Vector3 = Vector3.INF
var _target_anomaly: Node = null
var _uses_remaining: int = 2


func _ready() -> void:
	_owner = get_parent() as Player


func _physics_process(delta: float) -> void:
	if not _channeling:
		return
	
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _channel_start_time
	var progress: float = elapsed / channel_duration
	progress = clampf(progress, 0.0, 1.0)
	
	channel_progress.emit(progress)
	
	# Check for interruption (movement or damage)
	if _owner != null:
		if _channel_start_pos != Vector3.INF:
			var moved: float = _channel_start_pos.distance_to(_owner.global_position)
			if moved > channel_interrupt_threshold:
				_interrupt_channel(false)
				return
		if not _owner.get_health().is_alive():
			_interrupt_channel(false)
			return
	
	if progress >= 1.0:
		_complete_channel()


## Starts the banish channel on the nearest anomaly in range.
## Returns true if channel started.
func start_channel() -> bool:
	if not multiplayer.is_server():
		return false
	if _channeling:
		return false
	if _owner == null or not _owner.get_health().is_alive():
		return false
	if _uses_remaining <= 0:
		return false
	
	# Find nearest anomaly in range
	var nearest: Node = _find_nearest_anomaly()
	if nearest == null:
		return false
	
	_target_anomaly = nearest
	_channeling = true
	_channel_start_time = Time.get_ticks_msec() / 1000.0
	_channel_start_pos = _owner.global_position
	_uses_remaining -= 1
	
	channel_started.emit(channel_duration)
	
	# Visual/audio feedback
	EventBus.noise_event.emit(global_position, 15.0, _owner.peer_id)
	
	return true


func _find_nearest_anomaly() -> Node:
	var best: Node = null
	var best_dist: float = effective_range
	
	for node: Node in get_tree().get_nodes_in_group("anomalies"):
		var dist: float = global_position.distance_to(node.global_position)
		if dist < best_dist:
			best = node
			best_dist = dist
	
	return best


func _complete_channel() -> bool:
	if _target_anomaly == null or not is_instance_valid(_target_anomaly):
		_interrupt_channel(false)
		return false
	
	_channeling = false
	channel_progress.emit(1.0)
	channel_completed.emit(true)
	
	# Trigger anomaly banishment
	if _target_anomaly.has_method("on_reverse_tone_complete"):
		_target_anomaly.on_reverse_tone_complete()
		anomaly_banished.emit(_target_anomaly.get_name())
		return true
	elif _target_anomaly.has_method("banish"):
		_target_anomaly.banish()
		anomaly_banished.emit(_target_anomaly.get_name())
		return true
	
	return false


func _interrupt_channel(success: bool) -> void:
	_channeling = false
	_target_anomaly = null
	_channel_progress.emit(0.0)
	channel_completed.emit(success)
	EventBus.noise_event.emit(global_position, 5.0, _owner.peer_id if _owner != null else 0)


## Returns true if currently channeling
func is_channeling() -> bool:
	return _channeling


## Gets remaining channel time
func get_remaining_time() -> float:
	if not _channeling:
		return 0.0
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _channel_start_time
	return maxf(0.0, channel_duration - elapsed)


## Gets remaining uses
func get_uses_remaining() -> int:
	return _uses_remaining


## Refills uses (for testing or mission reset)
func refill_uses() -> void:
	_uses_remaining = 2