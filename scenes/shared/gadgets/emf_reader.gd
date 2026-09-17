## EMF Reader — detects electromagnetic field disturbances from anomalies (GAMEPLAY_MECHANICS §9).
## Medic primary; others at 50% accuracy. Authority: OWNING PEER (input), HOST (anomaly state).
class_name EMFReader
extends Node3D

signal emf_level_changed(level: int)
signal anomaly_detected(anomaly_id: StringName, level: int, position: Vector3)

@export var max_range: float = 20.0
@export var update_interval: float = 0.5
@export var accuracy_penalty_non_medic: float = 0.5  # 50% for non-Medics

## Current EMF level (0-5)
var current_level: int = 0
var _accumulator: float = 0.0
var _owner: Player = null
var _is_medic: bool = false


func _ready() -> void:
	_owner = get_parent() as Player
	if _owner != null:
		_is_medic = _owner.class_id == &"medic"


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _owner == null or not _owner.get_health().is_alive():
		return
	
	_accumulator += delta
	if _accumulator < update_interval:
		return
	_accumulator = 0.0
	
	_scan_for_anomalies()


func _scan_for_anomalies() -> void:
	var max_level: int = 0
	var detected_anomaly: StringName = &""
	var anomaly_pos: Vector3 = Vector3.INF
	
	# Scan for anomalies in range
	for node: Node in get_tree().get_nodes_in_group("anomalies"):
		var anomaly: Node = node
		var distance: float = global_position.distance_to(anomaly.global_position)
		if distance > max_range:
			continue
		
		# Get anomaly's EMF emission level (0-5)
		var level: int = _get_anomaly_emf_level(anomaly, distance)
		if level > max_level:
			max_level = level
			detected_anomaly = anomaly.get_name()
			anomaly_pos = anomaly.global_position
	
	# Apply accuracy penalty for non-Medics
	if not _is_medic and max_level > 0:
		max_level = maxi(1, int(max_level * accuracy_penalty_non_medic))
	
	if max_level != current_level:
		current_level = max_level
		emf_level_changed.emit(current_level)
	
	if detected_anomaly != &"" and max_level >= 3:
		anomaly_detected.emit(detected_anomaly, max_level, anomaly_pos)


func _get_anomaly_emf_level(anomaly: Node, distance: float) -> int:
	# Base EMF level from anomaly state
	var base_level: int = 0
	if anomaly.has_method("get_emf_level"):
		base_level = anomaly.get_emf_level()
	elif anomaly.has_method("state"):
		# Drowned Woman state machine mapping
		var state: int = anomaly.state
		match state:
			0: base_level = 1  # DORMANT
			1: base_level = 3  # MANIFEST
			2: base_level = 4  # STALK
			3: base_level = 5  # HUNT
			4: base_level = 5  # ATTACK
			5: base_level = 2  # RETREAT
			6: base_level = 0  # BANISHED
	
	# Distance falloff
	var falloff: float = 1.0 - (distance / max_range)
	return maxi(0, int(base_level * falloff))


## Returns true if EMF level indicates an anomaly nearby (level >= 3)
func is_anomaly_nearby() -> bool:
	return current_level >= 3


## Gets the current EMF level for UI display
func get_emf_level() -> int:
	return current_level