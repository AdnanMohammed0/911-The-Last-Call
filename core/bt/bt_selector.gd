## Tries children in priority order every tick; returns the first non-FAILURE result.
## Reactive: a higher-priority child that becomes possible interrupts (aborts) a lower RUNNING one.
## Authority: HOST
class_name BTSelector
extends BTComposite


func _tick(agent: Node, bb: BTBlackboard) -> BTNode.Status:
	for child: BTNode in children:
		var status: BTNode.Status = _tick_child(child, agent, bb)
		if status != BTNode.Status.FAILURE:
			_abort_others(child, agent, bb)
			return status
	return BTNode.Status.FAILURE
