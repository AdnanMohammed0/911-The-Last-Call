extends GutTest

const CallDirectorScript := preload("res://autoload/call_director.gd")

var _director: CallDirectorScript


func before_each() -> void:
	_director = CallDirectorScript.new()
	add_child_autofree(_director)
	_director.reset()


func _create_dummy_call(id: StringName, earliest_min: int = 0, ring_time: float = 20.0) -> CallData:
	var call: CallData = CallData.new()
	call.id = id
	call.title = "Test Emergency Call"
	call.truth = CallData.Truth.GENUINE
	call.earliest_minute = earliest_min
	call.ring_timeout_seconds = ring_time
	call.patience_seconds = 120.0
	return call


func test_shift_clock_ticks_with_time_scale() -> void:
	_director.start_shift()
	_director.time_scale = 60.0 # 1 real sec = 60 in-game sec = 1 in-game min
	
	assert_eq(_director.shift_clock_minutes, 0)
	_director._process_shift_clock(1.0) # 1 sec * 60 = 60s -> +1 minute
	assert_eq(_director.shift_clock_minutes, 1)


func test_shift_clock_pause_and_resume() -> void:
	_director.start_shift()
	_director.time_scale = 60.0
	_director.pause_shift()
	_director._process_shift_clock(2.0)
	assert_eq(_director.shift_clock_minutes, 0)
	
	_director.resume_shift()
	_director._process_shift_clock(1.0)
	assert_eq(_director.shift_clock_minutes, 1)


func test_call_registration_and_queuing() -> void:
	var call: CallData = _create_dummy_call(&"call_test_01", 10)
	_director.register_call(call)
	assert_true(_director.registered_calls.has(&"call_test_01"))
	
	_director.enqueue_call(&"call_test_01")
	assert_eq(_director.call_queue.size(), 1)
	assert_eq(_director.current_state, CallDirectorScript.CallState.IDLE)
	
	# Clock hasn't reached earliest_minute yet
	_director.set_shift_time(5)
	assert_eq(_director.current_state, CallDirectorScript.CallState.IDLE)
	
	# Advance clock to trigger time
	_director.set_shift_time(10)
	assert_eq(_director.current_state, CallDirectorScript.CallState.RINGING)
	assert_eq(_director.active_call_id, &"call_test_01")


func test_call_ringing_timeout_transitions_to_missed() -> void:
	var call: CallData = _create_dummy_call(&"call_miss_test", 0, 5.0)
	_director.register_call(call)
	_director.ring_call(&"call_miss_test")
	
	assert_eq(_director.current_state, CallDirectorScript.CallState.RINGING)
	assert_eq(_director.ring_timer, 5.0)
	
	# Tick down ring timer
	_director._process_call_lifecycle(3.0)
	assert_eq(_director.current_state, CallDirectorScript.CallState.RINGING)
	
	_director._process_call_lifecycle(2.5)
	# Should have missed and returned to idle
	assert_eq(_director.current_state, CallDirectorScript.CallState.IDLE)
	assert_true(_director.call_history.has(&"call_miss_test"))
	assert_eq(_director.call_history[&"call_miss_test"]["state"], "missed")


func test_call_answer_and_hangup_lifecycle() -> void:
	var call: CallData = _create_dummy_call(&"call_active_test", 0, 20.0)
	_director.register_call(call)
	_director.ring_call(&"call_active_test")
	
	# Answer call
	_director._answer_call()
	assert_eq(_director.current_state, CallDirectorScript.CallState.CONNECTED)
	assert_true(_director.is_active(&"call_active_test"))
	
	# Hangup call
	_director._hangup_call(&"test_hangup")
	assert_eq(_director.current_state, CallDirectorScript.CallState.ASSESSMENT)
	
	# Classify verdict
	_director.submit_verdict(1, &"call_active_test", &"genuine")
	assert_eq(_director.current_state, CallDirectorScript.CallState.IDLE)
	assert_true(_director.call_history.has(&"call_active_test"))
	assert_eq(_director.call_history[&"call_active_test"]["verdict"], &"genuine")
	assert_eq(_director.call_history[&"call_active_test"]["truth"], CallData.Truth.GENUINE)


func test_call_director_snapshot_restore() -> void:
	_director.shift_clock_minutes = 145
	_director.handset_owner_peer_id = 2
	_director.current_state = CallDirectorScript.CallState.RINGING
	_director.active_call_id = &"call_snap_test"
	_director.ring_timer = 14.5
	
	var snap: Dictionary = _director.get_snapshot()
	
	var director2: CallDirectorScript = CallDirectorScript.new()
	add_child_autofree(director2)
	director2.apply_snapshot(snap)
	
	assert_eq(director2.shift_clock_minutes, 145)
	assert_eq(director2.handset_owner_peer_id, 2)
	assert_eq(director2.current_state, CallDirectorScript.CallState.RINGING)
	assert_eq(director2.active_call_id, &"call_snap_test")
	assert_almost_eq(director2.ring_timer, 14.5, 0.01)
