## Searchable dispatch archive for the active call and previous calls in this shift.
class_name RecordsDatabase
extends Control

const READABILITY := preload("res://ui/kit/ui_readability.gd")
const CYAN: Color = Color(0.42, 0.82, 0.95)
const DIM: Color = Color(0.58, 0.67, 0.72)

signal closed()
signal lookup_requested(record_id: StringName)

var _search: LineEdit
var _results: VBoxContainer
var _detail: RichTextLabel
var _status: Label
var _lookup_button: Button
var _selected_record: RecordEntry = null
var _selected_call_id: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	READABILITY.enlarge_text(self)
	CallDirector.records_lookup_updated.connect(_on_lookup_updated)


func open() -> void:
	visible = true
	_search.text = ""
	_rebuild_results("")
	_refresh_detail()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if not visible or CallDirector.records_lookup_id == &"":
		return
	if not multiplayer.is_server():
		CallDirector.records_lookup_time_left = maxf(0.0, CallDirector.records_lookup_time_left - delta)
	_update_status()


func _build() -> void:
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.006, 0.013, 0.02, 0.97)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var frame: PanelContainer = UiKit.glass(Color(0.026, 0.043, 0.057), 14, 0, 0, 0.94, 3.0, Color(CYAN, 0.22))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 32
	frame.offset_top = 28
	frame.offset_right = -32
	frame.offset_bottom = -28
	add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(UiKit.margin(column, 20, 16, 20, 16))
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var title: VBoxContainer = VBoxContainer.new()
	header.add_child(title)
	title.add_child(UiKit.caps("BLACKVALE COUNTY / ARCHIVE", 11, CYAN, &"bold", 2))
	title.add_child(UiKit.label("Records Database", 26, Color.WHITE, &"bold"))
	header.add_child(UiKit.expand(Control.new()))
	header.add_child(KitButton.make("Back to CAD", &"close", KitButton.Variant.SUBTLE, close))
	_search = LineEdit.new()
	_search.placeholder_text = "Search caller, phone, address or record title…"
	_search.custom_minimum_size = Vector2(0, 45)
	_search.text_changed.connect(_rebuild_results)
	column.add_child(_search)
	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	column.add_child(split)
	var list_panel: PanelContainer = _card()
	list_panel.custom_minimum_size = Vector2(370, 0)
	split.add_child(list_panel)
	var list_box: VBoxContainer = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 10)
	list_panel.add_child(list_box)
	list_box.add_child(UiKit.caps("MATCHING RECORDS", 11, DIM, &"bold", 2))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(scroll)
	_results = VBoxContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 8)
	scroll.add_child(_results)
	var detail_panel: PanelContainer = _card()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail_panel)
	var detail_box: VBoxContainer = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(detail_box)
	detail_box.add_child(UiKit.caps("FILE CONTENTS", 11, CYAN, &"bold", 2))
	_detail = UiKit.rich(16)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail)
	_status = UiKit.label("", 13, DIM, &"medium")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_status)
	_lookup_button = KitButton.make("Deep Lookup · 30s", &"search", KitButton.Variant.PRIMARY, _request_lookup)
	detail_box.add_child(_lookup_button)


func _card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.style(Color(0.04, 0.07, 0.09), 10, 16, 14, Color(CYAN, 0.13), 1))
	return card


func _rebuild_results(query: String) -> void:
	if _results == null:
		return
	for child: Node in _results.get_children():
		_results.remove_child(child)
		child.queue_free()
	var needle: String = query.strip_edges().to_lower()
	var call_ids: Array[StringName] = []
	if CallDirector.active_call != null:
		call_ids.append(CallDirector.active_call.id)
	for key: StringName in CallDirector.call_history:
		if not key in call_ids:
			call_ids.append(key)
	var matches: int = 0
	for call_id: StringName in call_ids:
		var call: CallData = CallDirector.registered_calls.get(call_id, null)
		if call == null and CallDirector.active_call != null and CallDirector.active_call.id == call_id:
			call = CallDirector.active_call
		if call == null:
			continue
		for record: RecordEntry in call.records:
			var haystack: String = "%s %s %s %s %s" % [call.caller_name, call.phone_number, call.caller_location_name, record.title, record.content]
			if not needle.is_empty() and not haystack.to_lower().contains(needle):
				continue
			var row: KitButton = KitButton.make("%s\n%s · %s" % [record.title, call.phone_number, call.caller_location_name], &"file", KitButton.Variant.SUBTLE, _select_record.bind(call_id, record))
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.custom_minimum_size = Vector2(0, 66)
			_results.add_child(row)
			matches += 1
	if matches == 0:
		_results.add_child(UiKit.label("No matching records in this shift.", 14, DIM, &"medium"))
	READABILITY.enlarge_text(_results)


func _select_record(call_id: StringName, record: RecordEntry) -> void:
	_selected_call_id = call_id
	_selected_record = record
	_refresh_detail()


func _refresh_detail() -> void:
	if _detail == null:
		return
	_detail.clear()
	if _selected_record == null:
		_detail.append_text("[color=#9aabb3]Select a record on the left.[/color]")
		_lookup_button.disabled = true
		_status.text = ""
		return
	_detail.append_text("[color=#6bd7f2][b]%s[/b][/color]\n\n%s" % [_selected_record.title, _selected_record.content])
	_update_status()


func _update_status() -> void:
	if _selected_record == null:
		return
	var current: bool = CallDirector.current_state == CallDirector.CallState.CONNECTED and CallDirector.active_call != null and _selected_call_id == CallDirector.active_call.id
	var my_class: StringName = NetManager.get_class_id(multiplayer.get_unique_id())
	var role_ok: bool = my_class == &"tech" or (not NetManager.is_online() and NetManager.roster.is_empty())
	var unlocked: bool = _selected_record.id in CallDirector.records_unlocked
	var busy: bool = CallDirector.records_lookup_id != &""
	_lookup_button.disabled = not current or not role_ok or unlocked or busy
	if unlocked:
		_status.text = "VERIFIED · Evidence added to the case."
	elif busy:
		_status.text = "Searching archive… %ds" % ceili(CallDirector.records_lookup_time_left)
	elif not current:
		_status.text = "Deep Lookup is available while this caller is connected."
	elif not role_ok:
		_status.text = "Tech Operator access required for Deep Lookup."
	else:
		_status.text = "Run a 30-second Deep Lookup to certify this record as evidence."


func _request_lookup() -> void:
	if _selected_record != null:
		lookup_requested.emit(_selected_record.id)


func _on_lookup_updated(_record_id: StringName, _seconds_left: float, _completed: bool) -> void:
	if visible:
		_refresh_detail()
