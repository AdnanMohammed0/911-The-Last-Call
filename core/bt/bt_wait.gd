## RUNNING for `seconds` (optionally a random extra up to `random_extra`), then SUCCESS.
## Authority: HOST
class_name BTWait
extends BTNode

@export var seconds: float = 1.0
@export var random_extra: float = 0.0


func get_display_name() -> String:
	return label if not label.is_empty() else "Wait %.1fs" % seconds


func _enter(_agent: Node, bb: BTBlackboard) -> void:
	state(bb)["until"] = bb.time + seconds + randf() * random_extra


func _tick(_agent: Node, bb: BTBlackboard) -> BTNode.Status:
	var until: float = state(bb).get("until", bb.time)
	return BTNode.Status.SUCCESS if bb.time >= until else BTNode.Status.RUNNING
