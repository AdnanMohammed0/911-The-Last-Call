## Runs children in order until one fails. With `remember_running` (default) it resumes at the child that
## was RUNNING instead of re-checking earlier children, so multi-step actions (MoveTo → Wait → Look)
## continue. Put conditions in a reactive selector above it when they must be re-checked every tick.
## Authority: HOST
class_name BTSequence
extends BTComposite

@export var remember_running: bool = true


func _tick(agent: Node, bb: BTBlackboard) -> BTNode.Status:
	var memory: Dictionary = state(bb)
	var start: int = memory.get("index", 0) if remember_running else 0
	for i: int in range(start, children.size()):
		var child: BTNode = children[i]
		var status: BTNode.Status = _tick_child(child, agent, bb)
		if status == BTNode.Status.RUNNING:
			memory["index"] = i
			return status
		if status == BTNode.Status.FAILURE:
			return status
	return BTNode.Status.SUCCESS
