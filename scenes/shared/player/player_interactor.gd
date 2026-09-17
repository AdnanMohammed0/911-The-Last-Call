## Finds the Interactable under the crosshair and turns the interact key into press / hold requests.
## Authority: OWNING PEER (only sends intents; the host decides in Interactable).
class_name PlayerInteractor
extends Node

signal focus_changed(target: Interactable)
## 0..1 while holding, -1 when no hold is in progress.
signal hold_progress_changed(progress: float)

@export var reach: float = 3.0
@export_flags_3d_physics var ray_mask: int = 1 | Interactable.LAYER

var focused: Interactable = null

var _hold_time: float = 0.0
var _is_holding: bool = false
var _hold_consumed: bool = false

@onready var _player: Player = get_parent() as Player


func _physics_process(delta: float) -> void:
	var target: Interactable = _find_target()
	if target != focused:
		_cancel_hold()
		focused = target
		focus_changed.emit(focused)

	if not Input.is_action_pressed(&"interact"):
		_hold_consumed = false
		_cancel_hold()
	if focused == null:
		return

	if not focused.is_hold():
		if Input.is_action_just_pressed(&"interact"):
			focused.request_interact()
		return

	if Input.is_action_pressed(&"interact") and not _hold_consumed:
		if not _is_holding:
			_is_holding = true
			_hold_time = 0.0
			focused.request_hold_start()
		_hold_time += delta
		hold_progress_changed.emit(clampf(_hold_time / focused.hold_duration, 0.0, 1.0))
		if _hold_time >= focused.hold_duration:
			focused.request_interact()
			_is_holding = false
			_hold_consumed = true
			hold_progress_changed.emit(-1.0)


func _find_target() -> Interactable:
	var camera: Camera3D = _player.get_camera()
	var origin: Vector3 = camera.global_position
	var to: Vector3 = origin - camera.global_basis.z * reach
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, to, ray_mask, [_player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var candidate_v: Variant = hit["collider"]
	if not (candidate_v is Interactable):
		return null
	var candidate: Interactable = candidate_v
	if candidate == null or not candidate.is_available_to(multiplayer.get_unique_id()):
		return null
	var hit_pos: Vector3 = hit["position"]
	if origin.distance_to(hit_pos) > candidate.max_distance:
		return null
	return candidate


func _cancel_hold() -> void:
	if not _is_holding:
		return
	_is_holding = false
	if is_instance_valid(focused):
		focused.request_hold_cancel()
	hold_progress_changed.emit(-1.0)
