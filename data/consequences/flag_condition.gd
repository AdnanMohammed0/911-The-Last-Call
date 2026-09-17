## Condition over flags or events evaluated by FlagSystem or GameState (ARCHITECTURE §7.2).
class_name FlagCondition
extends Resource

enum Op { EQ, NEQ, GT, GTE, LT, LTE, HAS_EVENT }

@export var key: StringName = &""
@export var op: Op = Op.EQ
@export var value: Variant = null


func evaluate(fs: Object = null) -> bool:
	if fs == null:
		return true
	if op == Op.HAS_EVENT:
		if fs.has_method("has_event"):
			var ev_res: Variant = fs.call("has_event", key, value)
			return ev_res == true
		return false
	
	var v: Variant = null
	if fs.has_method("get_flag"):
		v = fs.call("get_flag", key)
	elif key in fs:
		v = fs.get(key)
	
	match op:
		Op.EQ:
			return v == value
		Op.NEQ:
			return v != value
		Op.GT:
			return v != null and value != null and v > value
		Op.GTE:
			return v != null and value != null and v >= value
		Op.LT:
			return v != null and value != null and v < value
		Op.LTE:
			return v != null and value != null and v <= value
	return false
