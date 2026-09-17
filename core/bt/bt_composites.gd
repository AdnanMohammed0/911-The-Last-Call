## Base for nodes with several children (BTSelector, BTSequence, BTParallel).
## Authority: HOST
class_name BTComposite
extends BTNode

@export var children: Array[BTNode] = []


func get_children() -> Array[BTNode]:
	return children


func _tick_child(child: BTNode, agent: Node, bb: BTBlackboard) -> BTNode.Status:
	bb.push_depth()
	var status: BTNode.Status = child.tick(agent, bb)
	bb.pop_depth()
	return status


## Abort every RUNNING child except `keep` (a higher-priority branch took over).
func _abort_others(keep: BTNode, agent: Node, bb: BTBlackboard) -> void:
	for child: BTNode in children:
		if child != keep:
			child.abort(agent, bb)
