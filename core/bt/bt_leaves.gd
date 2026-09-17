## Leaf that calls a method on the agent. Conditions return bool (true = SUCCESS); actions return a
## BTNode.Status (or bool). Archetypes implement their actions as agent methods, e.g. `act_move_to_cover`.
## Extra `args` are passed after (bb) : method(bb, arg0, arg1...).
## Authority: HOST
class_name BTCall
extends BTNode

@export var method: StringName = &""
@export var args: Array = []


func get_display_name() -> String:
	return label if not label.is_empty() else String(method)


func _tick(agent: Node, bb: BTBlackboard) -> BTNode.Status:
	if method == &"" or not agent.has_method(method):
		push_warning("BTCall: agent %s has no method '%s'" % [agent.name, method])
		return BTNode.Status.FAILURE
	var result: Variant = agent.callv(method, [bb] + args)
	if result is bool:
		return BTNode.Status.SUCCESS if result else BTNode.Status.FAILURE
	if result is int:
		var value: int = result
		return value as BTNode.Status
	return BTNode.Status.SUCCESS


func _exit(agent: Node, bb: BTBlackboard, status: BTNode.Status) -> void:
	# Lets long actions clean up (stop moving, release a claimed cover point) when interrupted.
	var cleanup: StringName = StringName(String(method) + "_exit")
	if status == BTNode.Status.FAILURE and agent.has_method(cleanup):
		agent.call(cleanup, bb)
