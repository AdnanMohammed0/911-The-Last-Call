## Wires the operations room into the call system: registers every authored call on every peer (clients
## need the CallData to show caller info), starts the shift clock, rings a test call after
## `auto_test_call_delay` seconds on the host, and forwards "Start test call" from any player's terminal.
## Authority: HOST (ringing) / every peer (registration, UI)
class_name DispatchSetup
extends Node3D

const TEST_CALL: String = "res://data/calls/slice/call_closet_monster.tres"

## Seconds after the room loads before the host rings the test call (0 = never automatically).
@export var auto_test_call_delay: float = 15.0
@export var clock_label: Label3D

var _auto_timer: float = 0.0
var _auto_done: bool = false


func _ready() -> void:
	for path: String in CallValidator._find_resources(CallValidator.CALLS_DIR):
		var call: CallData = load(path) as CallData
		if call != null:
			CallDirector.register_call(call)
	var terminal: DispatchTerminal = DispatchTerminal.find(get_tree())
	if terminal == null:
		terminal = get_node_or_null(^"TerminalLayer/DispatchTerminal") as DispatchTerminal
	if terminal != null:
		terminal.test_call_requested.connect(request_test_call)
	if multiplayer.is_server():
		CallDirector.start_shift()


func _process(delta: float) -> void:
	if clock_label != null:
		var minutes: int = CallDirector.shift_clock_minutes
		clock_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	if not multiplayer.is_server() or _auto_done or auto_test_call_delay <= 0.0:
		return
	_auto_timer += delta
	if _auto_timer >= auto_test_call_delay:
		_auto_done = true
		ring_test_call()


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
