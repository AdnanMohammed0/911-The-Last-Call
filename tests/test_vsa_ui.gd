extends GutTest

@warning_ignore_start("unsafe_cast")
@warning_ignore_start("unsafe_call_argument")

const DirectorScript := preload("res://autoload/call_director.gd")

var _saved_roster: Dictionary[int, Dictionary]
var _saved_call: CallData
var _saved_state: int
var _saved_profile: StressProfile
var _saved_duration: float


func before_each() -> void:
	_saved_roster = NetManager.roster.duplicate(true)
	_saved_call = CallDirector.active_call
	_saved_state = CallDirector.current_state
	_saved_profile = CallDirector.vsa.active_profile
	_saved_duration = CallDirector.vsa.total_call_duration
	NetManager.roster[1] = {"name": "Profiler", "class_id": &"profiler"}


func after_each() -> void:
	NetManager.roster = _saved_roster
	CallDirector.active_call = _saved_call
	CallDirector.current_state = _saved_state
	CallDirector.vsa.active_profile = _saved_profile
	CallDirector.vsa.total_call_duration = _saved_duration


func _profile() -> StressProfile:
	var profile: StressProfile = StressProfile.new()
	var tremor: Curve = Curve.new()
	tremor.add_point(Vector2(0.0, 0.1))
	tremor.add_point(Vector2(1.0, 0.9))
	profile.tremor_curve = tremor
	profile.loop_segments = [Vector2(10.0, 15.0)]
	profile.background_tags = [&"adult_breathing"]
	return profile


func test_scrub_window_selects_time_and_requests_tag() -> void:
	var vsa: VoiceStressAnalyzer = VoiceStressAnalyzer.new()
	vsa.set_profile(_profile(), 100.0)
	var panel: VsaMiniGame = VsaMiniGame.new()
	add_child_autofree(panel)
	panel.open(vsa)
	await get_tree().process_frame
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(panel._waveform.size.x * 0.12, 80.0)
	panel._wave_input(click)
	assert_almost_eq(panel._selected_time, 12.0, 0.2)
	var requested: Array[Variant] = []
	panel.tag_requested.connect(func(time_seconds: float, tag_type: StringName) -> void:
		requested.append(time_seconds)
		requested.append(tag_type))
	panel._request_tag()
	assert_eq(requested.size(), 2)
	assert_almost_eq(requested[0] as float, 12.0, 0.2)
	assert_eq(requested[1], &"loop")
	panel.close()
	assert_false(panel.visible)


func test_profiler_opens_vsa_from_cad() -> void:
	var call: CallData = CallData.new()
	call.stress_profile = _profile()
	CallDirector.active_call = call
	CallDirector.current_state = CallDirector.CallState.CONNECTED
	CallDirector.vsa.set_profile(call.stress_profile, 100.0)
	var terminal: DispatchTerminal = DispatchTerminal.new()
	add_child_autofree(terminal)
	terminal._refresh()
	assert_true(terminal._vsa_button.visible)
	terminal._open_vsa()
	assert_not_null(terminal._vsa_minigame)
	assert_true(terminal._vsa_minigame.visible)
	terminal._vsa_minigame.close()


func test_host_accepts_profiler_tag_once_and_rejects_other_role() -> void:
	var director: DirectorScript = DirectorScript.new()
	add_child_autofree(director)
	var call: CallData = CallData.new()
	call.stress_profile = _profile()
	director.active_call = call
	director.current_state = director.CallState.CONNECTED
	director.vsa.set_profile(call.stress_profile, 100.0)
	director.dialogue_runner.max_patience = 100.0
	director.dialogue_runner.patience_remaining = 50.0
	var results: Array[Dictionary] = []
	director.vsa_tag_result.connect(func(result: Dictionary) -> void: results.append(result))
	director.request_vsa_tag(12.0, &"loop")
	assert_true(director.dialogue_runner.revealed_evidence.has(&"evidence_loop_detected"))
	assert_eq(results.size(), 1)
	assert_true(results[0].get("success", false))
	assert_almost_eq(director.dialogue_runner.patience_remaining, 60.0, 0.1)
	director.request_vsa_tag(12.0, &"loop")
	assert_eq(results.size(), 2)
	assert_false(results[1].get("success", true))
	assert_almost_eq(director.dialogue_runner.patience_remaining, 60.0, 0.1)
	director.request_vsa_tag(50.0, &"loop")
	assert_eq(results.size(), 3)
	assert_false(results[2].get("success", true))
	assert_almost_eq(director.dialogue_runner.patience_remaining, 40.0, 0.1)
	NetManager.roster[1]["class_id"] = &"tech"
	director.request_vsa_tag(12.0, &"loop")
	assert_eq(results.size(), 3)
