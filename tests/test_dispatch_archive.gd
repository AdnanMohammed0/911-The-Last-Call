extends GutTest

const DirectorScript := preload("res://autoload/call_director.gd")

var _saved_roster: Dictionary[int, Dictionary]


func before_each() -> void:
	_saved_roster = NetManager.roster.duplicate(true)
	NetManager.roster[1] = {"name": "Tech", "class_id": &"tech"}


func after_each() -> void:
	NetManager.roster = _saved_roster


func test_deep_lookup_requires_active_record_and_completes_after_30_seconds() -> void:
	var director: DirectorScript = DirectorScript.new()
	add_child_autofree(director)
	var call: CallData = CallData.new()
	call.id = &"live_case"
	var record: RecordEntry = RecordEntry.new()
	record.id = &"plate_42"
	record.title = "Vehicle registration"
	call.records.append(record)
	director.active_call = call
	director.active_call_id = call.id
	director.current_state = director.CallState.CONNECTED
	director.request_records_lookup(&"missing")
	assert_eq(director.records_lookup_id, &"")
	director.request_records_lookup(record.id)
	assert_eq(director.records_lookup_id, record.id)
	director._process_records_lookup(29.0)
	assert_false(record.id in director.records_unlocked)
	director._process_records_lookup(1.0)
	assert_true(record.id in director.records_unlocked)
	assert_true(director.dialogue_runner.revealed_evidence.has(&"evidence_record_plate_42"))
	director.request_records_lookup(record.id)
	assert_eq(director.records_lookup_id, &"")


func test_pattern_link_requires_medic_and_one_prior_case() -> void:
	var director: DirectorScript = DirectorScript.new()
	add_child_autofree(director)
	var call: CallData = CallData.new()
	call.id = &"current_case"
	director.active_call = call
	director.active_call_id = call.id
	director.current_state = director.CallState.CONNECTED
	director.call_history[&"prior_case"] = {"verdict": &"solved"}
	director.request_pattern_link(&"prior_case")
	assert_eq(director.pattern_link_used_call_id, &"")
	NetManager.roster[1] = {"name": "Medic", "class_id": &"medic"}
	director.request_pattern_link(&"missing")
	assert_eq(director.pattern_link_used_call_id, &"")
	director.request_pattern_link(&"prior_case")
	assert_eq(director.pattern_link_used_call_id, call.id)
	assert_true(director.dialogue_runner.revealed_evidence.has(&"evidence_pattern_prior_case_current_case"))
	assert_true(director.case_evidence_by_call[call.id].has(&"evidence_pattern_prior_case_current_case"))
	director.request_pattern_link(&"prior_case")
	assert_eq(director.case_evidence_by_call[call.id].size(), 1)


func test_records_and_case_board_show_shift_entries() -> void:
	var saved_state: Dictionary = CallDirector.get_snapshot()
	var saved_calls: Dictionary[StringName, CallData] = CallDirector.registered_calls.duplicate()
	var saved_history: Dictionary[StringName, Dictionary] = CallDirector.call_history.duplicate(true)
	var call: CallData = CallData.new()
	call.id = &"archive_test"
	call.title = "Archive test"
	call.caller_name = "Morgan"
	call.phone_number = "555-0199"
	call.caller_location_name = "Harbor"
	var record: RecordEntry = RecordEntry.new()
	record.id = &"record_archive"
	record.title = "Incident report"
	call.records.append(record)
	CallDirector.active_call = call
	CallDirector.active_call_id = call.id
	CallDirector.registered_calls[call.id] = call
	CallDirector.call_history[&"prior_archive"] = {"verdict": &"solved"}
	CallDirector.case_evidence_by_call[call.id] = [&"evidence_archive_test"]
	var records: RecordsDatabase = RecordsDatabase.new()
	add_child_autofree(records)
	records.open()
	assert_gt(records._results.get_child_count(), 0)
	records._select_record(call.id, record)
	assert_eq(records._selected_record, record)
	var board: CaseBoard = CaseBoard.new()
	add_child_autofree(board)
	board.open()
	assert_gt(board._history.get_child_count(), 0)
	assert_gt(board._evidence.get_child_count(), 0)
	CallDirector.apply_snapshot(saved_state)
	CallDirector.registered_calls = saved_calls
	CallDirector.call_history = saved_history
