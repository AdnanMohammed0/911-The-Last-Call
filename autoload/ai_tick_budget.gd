## Shared host AI budget. Two rotating cohorts preserve 10 Hz AI ticks at 20 physics FPS.
extends Node

const COHORTS: int = 2

@export var max_jobs_per_physics_frame: int = 12
@export var max_ai_usec_per_physics_frame: int = 3000

var jobs_this_frame: int = 0
var deferred_this_frame: int = 0
var total_deferred: int = 0
var _frame: int = -1
var _frame_started_usec: int = 0


func try_consume(job: Node) -> bool:
	if not multiplayer.is_server():
		return false
	var frame: int = Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		jobs_this_frame = 0
		deferred_this_frame = 0
		_frame_started_usec = 0
	if int(job.get_instance_id() % COHORTS) != frame % COHORTS:
		return false
	if _frame_started_usec == 0:
		_frame_started_usec = Time.get_ticks_usec()
	if jobs_this_frame >= max_jobs_per_physics_frame or Time.get_ticks_usec() - _frame_started_usec >= max_ai_usec_per_physics_frame:
		deferred_this_frame += 1
		total_deferred += 1
		return false
	jobs_this_frame += 1
	return true
