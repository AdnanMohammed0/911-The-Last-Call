## Wires the operations room into the call system: registers every authored call on every peer (clients
## need the CallData to show caller info), starts the shift clock, queues every call that has not been
## handled yet by its `earliest_minute` (the shift schedule), and forwards "Start test call" from any
## player's terminal.
## Authority: HOST (ringing) / every peer (registration, UI)
class_name DispatchSetup
extends Node3D

const TEST_CALL: String = "res://data/calls/slice/call_closet_monster.tres"

## Seconds after the room loads before the host rings the test call (0 = never automatically).
@export var auto_test_call_delay: float = 0.0
@export var clock_label: Label3D

var _auto_timer: float = 0.0
var _auto_done: bool = false
## Host: seconds the line has been quiet (no call, no response in progress).
var _quiet_seconds: float = 0.0
var _shift_done: bool = false

## Seconds of silence before the next queued call rings early (keeps the shift moving, so players
## never wait long between calls).
@export var max_quiet_seconds: float = 12.0


func _ready() -> void:
	for path: String in CallValidator._find_resources(CallValidator.CALLS_DIR):
		var call: CallData = load(path) as CallData
		if CallValidator.is_playable(call):
			CallDirector.register_call(call)
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal == null:
		terminal = get_node_or_null(^"TerminalLayer/DispatchTerminal") as DispatchTerminal
	if terminal != null:
		terminal.test_call_requested.connect(request_test_call)
	if multiplayer.is_server():
		CallDirector.start_shift()
		queue_shift_calls()


## Host: queue every registered call that has not rung yet, earliest first.
func queue_shift_calls() -> void:
	if not multiplayer.is_server():
		return
	var pending: Array[CallData] = []
	for call_id: StringName in CallDirector.registered_calls:
		if CallDirector.call_history.has(call_id) or call_id in CallDirector.call_queue or call_id == CallDirector.active_call_id:
			continue
		pending.append(CallDirector.registered_calls[call_id])
	pending.sort_custom(func(a: CallData, b: CallData) -> bool: return a.earliest_minute < b.earliest_minute)
	for call: CallData in pending:
		CallDirector.enqueue_call(call.id)
	MissionDirector.set_calls_total(CallDirector.registered_calls.size())


func _process(delta: float) -> void:
	if clock_label != null:
		var minutes: int = CallDirector.shift_clock_minutes
		clock_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	if multiplayer.is_server():
		_pace_calls(delta)
	if not multiplayer.is_server() or _auto_done or auto_test_call_delay <= 0.0:
		return
	_auto_timer += delta
	if _auto_timer >= auto_test_call_delay:
		_auto_done = true
		ring_test_call()


## Host: ring the next call early after a quiet spell, and roll over to the next shift when all are handled.
func _pace_calls(delta: float) -> void:
	var line_free: bool = CallDirector.current_state == CallDirector.CallState.IDLE
	if not line_free or MissionDirector.state != MissionDirector.State.IDLE:
		_quiet_seconds = 0.0
		return
	_quiet_seconds += delta
	if not CallDirector.call_queue.is_empty():
		_shift_done = false
		if _quiet_seconds >= max_quiet_seconds:
			_quiet_seconds = 0.0
			var next_id: StringName = CallDirector.call_queue.pop_front()
			CallDirector.ring_call(next_id)
	elif not _shift_done and _quiet_seconds >= 6.0 and CallDirector.call_history.size() >= CallDirector.registered_calls.size():
		_shift_done = true
		MissionDirector.complete_shift()
		CallDirector.call_history.clear()
		CallDirector.set_shift_time(0)
		_quiet_seconds = -20.0
		queue_shift_calls()


## Any peer: ask the host to ring the test call.
func request_test_call() -> void:
	if multiplayer.is_server():
		ring_test_call()
	else:
		_rpc_request_test_call.rpc_id(1)


## Host: ring the slice test call if the line is free. Returns true when it rang.
func ring_test_call() -> bool:
	if not multiplayer.is_server():
		return false
	var state: int = CallDirector.current_state
	if state != 0 and state != 4 and state != 5:  # IDLE / COMPLETED / MISSED
		return false
	var call: CallData = load(TEST_CALL) as CallData
	CallDirector.register_call(call)
	CallDirector.current_state = 0
	CallDirector.ring_call(call.id)
	return CallDirector.current_state == 1


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_test_call() -> void:
	if RpcGuard.is_host(self) and RpcGuard.is_registered(RpcGuard.sender_id(self)):
		ring_test_call()
