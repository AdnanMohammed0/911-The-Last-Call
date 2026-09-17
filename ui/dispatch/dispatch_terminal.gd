## Dispatch CAD terminal (the "computer" in the operations room): live view of the CallDirector for the
## local player: call status, caller ID, patience, transcript, reply choices (handset holder), police
## records, and the verdict / team vote after the call. Built in code so designers only drop it in a level.
## Opened by DispatchComputer / DispatchPhone interactables; Esc closes it.
## Authority: LOCAL (UI) — every action is a request the host validates in CallDirector / VoteManager.
class_name DispatchTerminal
extends Control

const GROUP: StringName = &"dispatch_terminal"
const MODAL_GROUP: StringName = &"modal_ui"
const GREEN: Color = Color(0.45, 1.0, 0.6)
const AMBER: Color = Color(1.0, 0.72, 0.25)
const RED: Color = Color(1.0, 0.35, 0.3)
const DIM: Color = Color(0.55, 0.62, 0.6)
const STATE_NAMES: Array[String] = ["IDLE", "RINGING", "CONNECTED", "ASSESSMENT", "COMPLETED", "MISSED"]

## Emitted when a player asks for a test call from this terminal (DispatchSetup forwards it to the host).
signal test_call_requested()

var _status: Label
var _clock: Label
var _caller: Label
var _handset: Label
var _patience: ProgressBar
var _transcript: RichTextLabel
var _choices: VBoxContainer
var _records: RichTextLabel
var _verdict_box: VBoxContainer
var _verdict_buttons: HBoxContainer
var _vote_label: Label
var _result: Label
var _answer_button: Button
var _hangup_button: Button
var _handset_button: Button
var _test_button: Button

var _call_id: StringName = &""
var _last_node_id: StringName = &""
var _choice_data: Array = []
var _closed_player_input: Player = null


func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	EventBus.call_ring.connect(_on_call_ring)
	EventBus.call_connected.connect(_on_call_connected)
	EventBus.call_missed.connect(_on_call_missed)
	EventBus.call_assessment_started.connect(_on_assessment_started)
	EventBus.call_classified.connect(_on_call_classified)
	EventBus.caller_patience_updated.connect(_on_patience)
	EventBus.dialogue_node_changed.connect(_on_dialogue_node)
	EventBus.handset_owner_changed.connect(func(_peer: int) -> void: _refresh())
	EventBus.evidence_unlocked.connect(func(key: StringName) -> void: _append("[color=#7fd4ff]EVIDENCE:[/color] %s" % key))
	VoteManager.vote_updated.connect(_on_vote_updated)
	VoteManager.vote_opened.connect(_on_vote_updated)
	_refresh()


# --- Open / close ---------------------------------------------------------------

static func find(tree: SceneTree) -> DispatchTerminal:
	return tree.get_first_node_in_group(GROUP) as DispatchTerminal


func open() -> void:
	if visible:
		return
	visible = true
	add_to_group(MODAL_GROUP)
	var player: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if player != null:
		player.set_input_enabled(false)
		_closed_player_input = player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	remove_from_group(MODAL_GROUP)
	if _closed_player_input != null and is_instance_valid(_closed_player_input):
		_closed_player_input.set_input_enabled(true)
	_closed_player_input = null
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		var minutes: int = CallDirector.shift_clock_minutes
		_clock.text = "SHIFT %02d:%02d" % [minutes / 60, minutes % 60]
		if CallDirector.current_state == CallDirector.CallState.RINGING:
			_status.text = "● INCOMING 911 CALL  (%ds)" % ceili(CallDirector.ring_timer)


# --- Actions (requests to the host) ---------------------------------------------------

func answer() -> void:
	_call_host(&"request_answer_call", [CallDirector.active_call_id])


func hang_up() -> void:
	_call_host(&"request_hangup_call", [])


func take_handset() -> void:
	if CallDirector.handset_owner_peer_id == multiplayer.get_unique_id():
		_call_host(&"request_release_handset", [])
	else:
		_call_host(&"request_take_handset", [])


func choose(index: int) -> void:
	_call_host(&"request_dialogue_choice", [index])


func classify(verdict: StringName) -> void:
	if _call_id == &"":
		return
	_call_host(&"request_classify_call", [_call_id, verdict])
	_vote_label.text = "Your verdict: %s" % String(verdict).to_upper()


func _call_host(method: StringName, args: Array) -> void:
	if multiplayer.is_server():
		CallDirector.callv(method, args)
	else:
		CallDirector.callv(&"rpc_id", [1, method] + args)


# --- EventBus handlers ----------------------------------------------------------------

func _on_call_ring(call_id: StringName, call_data: CallData) -> void:
	_call_id = call_id
	_transcript.clear()
	_result.text = ""
	_vote_label.text = ""
	_choice_data = []
	_last_node_id = &""
	_show_records(call_data)
	_append("[color=#ffb347]%s — incoming call from %s[/color]" % [_clock_text(), call_data.phone_number if call_data != null else "UNKNOWN"])
	_refresh()


func _on_call_connected(call_id: StringName, _call_data: CallData) -> void:
	_call_id = call_id
	_append("[color=#9fe0b0]— line connected —[/color]")
	_refresh()


func _on_call_missed(_call_id_missed: StringName) -> void:
	_append("[color=#ff6b5e]Call missed. Nobody answered in time.[/color]")
	_refresh()


func _on_assessment_started(_id: StringName) -> void:
	_append("[color=#ffb347]— caller disconnected. Classify the call. —[/color]")
	_choice_data = []
	_refresh()


func _on_call_classified(call_id: StringName, verdict: StringName) -> void:
	var call: CallData = CallDirector.registered_calls.get(call_id, null)
	var truth_name: String = "?"
	if call != null:
		var truth_key: String = CallData.Truth.keys()[call.truth]
		truth_name = truth_key
	var correct: bool = truth_name.to_lower() == String(verdict)
	_result.text = "VERDICT: %s   ·   TRUTH: %s   ·   %s" % [String(verdict).to_upper(), truth_name, "CORRECT" if correct else "WRONG CALL"]
	_result.add_theme_color_override("font_color", GREEN if correct else RED)
	_append("[color=#%s]Verdict %s — the call was %s.[/color]" % ["7dff9a" if correct else "ff6b5e", String(verdict).to_upper(), truth_name])
	_refresh()


func _on_patience(current: float, max_patience: float) -> void:
	_patience.max_value = max_patience
	_patience.value = current


func _on_dialogue_node(node_id: StringName, speaker: StringName, line: String, choices: Array) -> void:
	# CallDirector re-sends the current node when only the choices change: print each line once.
	var is_new_node: bool = node_id != _last_node_id
	_last_node_id = node_id
	if is_new_node and not line.is_empty():
		var colour: String = "e8e8e8" if speaker == &"caller" else "9ec9ff"
		_append("[color=#8a9]%s[/color] [color=#%s]%s[/color]" % [String(speaker).to_upper(), colour, line])
	_choice_data = choices
	_refresh()


func _on_vote_updated(vote: Dictionary) -> void:
	if vote.get("topic", &"") != VoteManager.VERDICT_TOPIC:
		return
	var vote_id: int = vote.get("id", 0)
	var tally: Dictionary = VoteManager.get_tally(vote_id)
	var parts: PackedStringArray = PackedStringArray()
	for option: Variant in tally:
		var count: int = tally[option]
		var option_name: String = str(option)
		if count > 0:
			parts.append("%s %d" % [option_name.to_upper(), count])
	_vote_label.text = "TEAM VOTE (%ds): %s" % [ceili(VoteManager.get_time_left(vote_id)), ", ".join(parts) if not parts.is_empty() else "waiting…"]


# --- View -----------------------------------------------------------------------------

func _refresh() -> void:
	if _status == null:
		return
	var state: int = CallDirector.current_state
	var me: int = multiplayer.get_unique_id()
	var call: CallData = CallDirector.active_call
	if call == null and _call_id != &"":
		call = CallDirector.registered_calls.get(_call_id, null)
	match state:
		CallDirector.CallState.IDLE, CallDirector.CallState.COMPLETED, CallDirector.CallState.MISSED:
			_status.text = "NO ACTIVE CALL"
			_status.add_theme_color_override("font_color", DIM)
		CallDirector.CallState.RINGING:
			_status.add_theme_color_override("font_color", RED)
		CallDirector.CallState.CONNECTED:
			_status.text = "● CALL IN PROGRESS"
			_status.add_theme_color_override("font_color", GREEN)
		CallDirector.CallState.ASSESSMENT:
			_status.text = "ASSESSMENT — CLASSIFY THE CALL"
			_status.add_theme_color_override("font_color", AMBER)
	if call != null and state != CallDirector.CallState.IDLE:
		_caller.text = "CALLER: %s\nNUMBER: %s\nREPORTED LOCATION: %s" % [call.caller_name, call.phone_number, call.caller_location_name if not call.caller_location_name.is_empty() else "unknown"]
	else:
		_caller.text = "CALLER: —\nNUMBER: —\nREPORTED LOCATION: —"
	var owner: int = CallDirector.handset_owner_peer_id
	_handset.text = "HANDSET: %s" % ("on the desk" if owner == 0 else ("YOU" if owner == me else NetManager.get_player_name(owner)))
	_answer_button.disabled = state != CallDirector.CallState.RINGING
	_hangup_button.disabled = state != CallDirector.CallState.CONNECTED or not CallDirector.has_handset(me)
	_handset_button.text = "Put handset down" if owner == me else "Take handset"
	_handset_button.disabled = state != CallDirector.CallState.CONNECTED
	_verdict_box.visible = state == CallDirector.CallState.ASSESSMENT or not _result.text.is_empty()
	for child: Node in _verdict_buttons.get_children():
		(child as Button).disabled = state != CallDirector.CallState.ASSESSMENT
	_test_button.disabled = state != CallDirector.CallState.IDLE and state != CallDirector.CallState.COMPLETED and state != CallDirector.CallState.MISSED
	_rebuild_choices(state == CallDirector.CallState.CONNECTED and CallDirector.has_handset(me))


func _rebuild_choices(can_choose: bool) -> void:
	for child: Node in _choices.get_children():
		child.queue_free()
	if _choice_data.is_empty():
		var hint: Label = Label.new()
		hint.text = "(no replies — listen)" if CallDirector.current_state == CallDirector.CallState.CONNECTED else ""
		hint.add_theme_color_override("font_color", DIM)
		_choices.add_child(hint)
		return
	var my_class: StringName = NetManager.get_class_id(multiplayer.get_unique_id())
	for entry: Variant in _choice_data:
		var data: Dictionary = entry
		var index: int = data.get("index", 0)
		var text: String = data.get("text", "")
		var required: StringName = data.get("required_class", &"")
		var unlocked: bool = data.get("unlocked", true)
		var class_ok: bool = required == &"" or my_class == &"" or required == my_class
		var button: Button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d. %s" % [index + 1, text]
		if not unlocked:
			button.text += "   [%s]" % data.get("lock_reason", "locked")
		elif not class_ok:
			button.text += "   [%s only]" % String(required).capitalize()
		button.disabled = not can_choose or not unlocked or not class_ok
		button.pressed.connect(choose.bind(index))
		_choices.add_child(button)
	if not can_choose:
		var who: Label = Label.new()
		who.text = "Only the handset holder can reply."
		who.add_theme_color_override("font_color", DIM)
		_choices.add_child(who)


func _show_records(call: CallData) -> void:
	_records.clear()
	if call == null or call.records.is_empty():
		_records.append_text("[color=#8a9]No records on file for this number.[/color]")
		return
	for record: RecordEntry in call.records:
		_records.append_text("[color=#ffb347]%s[/color]\n%s\n\n" % [record.title, record.content])


func _append(bbcode: String) -> void:
	_transcript.append_text(bbcode + "\n")


func _clock_text() -> String:
	var minutes: int = CallDirector.shift_clock_minutes
	return "%02d:%02d" % [minutes / 60, minutes % 60]


# --- Layout -----------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame: PanelContainer = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 120
	frame.offset_top = 70
	frame.offset_right = -120
	frame.offset_bottom = -70
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.05, 0.97)
	style.border_color = Color(0.2, 0.55, 0.4)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	frame.add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	var title: Label = _label("BLACKVALE COUNTY 911 · STATION 4 · DISPATCH CAD", 24, GREEN, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_clock = _label("SHIFT 00:00", 24, AMBER, false)
	header.add_child(_clock)
	var close_button: Button = Button.new()
	close_button.text = "  Close [Esc]  "
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_status = _label("NO ACTIVE CALL", 30, DIM, false)
	root.add_child(_status)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	root.add_child(columns)

	# Left: caller + controls
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	_caller = _label("", 18, Color(0.85, 0.9, 0.88))
	left.add_child(_caller)
	left.add_child(_label("CALLER PATIENCE", 14, DIM))
	_patience = ProgressBar.new()
	_patience.custom_minimum_size = Vector2(0, 18)
	_patience.show_percentage = false
	_patience.max_value = 1.0
	_patience.value = 0.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = AMBER
	_patience.add_theme_stylebox_override("fill", fill)
	left.add_child(_patience)
	_handset = _label("HANDSET: on the desk", 16, AMBER)
	left.add_child(_handset)
	_answer_button = _button("Answer call", answer)
	left.add_child(_answer_button)
	_handset_button = _button("Take handset", take_handset)
	left.add_child(_handset_button)
	_hangup_button = _button("Hang up", hang_up)
	left.add_child(_hangup_button)
	left.add_child(HSeparator.new())
	left.add_child(_label("RECORDS LOOKUP", 14, DIM))
	_records = RichTextLabel.new()
	_records.bbcode_enabled = true
	_records.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_records.custom_minimum_size = Vector2(0, 170)
	_records.add_theme_font_size_override("normal_font_size", 15)
	left.add_child(_records)
	_test_button = _button("Start test call", func() -> void: test_call_requested.emit())
	left.add_child(_test_button)

	# Centre: transcript + replies + verdict
	var centre: VBoxContainer = VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.add_theme_constant_override("separation", 10)
	columns.add_child(centre)
	centre.add_child(_label("CALL TRANSCRIPT", 14, DIM))
	_transcript = RichTextLabel.new()
	_transcript.bbcode_enabled = true
	_transcript.scroll_following = true
	_transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcript.add_theme_font_size_override("normal_font_size", 18)
	centre.add_child(_transcript)
	centre.add_child(_label("REPLIES", 14, DIM))
	_choices = VBoxContainer.new()
	centre.add_child(_choices)

	_verdict_box = VBoxContainer.new()
	centre.add_child(_verdict_box)
	_verdict_box.add_child(_label("CLASSIFY THIS CALL", 16, AMBER))
	_verdict_buttons = HBoxContainer.new()
	_verdict_box.add_child(_verdict_buttons)
	for verdict: StringName in CallData.VERDICTS:
		var verdict_button: Button = _button(String(verdict).to_upper(), classify.bind(verdict))
		verdict_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_verdict_buttons.add_child(verdict_button)
	_vote_label = _label("", 15, DIM)
	_verdict_box.add_child(_vote_label)
	_result = _label("", 20, GREEN)
	_verdict_box.add_child(_result)


func _label(text: String, size: int, colour: Color, wrap: bool = true) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	return button
