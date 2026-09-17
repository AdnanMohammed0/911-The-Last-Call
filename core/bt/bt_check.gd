## Blackboard condition: compares `bb[key]` with `value` (or just checks presence with EXISTS).
## Authority: HOST
class_name BTCheck
extends BTNode

enum Op { EXISTS, EQUAL, NOT_EQUAL, LESS, LESS_EQUAL, GREATER, GREATER_EQUAL }

@export var key: StringName = &""
@export var op: Op = Op.EXISTS
@export var value: Variant = null


func get_display_name() -> String:
	if not label.is_empty():
		return label
	if op == Op.EXISTS:
		return "%s?" % key
	return "%s %s %s" % [key, ["?", "==", "!=", "<", "<=", ">", ">="][op], value]


func _tick(_agent: Node, bb: BTBlackboard) -> BTNode.Status:
	if op == Op.EXISTS:
		return BTNode.Status.SUCCESS if bb.has_value(key) else BTNode.Status.FAILURE
	if not bb.data.has(key):
		return BTNode.Status.FAILURE
	var current: Variant = bb.data[key]
	var ok: bool = false
	match op:
		Op.EQUAL:
			ok = current == value
		Op.NOT_EQUAL:
			ok = current != value
		Op.LESS:
			ok = _as_float(current) < _as_float(value)
		Op.LESS_EQUAL:
			ok = _as_float(current) <= _as_float(value)
		Op.GREATER:
			ok = _as_float(current) > _as_float(value)
		Op.GREATER_EQUAL:
			ok = _as_float(current) >= _as_float(value)
	return BTNode.Status.SUCCESS if ok else BTNode.Status.FAILURE


static func _as_float(v: Variant) -> float:
	if v is float:
		var f: float = v
		return f
	if v is int:
		var i: int = v
		return float(i)
	return 0.0
