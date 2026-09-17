## Small reusable finite state machine. States are Callables registered by name:
##   fsm.add_state(&"hunt", _enter_hunt, _update_hunt, _exit_hunt)
## `update` callables receive delta and may return a StringName to transition (or &"" to stay).
## Authority: whoever owns the logic (anomalies: HOST)
class_name StateMachine
extends RefCounted

signal state_changed(from: StringName, to: StringName)

var current: StringName = &""
var previous: StringName = &""
## Seconds spent in the current state.
var time_in_state: float = 0.0

var _states: Dictionary[StringName, Array] = {}   # name -> [enter, update, exit]


func add_state(state: StringName, enter: Callable = Callable(), update: Callable = Callable(), exit: Callable = Callable()) -> void:
	_states[state] = [enter, update, exit]


func has_state(state: StringName) -> bool:
	return _states.has(state)


func start(state: StringName) -> void:
	current = &""
	transition_to(state)


func transition_to(state: StringName) -> void:
	if not _states.has(state):
		push_error("StateMachine: unknown state '%s'" % state)
		return
	if current != &"":
		var old_callbacks: Array = _states[current]
		var exit: Callable = old_callbacks[2]
		if exit.is_valid():
			exit.call()
	previous = current
	current = state
	time_in_state = 0.0
	var callbacks: Array = _states[state]
	var enter: Callable = callbacks[0]
	if enter.is_valid():
		enter.call()
	state_changed.emit(previous, current)


func update(delta: float) -> void:
	if current == &"":
		return
	time_in_state += delta
	var callbacks: Array = _states[current]
	var update_callable: Callable = callbacks[1]
	if not update_callable.is_valid():
		return
	var next: Variant = update_callable.call(delta)
	if next is StringName:
		var next_state: StringName = next
		if next_state != &"" and next_state != current:
			transition_to(next_state)
