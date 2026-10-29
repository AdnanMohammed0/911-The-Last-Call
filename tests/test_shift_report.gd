## The report freezes an entire shift before history is reset for the next one.
extends GutTest

@warning_ignore_start("unsafe_call_argument", "unsafe_method_access")


func before_each() -> void:
	GameState.reset()
	MissionDirector.reset()
	MissionDirector.scene_changes_enabled = false
	CallDirector.call_history.clear()
	CallDirector.call_queue.clear()
	CallDirector.pause_shift()
	CallDirector.set_shift_time(0)


func after_each() -> void:
	MissionDirector.scene_changes_enabled = true
	MissionDirector.reset()
	GameState.reset()
	CallDirector.call_history.clear()


func test_report_collects_timeline_meter_deltas_traits_and_leads() -> void:
	MissionDirector.calls_handled = 2
	MissionDirector.calls_total = 2
	MissionDirector.public_trust = 81
	GameState.station_budget += 1200
	GameState.cult_awareness = 11
	CallDirector.call_history[&"call_test"] = {"state": "completed", "minute": 42, "verdict": &"genuine"}
	CallDirector.call_history[&"call_missed_test"] = {"state": "missed", "minute": 88, "verdict": &"missed"}
	MissionDirector._record_report_event("FIELD RESPONSE", "Suspect arrested", 54)
	MissionDirector._on_report_evidence_unlocked(&"evidence_hidden_camera")
	MissionDirector._on_report_trait_applied(1, &"limping")
	var report: Dictionary = MissionDirector.build_shift_report()
	assert_eq(report["shift"], 1)
	assert_eq(report["handled"], 2)
	assert_eq(report["deltas"]["trust"], 6)
	assert_eq(report["deltas"]["budget"], 1200)
	assert_eq(report["deltas"]["awareness"], 11)
	assert_eq(report["events"].size(), 5)
	assert_eq(report["events"][2]["minute"], 42)
	assert_eq(report["events"][3]["minute"], 54)
	assert_eq(report["events"][4]["minute"], 88)
	assert_true(report["leads"].has("Hidden Camera"))
	assert_eq(report["traits"].size(), 1)


func test_report_pauses_shift_until_host_continues() -> void:
	CallDirector.call_history[&"call_test"] = {"state": "completed", "minute": 12, "verdict": &"genuine"}
	MissionDirector.complete_shift()
	assert_eq(GameState.phase, GameState.Phase.AFTERMATH)
	assert_eq(MissionDirector.shift_number, 2)
	assert_eq(MissionDirector.last_shift_report["shift"], 1)
	assert_true(CallDirector.call_history.has(&"call_test"))
	MissionDirector.continue_after_report()
	assert_eq(GameState.phase, GameState.Phase.DISPATCH)
	assert_true(CallDirector.call_history.is_empty())
	assert_eq(CallDirector.shift_clock_minutes, 0)


func test_scene_displays_frozen_report_and_continue_button() -> void:
	MissionDirector.last_shift_report = {
		"shift": 3, "handled": 2, "total": 2,
		"events": [{"minute": 45, "title": "Warehouse raid", "detail": "Suspect arrested"}],
		"meters": {"trust": 82, "budget": 12345, "awareness": 7},
		"deltas": {"trust": 4, "budget": 300, "awareness": 2},
		"traits": ["Limping — Officer 1"], "leads": ["Station Ambush Intel"]
	}
	GameState.phase = GameState.Phase.AFTERMATH
	var report_scene: ShiftReport = (load("res://scenes/aftermath/shift_report.tscn") as PackedScene).instantiate() as ShiftReport
	add_child_autofree(report_scene)
	assert_not_null(report_scene._continue_button)
	assert_false(report_scene._continue_button.disabled)
	var text: String = ""
	for node: Node in report_scene.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	assert_string_contains(text, "SHIFT 03 COMPLETE")
	assert_string_contains(text, "Warehouse raid")
	assert_string_contains(text, "Station Ambush Intel")
