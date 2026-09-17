## Base for single-child nodes. `mode` picks the behaviour so authored trees need one decorator type:
##  INVERT      SUCCESS <-> FAILURE
##  SUCCEED     always SUCCESS once the child finishes
##  REPEAT      re-run the child `count` times (0 = forever) while it succeeds
##  COOLDOWN    after the child finishes, FAILURE for `seconds`
##  TIME_LIMIT  FAILURE (and abort the child) when it has been RUNNING longer than `seconds`
## Authority: HOST
class_name BTDecorator
extends BTNode

enum Mode { INVERT, SUCCEED, REPEAT, COOLDOWN, TIME_LIMIT }

@export var mode: Mode = Mode.INVERT
@export var child: BTNode
@export var count: int = 0
@export var seconds: float = 1.0


func get_children() -> Array[BTNode]:
	return [child] if child != null else []


func get_display_name() -> String:
	var mode_name: String = Mode.keys()[mode]
	return label if not label.is_empty() else mode_name.capitalize()


func _tick(agent: Node, bb: BTBlackboard) -> BTNode.Status:
	if child == null:
		return BTNode.Status.FAILURE
	var memory: Dictionary = bb.persistent_state(get_instance_id())
	match mode:
		Mode.COOLDOWN:
			var ready_at: float = memory.get("ready_at", -1.0)
			if bb.time < ready_at:
				return BTNode.Status.FAILURE
		Mode.TIME_LIMIT:
			var running: Dictionary = state(bb)
			if not running.has("started"):
				running["started"] = bb.time
			var started: float = running["started"]
			if bb.time - started > seconds:
				child.abort(agent, bb)
				return BTNode.Status.FAILURE

	bb.push_depth()
	var status: BTNode.Status = child.tick(agent, bb)
	bb.pop_depth()

	match mode:
		Mode.INVERT:
			if status == BTNode.Status.SUCCESS:
				return BTNode.Status.FAILURE
			if status == BTNode.Status.FAILURE:
				return BTNode.Status.SUCCESS
		Mode.SUCCEED:
			if status != BTNode.Status.RUNNING:
				return BTNode.Status.SUCCESS
		Mode.REPEAT:
			if status == BTNode.Status.SUCCESS:
				var running: Dictionary = state(bb)
				var done: int = running.get("done", 0) + 1
				running["done"] = done
				if count > 0 and done >= count:
					return BTNode.Status.SUCCESS
				return BTNode.Status.RUNNING
		Mode.COOLDOWN:
			if status != BTNode.Status.RUNNING:
				memory["ready_at"] = bb.time + seconds
	return status
