## Per-agent behavior tree memory: shared key/value data (target, last known position, flags…),
## private per-node state (timers, child indices), which nodes are RUNNING, and the last tick's trace
## for the debugger.
## Authority: HOST
class_name BTBlackboard
extends RefCounted

var data: Dictionary = {}
## Seconds of simulated time; advanced by BTRunner (lets tests step time deterministically).
var time: float = 0.0
## Last tick: Array of {"node": BTNode, "status": BTNode.Status, "depth": int}.
var last_trace: Array[Dictionary] = []

var _node_states: Dictionary[int, Dictionary] = {}
var _persistent: Dictionary[int, Dictionary] = {}
var _running: Dictionary[int, bool] = {}
var _current_trace: Array[Dictionary] = []
var _depth: int = 0


func get_value(key: StringName, default: Variant = null) -> Variant:
	return data.get(key, default)


func set_value(key: StringName, value: Variant) -> void:
	data[key] = value


func has_value(key: StringName) -> bool:
	return data.has(key) and data[key] != null


func erase(key: StringName) -> void:
	data.erase(key)


func node_state(node_id: int) -> Dictionary:
	if not _node_states.has(node_id):
		_node_states[node_id] = {}
	return _node_states[node_id]


## Node memory that survives the node finishing (cooldowns, counters across runs).
func persistent_state(node_id: int) -> Dictionary:
	if not _persistent.has(node_id):
		_persistent[node_id] = {}
	return _persistent[node_id]


func is_running(node_id: int) -> bool:
	return _running.has(node_id)


func mark_running(node_id: int) -> void:
	_running[node_id] = true


func clear_running(node_id: int) -> void:
	_running.erase(node_id)
	_node_states.erase(node_id)


func begin_tick() -> void:
	_current_trace = []
	_depth = 0


func end_tick() -> void:
	last_trace = _current_trace


func push_depth() -> void:
	_depth += 1


func pop_depth() -> void:
	_depth -= 1


## Parent entries are recorded before their children so the trace reads top-down.
func trace_begin(node: BTNode) -> int:
	_current_trace.append({"node": node, "status": BTNode.Status.FAILURE, "depth": _depth})
	return _current_trace.size() - 1


func trace_end(index: int, status: BTNode.Status) -> void:
	_current_trace[index]["status"] = status


## Readable dump of the last tick (debugger overlay / logs), in evaluation order with indentation.
func format_trace() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in last_trace:
		var node: BTNode = entry["node"]
		var status: BTNode.Status = entry["status"]
		var depth: int = entry["depth"]
		lines.append("%s%s %s" % ["  ".repeat(depth), ["✔", "✘", "…"][status], node.get_display_name()])
	return "\n".join(lines)
