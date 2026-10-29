## Every call exposes one recorded route and keeps the alternatives unexplored.
extends GutTest

@warning_ignore_start("unsafe_call_argument", "unsafe_method_access")


func before_each() -> void:
	GameState.reset()
	MissionDirector.reset()
	MissionDirector.scene_changes_enabled = false
	CallDirector.call_history.clear()
	CallDirector.call_queue.clear()


func after_each() -> void:
	MissionDirector.scene_changes_enabled = true
	MissionDirector.reset()
	GameState.reset()
	CallDirector.call_history.clear()


func test_branch_snapshot_keeps_chosen_verdict_and_mission_result() -> void:
	CallDirector.call_history[&"call_barn_fire"] = {
		"state": "completed", "minute": 20, "verdict": &"genuine", "truth": CallData.Truth.GENUINE}
	CallDirector.call_history[&"call_missed_test"] = {"state": "missed", "minute": 90, "verdict": &"missed"}
	MissionDirector._mission_outcomes[&"call_barn_fire"] = {"state": "resolved", "detail": "Hostage rescued"}
	var report: Dictionary = MissionDirector.build_shift_report()
	var branches: Array = report["branches"]
	assert_eq(branches.size(), 2)
	assert_eq(branches[0]["verdict"], "genuine")
	assert_eq(branches[0]["actual"], "genuine")
	assert_eq(branches[0]["outcome"], "Hostage rescued")
	assert_eq(branches[1]["verdict"], "")
	assert_eq(branches[1]["actual"], "")
	assert_eq(branches[1]["outcome_state"], "missed")


func test_flowchart_switches_between_taken_and_missed_routes() -> void:
	var scene: PackedScene = load("res://scenes/aftermath/shift_flowchart.tscn") as PackedScene
	var view: ShiftFlowchart = scene.instantiate() as ShiftFlowchart
	view.report_data = {
		"shift": 2,
		"branches": [
			{"title": "Barn fire", "minute": 20, "verdict": "genuine", "actual": "genuine", "outcome": "Hostage rescued"},
			{"title": "Missed call", "minute": 90, "verdict": "", "actual": "", "outcome": "The line was not answered"},
		]
	}
	add_child_autofree(view)
	await get_tree().process_frame
	assert_eq(view._entries.size(), 2)
	assert_eq(view._graph.branch["verdict"], "genuine")
	assert_eq(view._graph.get_child_count(), 7)
	view._select_call(1)
	assert_eq(view._graph.branch["verdict"], "")
	assert_eq(view._selected_index, 1)


func test_report_opens_local_flowchart_and_can_close_it() -> void:
	MissionDirector.last_shift_report = {"shift": 2, "branches": [], "events": [], "meters": {}, "deltas": {}}
	GameState.phase = GameState.Phase.AFTERMATH
	var report: ShiftReport = (load("res://scenes/aftermath/shift_report.tscn") as PackedScene).instantiate() as ShiftReport
	add_child_autofree(report)
	report._flowchart_button.pressed.emit()
	var view: ShiftFlowchart = report.get_node_or_null(^"ShiftFlowchart") as ShiftFlowchart
	assert_not_null(view)
	assert_eq(view.report_data["shift"], 2)
	view.closed.emit()
	assert_true(view.is_queued_for_deletion())
