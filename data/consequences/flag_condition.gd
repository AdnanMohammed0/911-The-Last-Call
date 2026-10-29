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
			return values_equal(v, value)
		Op.NEQ:
			return not values_equal(v, value)
		Op.GT:
			return comparable(v, value) and v > value
		Op.GTE:
			return comparable(v, value) and v >= value
		Op.LT:
			return comparable(v, value) and v < value
		Op.LTE:
			return comparable(v, value) and v <= value
	return false


## Equality that never errors on mismatched types (Godot 4 raises on e.g. int == bool): numbers compare
## with numbers, String with StringName, anything else only with its own type.
static func values_equal(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return typeof(a) == typeof(b)
	return comparable(a, b) and a == b


static func comparable(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta == TYPE_NIL or tb == TYPE_NIL:
		return false
	var numbers: Array[int] = [TYPE_INT, TYPE_FLOAT]
	var strings: Array[int] = [TYPE_STRING, TYPE_STRING_NAME]
	return ta == tb or (ta in numbers and tb in numbers) or (ta in strings and tb in strings)
