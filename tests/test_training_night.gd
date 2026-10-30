extends GutTest


func after_each() -> void:
	GameState.training_active = false
	CallDirector.reset()
	CallDirector.registered_calls.clear()
	MissionDirector.reset()


func test_training_call_is_playable_and_stays_out_of_regular_schedule() -> void:
	var call: CallData = load(DispatchSetup.TRAINING_CALL) as CallData
	assert_not_null(call)
	assert_true(CallValidator.is_playable(call))
	assert_eq(call.id, TrainingNight.CALL_ID)
	assert_eq(call.truth, CallData.Truth.PRANK)
	for path: String in CallValidator._find_resources(CallValidator.CALLS_DIR):
		assert_ne(path, DispatchSetup.TRAINING_CALL)


func test_station_training_registers_only_drill_and_guide_can_ring_it() -> void:
	GameState.training_active = true
	var packed: PackedScene = load("res://scenes/dispatch/operations_room.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var room: Node3D = packed.instantiate() as Node3D
	add_child_autofree(room)
	var guide: TrainingNight = room.get_node_or_null(^"TrainingNight") as TrainingNight
	assert_not_null(guide)
	assert_true(guide.visible)
	assert_eq(CallDirector.registered_calls.size(), 1)
	assert_true(CallDirector.registered_calls.has(TrainingNight.CALL_ID))
	assert_true(CallDirector.call_queue.is_empty())
	assert_eq(CallDirector.current_state, CallDirector.CallState.IDLE)
	guide.step = TrainingNight.Step.PHONE
	guide._ring_call()
	assert_eq(CallDirector.current_state, CallDirector.CallState.RINGING)
	assert_eq(CallDirector.active_call_id, TrainingNight.CALL_ID)
	guide._on_connected(TrainingNight.CALL_ID, CallDirector.active_call)
	assert_eq(guide.step, TrainingNight.Step.REPLY)
	guide._on_dialogue_node(&"confirmed", &"caller", "", [])
	assert_eq(guide.step, TrainingNight.Step.VERDICT)
	guide._on_classified(TrainingNight.CALL_ID, &"prank")
	assert_eq(guide.step, TrainingNight.Step.COMPLETE)
