## Host-driven basement flood. The Drowned Woman raises the surface while hunting;
## banishment lets it recede. The lake outside uses the same shader but stays still.
class_name LakeWater
extends Node3D

@export var surface: MeshInstance3D
@export var anomaly: DrownedWoman
@export var low_height: float = -2.28
@export var high_height: float = -0.34
@export var recede_speed: float = 0.18

var level: float = 0.0
var target_level: float = 0.0
var _last_sent: float = -1.0


func _ready() -> void:
	if anomaly != null:
		anomaly.water_level_changed.connect(_on_water_level_changed)
		anomaly.state_entered.connect(_on_anomaly_state_entered)
	_apply_level()


func _process(delta: float) -> void:
	if not multiplayer.is_server() or is_equal_approx(level, target_level):
		return
	level = move_toward(level, target_level, delta * recede_speed)
	_apply_level()
	if absf(level - _last_sent) >= 0.015 or is_equal_approx(level, target_level):
		_last_sent = level
		_sync_level.rpc(level)


func set_level(value: float) -> void:
	level = clampf(value, 0.0, 1.0)
	target_level = level
	_apply_level()


func _on_water_level_changed(value: float) -> void:
	if multiplayer.is_server():
		target_level = clampf(value, 0.0, 1.0)


func _on_anomaly_state_entered(state: StringName) -> void:
	if multiplayer.is_server() and state == DrownedWoman.BANISHED:
		target_level = 0.0


func _apply_level() -> void:
	if surface == null:
		return
	surface.position.y = lerpf(low_height, high_height, level)
	var material: ShaderMaterial = surface.material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter(&"rise_fraction", level)


@rpc("authority", "call_local", "unreliable_ordered")
func _sync_level(value: float) -> void:
	if multiplayer.is_server():
		return
	set_level(value)
