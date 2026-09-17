@tool
class_name DialogueGraphNode
extends GraphNode

## Visual GraphNode component for DialogueGraphEditor (P2-03).
## Renders a DialogueNode with left input port, right choice output ports, and tactical styling.

@warning_ignore_start("unsafe_call_argument")
@warning_ignore_start("unsafe_cast")

signal node_changed()
signal inspect_requested(dialogue_node: DialogueNode)
signal add_choice_requested()
signal remove_choice_requested(choice_index: int)
signal delete_node_requested()

const COLOR_PORT_INPUT: Color = Color(0.06, 0.71, 0.83) # Cyan
const COLOR_PORT_NORMAL: Color = Color(0.16, 0.75, 0.44) # Emerald
const COLOR_PORT_CLASS: Color = Color(0.96, 0.62, 0.07) # Amber
const COLOR_PORT_EVIDENCE: Color = Color(0.23, 0.51, 0.96) # Blue
const COLOR_PORT_AUTONEXT: Color = Color(0.66, 0.33, 0.95) # Purple

var dialogue_node: DialogueNode = null
var is_initial_node: bool = false:
	set(val):
		is_initial_node = val
		_update_title_and_style()

# UI references
var _id_edit: LineEdit
var _speaker_option: OptionButton
var _line_edit: TextEdit
var _start_badge: Label
var _slots_container: VBoxContainer


func setup(d_node: DialogueNode, is_start: bool = false) -> void:
	dialogue_node = d_node
	is_initial_node = is_start
	name = String(d_node.id if d_node.id != &"" else &"node")
	position_offset = d_node.editor_position
	
	resizable = true
	custom_minimum_size = Vector2(280, 180)
	
	delete_request.connect(_on_close_request)
	dragged.connect(_on_dragged)
	node_selected.connect(_on_node_selected)
	
	rebuild_ui()


func _on_close_request() -> void:
	delete_node_requested.emit()


func _on_dragged(_from: Vector2, to: Vector2) -> void:
	if dialogue_node != null:
		dialogue_node.editor_position = to
		node_changed.emit()


func _on_node_selected() -> void:
	if dialogue_node != null:
		inspect_requested.emit(dialogue_node)


func _update_title_and_style() -> void:
	if dialogue_node == null:
		title = "Node"
		return
	
	var node_id: String = String(dialogue_node.id)
	if is_initial_node:
		title = "★ [START] " + node_id
	else:
		title = "● " + node_id


func rebuild_ui() -> void:
	# Clear existing children and slots
	clear_all_slots()
	for c in get_children():
		c.queue_free()
	
	if dialogue_node == null:
		return
	
	_update_title_and_style()
	
	# ==========================================================================
	# Slot 0: Header & Spoken Line (Input Port on Left)
	# ==========================================================================
	var slot0: VBoxContainer = VBoxContainer.new()
	slot0.name = "Slot0_Header"
	slot0.custom_minimum_size = Vector2(260, 90)
	add_child(slot0)
	
	# Enable Left Port for incoming dialogue jumps
	set_slot(0, true, 0, COLOR_PORT_INPUT, false, 0, Color.WHITE)
	
	# Row 1: ID edit and Speaker selector
	var header_row: HBoxContainer = HBoxContainer.new()
	slot0.add_child(header_row)
	
	var id_lbl: Label = Label.new()
	id_lbl.text = "ID:"
	id_lbl.modulate = Color(0.6, 0.7, 0.8)
	header_row.add_child(id_lbl)
	
	_id_edit = LineEdit.new()
	_id_edit.text = String(dialogue_node.id)
	_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_edit.text_changed.connect(_on_id_changed)
	header_row.add_child(_id_edit)
	
	_speaker_option = OptionButton.new()
	_speaker_option.add_item("caller", 0)
	_speaker_option.add_item("dispatcher", 1)
	_speaker_option.add_item("officer_dispatch", 2)
	_speaker_option.add_item("unknown", 3)
	_select_speaker(String(dialogue_node.speaker))
	_speaker_option.item_selected.connect(_on_speaker_selected)
	header_row.add_child(_speaker_option)
	
	# Row 2: Spoken line preview / quick edit
	_line_edit = TextEdit.new()
	_line_edit.text = dialogue_node.line
	_line_edit.custom_minimum_size = Vector2(250, 48)
	_line_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_line_edit.text_changed.connect(_on_line_changed)
	slot0.add_child(_line_edit)
	
	# ==========================================================================
	# Slots 1..N: Choices (Right Output Ports)
	# ==========================================================================
	var slot_index: int = 1
	for i in range(dialogue_node.choices.size()):
		var choice: DialogueChoice = dialogue_node.choices[i]
		if choice == null:
			continue
		
		var choice_row: HBoxContainer = HBoxContainer.new()
		choice_row.name = "ChoiceSlot_%d" % i
		choice_row.custom_minimum_size = Vector2(260, 28)
		add_child(choice_row)
		
		# Determine output port color based on requirement
		var port_color: Color = COLOR_PORT_NORMAL
		if choice.required_class != &"":
			port_color = COLOR_PORT_CLASS
		elif not choice.required_evidence.is_empty():
			port_color = COLOR_PORT_EVIDENCE
		
		# Slot for choice: Right port enabled
		set_slot(slot_index, false, 0, Color.WHITE, true, 0, port_color)
		
		# Choice summary text
		var choice_txt_edit: LineEdit = LineEdit.new()
		choice_txt_edit.text = choice.text if choice.text != "" else "(Empty Choice)"
		choice_txt_edit.placeholder_text = "Choice text..."
		choice_txt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c_idx: int = i
		choice_txt_edit.text_changed.connect(func(new_t: String) -> void:
			choice.text = new_t
			node_changed.emit()
		)
		choice_row.add_child(choice_txt_edit)
		
		# Requirement Badge
		if choice.required_class != &"":
			var class_badge: Label = Label.new()
			class_badge.text = "[%s]" % String(choice.required_class).to_upper()
			class_badge.modulate = COLOR_PORT_CLASS
			choice_row.add_child(class_badge)
		
		if not choice.required_evidence.is_empty():
			var ev_badge: Label = Label.new()
			ev_badge.text = "[EV]"
			ev_badge.modulate = COLOR_PORT_EVIDENCE
			choice_row.add_child(ev_badge)
		
		if choice.patience_delta != 0.0:
			var pat_badge: Label = Label.new()
			pat_badge.text = ("%+ds" % int(choice.patience_delta))
			pat_badge.modulate = Color(0.2, 0.9, 0.3) if choice.patience_delta > 0.0 else Color(0.9, 0.3, 0.2)
			choice_row.add_child(pat_badge)
		
		# Next target preview
		var target_lbl: Label = Label.new()
		target_lbl.text = "➔ " + (String(choice.next) if choice.next != &"" else "?")
		target_lbl.modulate = Color(0.7, 0.7, 0.7)
		choice_row.add_child(target_lbl)
		
		# Delete choice button
		var del_btn: Button = Button.new()
		del_btn.text = "×"
		del_btn.flat = true
		del_btn.pressed.connect(func() -> void:
			remove_choice_requested.emit(c_idx)
		)
		choice_row.add_child(del_btn)
		
		slot_index += 1
	
	# ==========================================================================
	# Auto-Next Slot (if no choices exist)
	# ==========================================================================
	if dialogue_node.choices.is_empty():
		var auto_row: HBoxContainer = HBoxContainer.new()
		auto_row.name = "AutoNextSlot"
		auto_row.custom_minimum_size = Vector2(260, 24)
		add_child(auto_row)
		
		set_slot(slot_index, false, 0, Color.WHITE, true, 0, COLOR_PORT_AUTONEXT)
		
		var auto_lbl: Label = Label.new()
		auto_lbl.text = "Auto-Next ➔ " + (String(dialogue_node.auto_next) if dialogue_node.auto_next != &"" else "(connect to target)")
		auto_lbl.modulate = COLOR_PORT_AUTONEXT
		auto_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		auto_row.add_child(auto_lbl)
		
		var delay_spin: SpinBox = SpinBox.new()
		delay_spin.min_value = 0.0
		delay_spin.max_value = 30.0
		delay_spin.step = 0.5
		delay_spin.value = dialogue_node.auto_delay
		delay_spin.suffix = "s"
		delay_spin.value_changed.connect(func(v: float) -> void:
			dialogue_node.auto_delay = v
			node_changed.emit()
		)
		auto_row.add_child(delay_spin)
		
		slot_index += 1
	
	# ==========================================================================
	# Footer Slot: "+ Add Choice" button
	# ==========================================================================
	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	footer.custom_minimum_size = Vector2(260, 26)
	add_child(footer)
	set_slot(slot_index, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	var add_choice_btn: Button = Button.new()
	add_choice_btn.text = "+ Add Choice"
	add_choice_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_choice_btn.pressed.connect(func() -> void:
		add_choice_requested.emit()
	)
	footer.add_child(add_choice_btn)


func _select_speaker(spk: String) -> void:
	match spk:
		"caller":
			_speaker_option.selected = 0
		"dispatcher":
			_speaker_option.selected = 1
		"officer_dispatch":
			_speaker_option.selected = 2
		"unknown":
			_speaker_option.selected = 3
		_:
			_speaker_option.selected = 0


func _on_id_changed(new_id: String) -> void:
	if dialogue_node != null:
		dialogue_node.id = StringName(new_id)
		name = new_id if new_id != "" else "node"
		_update_title_and_style()
		node_changed.emit()


func _on_speaker_selected(idx: int) -> void:
	if dialogue_node != null:
		var spk_name: StringName = StringName(_speaker_option.get_item_text(idx))
		dialogue_node.speaker = spk_name
		node_changed.emit()


func _on_line_changed() -> void:
	if dialogue_node != null:
		dialogue_node.line = _line_edit.text
		node_changed.emit()
