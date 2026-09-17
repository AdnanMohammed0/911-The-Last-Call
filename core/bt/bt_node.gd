## Base behavior tree node (GAMEPLAY_MECHANICS §8.3). Trees are Resources so one tree can be shared by
## many agents: per-agent runtime state lives in the BTBlackboard, never on the node itself.
## Subclasses override `_tick`; `tick` wraps it with enter/exit bookkeeping and debugger tracing.
## Authority: HOST (AI only runs on the host)
class_name BTNode
extends Resource

enum Status { SUCCESS, FAILURE, RUNNING }

## Shown by the BT debugger.
@export var label: String = ""


func tick(agent: Node, bb: BTBlackboard) -> Status:
	var id: int = get_instance_id()
	if not bb.is_running(id):
		_enter(agent, bb)
	var trace_index: int = bb.trace_begin(self)
	var status: Status = _tick(agent, bb)
	bb.trace_end(trace_index, status)
	if status == Status.RUNNING:
		bb.mark_running(id)
	else:
		bb.clear_running(id)
		_exit(agent, bb, status)
	return status


## Called by a parent when this branch is abandoned while RUNNING (a higher-priority branch took over).
func abort(agent: Node, bb: BTBlackboard) -> void:
	var id: int = get_instance_id()
	if bb.is_running(id):
		bb.clear_running(id)
		_exit(agent, bb, Status.FAILURE)
	for child: BTNode in get_children():
		child.abort(agent, bb)


func get_children() -> Array[BTNode]:
	return []


func get_display_name() -> String:
	if not label.is_empty():
		return label
	var node_script: Script = get_script()
	var script_name: String = node_script.get_global_name() if node_script != null else ""
	return script_name if not script_name.is_empty() else "BTNode"


## Per-agent memory for this node.
func state(bb: BTBlackboard) -> Dictionary:
	return bb.node_state(get_instance_id())


func _tick(_agent: Node, _bb: BTBlackboard) -> Status:
	return Status.FAILURE


func _enter(_agent: Node, _bb: BTBlackboard) -> void:
	pass


func _exit(_agent: Node, _bb: BTBlackboard, _status: Status) -> void:
	pass
