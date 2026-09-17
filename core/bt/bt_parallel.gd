## Ticks every child each tick. Succeeds when `success_threshold` children succeed, fails as soon as that
## becomes impossible, otherwise RUNNING. (e.g. "move to cover" while "keep aiming at target").
## Authority: HOST
class_name BTParallel
extends BTComposite

## 0 = all children must succeed.
@export var success_threshold: int = 0


func _tick(agent: Node, bb: BTBlackboard) -> BTNode.Status:
	var needed: int = children.size() if success_threshold <= 0 else mini(success_threshold, children.size())
	var succeeded: int = 0
	var failed: int = 0
	for child: BTNode in children:
		match _tick_child(child, agent, bb):
			BTNode.Status.SUCCESS:
				succeeded += 1
			BTNode.Status.FAILURE:
				failed += 1
	if succeeded >= needed:
		_abort_others(null, agent, bb)
		return BTNode.Status.SUCCESS
	if children.size() - failed < needed:
		_abort_others(null, agent, bb)
		return BTNode.Status.FAILURE
	return BTNode.Status.RUNNING
