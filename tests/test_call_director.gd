extends GutTest

@warning_ignore_start("unsafe_call_argument")
@warning_ignore_start("unsafe_cast")

const CallDirectorScript := preload("res://autoload/call_director.gd")

var _director: CallDirectorScript
var _mock_stress_profile: StressProfile
var _mock_dialogue_graph: DialogueGraph


func before_each() -> void:
	_director = CallDirectorScript.new()
	add_child_autofree(_director)
	_director.reset()

	# Create mock resources for dialogue
	_mock_stress_profile = StressProfile.new()
	_mock_stress_profile.baseline_heart_rate = 80

	_mock_dialogue_graph = DialogueGraph.new()
	_mock_dialogue_graph.initial_node_id = &"start"
	var start_node = DialogueNode.new()
	start_node.id = &"start"
	start_node.speaker = &"caller"
	start_node.line = "Help me!"
	_mock_dialogue_graph.add_node(start_node)


func _create_dummy_call(id: StringName, earliest_min: int = 0, ring_time: float = 20.0) -> CallData:
	var call: CallData = CallData.new()
	call.id = id
	call.title = "Test Emergency Call"
	call.truth = CallData.Truth.GENUINE
	call.earliest_minute = earliest_min
	call.ring_timeout_seconds = ring_time
	call.patience_seconds = 120.0
	call.stress_profile = _mock_stress_profile
	call.dialogue = _mock_dialogue_graph
	return call


# --- Existing Tests (Shift Clock, Call Queuing, Lifecycle) ---

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


# --- P2-06 Timer Pressure Modifier Tests ---

func test_low_trust_applies_penalty() -> void:
	# Need GameState for trust check
	var game_state = GameState.new()
	add_child_autofree(game_state)
	game_state.public_trust = 30  # Below 40 threshold
	
	var call: CallData = _create_dummy_call(&"trust_test", 0, 20.0)
	call.patience_seconds = 180.0
	_director.register_call(call)
	_director.ring_call(&"trust_test")
	_director._answer_call()
	
	# Trust < 40 should apply 0.75 multiplier: 180 * 0.75 = 135
	assert_almost_eq(_director.get_current_patience(), 135.0, 0.1)
	assert_almost_eq(_director.get_max_patience(), 135.0, 0.1)


func test_high_trust_no_penalty() -> void:
	var game_state = GameState.new()
	add_child_autofree(game_state)
	game_state.public_trust = 75  # Above 40 threshold
	
	var call: CallData = _create_dummy_call(&"trust_test_2", 0, 20.0)
	call.patience_seconds = 180.0
	_director.register_call(call)
	_director.ring_call(&"trust_test_2")
	_director._answer_call()
	
	# Trust >= 40 should not apply penalty
	assert_almost_eq(_director.get_current_patience(), 180.0, 0.1)
	assert_almost_eq(_director.get_max_patience(), 180.0, 0.1)


func test_rapport_bonus_applied_once() -> void:
	var call: CallData = _create_dummy_call(&"rapport_test", 0, 20.0)
	call.patience_seconds = 180.0
	_director.register_call(call)
	_director.ring_call(&"rapport_test")
	_director._answer_call()
	
	var initial_patience: float = _director.get_current_patience()
	
	# Apply rapport once
	var result1: bool = _director.apply_rapport()
	assert_true(result1)
	assert_almost_eq(_director.get_current_patience(), initial_patience + 30.0, 0.1)
	
	# Apply rapport again - should fail
	var result2: bool = _director.apply_rapport()
	assert_false(result2)
	assert_almost_eq(_director.get_current_patience(), initial_patience + 30.0, 0.1)


func test_challenge_penalty_stacks() -> void:
	var call: CallData = _create_dummy_call(&"challenge_test", 0, 20.0)
	call.patience_seconds = 180.0
	_director.register_call(call)
	_director.ring_call(&"challenge_test")
	_director._answer_call()
	
	var initial_patience: float = _director.get_current_patience()
	
	# Apply first challenge penalty
	var result1: bool = _director.apply_challenge_penalty()
	assert_true(result1)
	assert_almost_eq(_director.get_current_patience(), initial_patience - 60.0, 0.1)
	
	# Apply second challenge penalty - should stack
	var result2: bool = _director.apply_challenge_penalty()
	assert_true(result2)
	assert_almost_eq(_director.get_current_patience(), initial_patience - 120.0, 0.1)


func test_choice_patience_delta() -> void:
	var call: CallData = _create_dummy_call(&"choice_test", 0, 20.0)
	call.patience_seconds = 180.0
	_director.register_call(call)
	_director.ring_call(&"choice_test")
	_director._answer_call()
	
	var initial_patience: float = _director.get_current_patience()
	
	# Apply positive delta
	_director.apply_choice_patience_delta(15.0)
	assert_almost_eq(_director.get_current_patience(), initial_patience + 15.0, 0.1)
	
	# Apply negative delta
	_director.apply_choice_patience_delta(-10.0)
	assert_almost_eq(_director.get_current_patience(), initial_patience + 5.0, 0.1)


func test_rapport_and_challenge_combined() -> void:
	var call: CallData = _create_dummy_call(&"combined_test", 0, 20.0)
	call.patience_seconds = 180.0
	_director.register_call(call)
	_director.ring_call(&"combined_test")
	_director._answer_call()
	
	var initial_patience: float = _director.get_current_patience()
	
	# Apply rapport (+30)
	_director.apply_rapport()
	assert_almost_eq(_director.get_current_patience(), initial_patience + 30.0, 0.1)
	
	# Apply challenge penalty (-60)
	_director.apply_challenge_penalty()
	assert_almost_eq(_director.get_current_patience(), initial_patience - 30.0, 0.1)
	
	# Max patience should include rapport but not challenge penalties
	assert_almost_eq(_director.get_max_patience(), initial_patience + 30.0, 0.1)


func test_modifiers_reset_on_new_call() -> void:
	var call1: CallData = _create_dummy_call(&"reset_test_1", 0, 20.0)
	call1.patience_seconds = 180.0
	_director.register_call(call1)
	_director.ring_call(&"reset_test_1")
	_director._answer_call()
	
	_director.apply_rapport()
	_director.apply_challenge_penalty()
	
	# End first call
	_director._hangup_call(&"test")
	_director.submit_verdict(1, &"reset_test_1", &"genuine")
	
	# Start second call
	var call2: CallData = _create_dummy_call(&"reset_test_2", 0, 20.0)
	call2.patience_seconds = 180.0
	_director.register_call(call2)
	_director.ring_call(&"reset_test_2")
	_director._answer_call()
	
	# Modifiers should be reset
	assert_almost_eq(_director.get_current_patience(), 180.0, 0.1)
	
	# Rapport should be available again
	assert_true(_director.apply_rapport())
	assert_almost_eq(_director.get_current_patience(), 210.0, 0.1)