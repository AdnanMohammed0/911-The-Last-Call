## Shift evidence board: pins persist across calls; Medic can link one previous case to the live call.
class_name CaseBoard
extends Control

const READABILITY := preload("res://ui/kit/ui_readability.gd")
const AMBER: Color = Color(1.0, 0.74, 0.32)
const CYAN: Color = Color(0.41, 0.84, 0.95)
const DIM: Color = Color(0.60, 0.68, 0.72)

signal closed()
signal pattern_link_requested(prior_call_id: StringName)

var _current: Label
var _history: VBoxContainer
var _evidence: VBoxContainer
var _status: Label
var _link_button: Button
var _selected_prior: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	READABILITY.enlarge_text(self)
	EventBus.evidence_unlocked.connect(_on_evidence_unlocked)
	CallDirector.pattern_link_result.connect(_on_pattern_link_result)


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _build() -> void:
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.012, 0.016, 0.022, 0.98)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var frame: PanelContainer = UiKit.glass(Color(0.052, 0.061, 0.066), 13, 0, 0, 0.96, 3.0, Color(AMBER, 0.23))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 30
	frame.offset_top = 26
	frame.offset_right = -30
	frame.offset_bottom = -26
	add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(UiKit.margin(column, 22, 18, 22, 18))
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	header.add_child(titles)
	titles.add_child(UiKit.caps("INVESTIGATIONS / STATION 4", 11, AMBER, &"bold", 2))
	titles.add_child(UiKit.label("Case Board", 27, Color.WHITE, &"bold"))
	header.add_child(UiKit.expand(Control.new()))
	header.add_child(KitButton.make("Back to CAD", &"close", KitButton.Variant.SUBTLE, close))
	var cases: HBoxContainer = HBoxContainer.new()
	cases.add_theme_constant_override("separation", 14)
	cases.custom_minimum_size = Vector2(0, 205)
	column.add_child(cases)
	var live_card: PanelContainer = _card()
	live_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cases.add_child(live_card)
	var live_box: VBoxContainer = VBoxContainer.new()
	live_box.add_theme_constant_override("separation", 12)
	live_card.add_child(live_box)
	live_box.add_child(UiKit.caps("CURRENT CALL", 11, CYAN, &"bold", 2))
	_current = UiKit.label("", 18, Color(0.92, 0.95, 0.95), &"medium")
	_current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_box.add_child(_current)
	var prior_card: PanelContainer = _card()
	prior_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cases.add_child(prior_card)
	var prior_box: VBoxContainer = VBoxContainer.new()
	prior_box.add_theme_constant_override("separation", 8)
	prior_card.add_child(prior_box)
	prior_box.add_child(UiKit.caps("PRIOR CASES · SELECT ONE", 11, AMBER, &"bold", 2))
	var prior_scroll: ScrollContainer = ScrollContainer.new()
	prior_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prior_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	prior_box.add_child(prior_scroll)
	_history = VBoxContainer.new()
	_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history.add_theme_constant_override("separation", 6)
	prior_scroll.add_child(_history)
	var evidence_card: PanelContainer = _card()
	evidence_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(evidence_card)
	var evidence_box: VBoxContainer = VBoxContainer.new()
	evidence_box.add_theme_constant_override("separation", 10)
	evidence_card.add_child(evidence_box)
	evidence_box.add_child(UiKit.caps("EVIDENCE PINS / SHIFT ARCHIVE", 11, CYAN, &"bold", 2))
	var evidence_scroll: ScrollContainer = ScrollContainer.new()
	evidence_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	evidence_box.add_child(evidence_scroll)
	_evidence = VBoxContainer.new()
	_evidence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_evidence.add_theme_constant_override("separation", 9)
	evidence_scroll.add_child(_evidence)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_status = UiKit.label("", 13, DIM, &"medium")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(_status)
	_link_button = KitButton.make("Pattern Link", &"link", KitButton.Variant.PRIMARY, _request_link)
	actions.add_child(_link_button)


func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.style(Color(0.07, 0.084, 0.092), 10, 16, 14, Color(AMBER, 0.15), 1))
	return card


func _refresh() -> void:
	if _current == null:
		return
	var call: CallData = CallDirector.active_call
	_current.text = "%s\n%s\n%s" % [call.title, call.phone_number, call.caller_location_name] if call != null else "No active call. Review the shift archive below."
	for child: Node in _history.get_children():
		_history.remove_child(child)
		child.queue_free()
	if CallDirector.call_history.is_empty():
		_history.add_child(UiKit.label("No prior cases this shift.", 14, DIM, &"medium"))
	else:
		for call_id: StringName in CallDirector.call_history:
			var history: Dictionary = CallDirector.call_history[call_id]
			var prior: CallData = CallDirector.registered_calls.get(call_id, null)
			var title: String = prior.title if prior != null else String(call_id).replace("_", " ").capitalize()
			var button: KitButton = KitButton.make("%s  ·  %s" % [title, str(history.get("verdict", "—")).to_upper()], &"file", KitButton.Variant.SUBTLE, _select_prior.bind(call_id))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_history.add_child(button)
	for child: Node in _evidence.get_children():
		_evidence.remove_child(child)
		child.queue_free()
	var pin_count: int = 0
	for call_id: StringName in CallDirector.case_evidence_by_call:
		for key: Variant in CallDirector.case_evidence_by_call[call_id]:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(IconView.make(&"pin", 18, AMBER))
			row.add_child(UiKit.label("%s  /  %s" % [String(call_id).replace("call_", "").replace("_", " ").to_upper(), str(key).replace("evidence_", "").replace("_", " ").capitalize()], 15, Color(0.90, 0.95, 0.95), &"medium"))
			_evidence.add_child(row)
			pin_count += 1
	if pin_count == 0:
		_evidence.add_child(UiKit.label("No evidence pinned yet. VSA, CCTV and Deep Lookup results appear here.", 15, DIM, &"medium"))
	READABILITY.enlarge_text(_history)
	READABILITY.enlarge_text(_evidence)
	_update_status()


func _select_prior(call_id: StringName) -> void:
	_selected_prior = call_id
	_update_status()


func _update_status() -> void:
	var connected: bool = CallDirector.current_state == CallDirector.CallState.CONNECTED and CallDirector.active_call != null
	var my_class: StringName = NetManager.get_class_id(multiplayer.get_unique_id())
	var role_ok: bool = my_class == &"medic" or (not NetManager.is_online() and NetManager.roster.is_empty())
	var used: bool = CallDirector.pattern_link_used_call_id == CallDirector.active_call_id and CallDirector.active_call_id != &""
	_link_button.disabled = not connected or not role_ok or used or _selected_prior == &"" or _selected_prior == CallDirector.active_call_id
	if used:
		_status.text = "Pattern Link used for this call."
	elif not connected:
		_status.text = "Answer a call to connect it to a prior case."
	elif not role_ok:
		_status.text = "Investigator / Medic access required for Pattern Link."
	elif _selected_prior == &"":
		_status.text = "Select a prior case to find a pattern. One link per call."
	else:
		_status.text = "Link the selected prior case to the current call?"


func _request_link() -> void:
	if _selected_prior != &"":
		pattern_link_requested.emit(_selected_prior)


func _on_evidence_unlocked(_evidence_key: StringName) -> void:
	if visible:
		_refresh()


func _on_pattern_link_result(_result: Dictionary) -> void:
	if visible:
		_refresh()
