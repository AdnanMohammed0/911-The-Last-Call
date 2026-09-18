@tool
class_name DialogueGraphView
extends Control

## Main UI view for DialogueGraphEditor plugin (P2-03).
## Features GraphEdit canvas, toolbar, node creation/connection, side inspector, and .tres save/load.

@warning_ignore_start("unsafe_call_argument")
@warning_ignore_start("unsafe_cast")

signal graph_modified()

const DIALOGUE_GRAPH_NODE_SCRIPT := preload("res://addons/dialogue_editor/dialogue_graph_node.gd")

var dialogue_graph: DialogueGraph = null
var current_file_path: String = ""
var is_dirty: bool = false

# Internal mapping from DialogueNode.id to visual GraphNode
var _nodes_map: Dictionary = {}
var _selected_node: DialogueNode = null

# UI controls
var _graph_edit: GraphEdit
var _status_label: Label
var _file_dialog: FileDialog
var _dialog_mode: int = 0 # 0 = Open, 1 = SaveAs
var _validation_dialog: AcceptDialog

# Inspector UI controls
var _inspector_panel: PanelContainer
var _ins_node_id: LineEdit
var _ins_speaker: OptionButton
var _ins_line: TextEdit
var _ins_audio_path: LineEdit
var _ins_events: LineEdit
var _ins_auto_next: LineEdit
var _ins_auto_delay: SpinBox
var _ins_choices_container: VBoxContainer


func _ready() -> void:
	_setup_ui()
	if dialogue_graph == null:
		if FileAccess.file_exists("res://data/dialogue/sample_call_dialogue.tres"):
			load_from_file("res://data/dialogue/sample_call_dialogue.tres")
		else:
			new_graph()


func _setup_ui() -> void:
	# Main layout: Toolbar on top, Split container (GraphEdit + Inspector) below
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)
	
	# ==========================================================================
	# 1. Toolbar
	# ==========================================================================
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 36)
	main_vbox.add_child(toolbar)
	
	var new_btn: Button = Button.new()
	new_btn.text = "📁 New"
	new_btn.tooltip_text = "Create a new blank dialogue tree"
	new_btn.pressed.connect(new_graph)
	toolbar.add_child(new_btn)
	
	var open_btn: Button = Button.new()
	open_btn.text = "📂 Open"
	open_btn.tooltip_text = "Open an existing .tres DialogueGraph"
	open_btn.pressed.connect(_on_open_pressed)
	toolbar.add_child(open_btn)
	
	var save_btn: Button = Button.new()
	save_btn.text = "💾 Save"
	save_btn.tooltip_text = "Save dialogue graph"
	save_btn.pressed.connect(save_graph)
	toolbar.add_child(save_btn)
	
	var save_as_btn: Button = Button.new()
	save_as_btn.text = "💾 Save As..."
	save_as_btn.tooltip_text = "Save dialogue graph to new path"
	save_as_btn.pressed.connect(_on_save_as_pressed)
	toolbar.add_child(save_as_btn)
	
	toolbar.add_child(VSeparator.new())
	
	var add_node_btn: Button = Button.new()
	add_node_btn.text = "➕ Add Node"
	add_node_btn.tooltip_text = "Add a new dialogue node"
	add_node_btn.pressed.connect(func() -> void: add_new_node())
	toolbar.add_child(add_node_btn)
	
	var set_start_btn: Button = Button.new()
	set_start_btn.text = "🚩 Set Start"
	set_start_btn.tooltip_text = "Set selected node as initial entry point"
	set_start_btn.pressed.connect(_on_set_selected_as_start)
	toolbar.add_child(set_start_btn)
	
	var layout_btn: Button = Button.new()
	layout_btn.text = "⚡ Auto-Layout"
	layout_btn.tooltip_text = "Auto-arrange graph nodes in tree columns"
	layout_btn.pressed.connect(auto_layout_nodes)
	toolbar.add_child(layout_btn)
	
	var validate_btn: Button = Button.new()
	validate_btn.text = "🔍 Validate"
	validate_btn.tooltip_text = "Check for broken links or missing start node"
	validate_btn.pressed.connect(_on_validate_pressed)
	toolbar.add_child(validate_btn)
	
	toolbar.add_child(VSeparator.new())
	
	_status_label = Label.new()
	_status_label.text = "Untitled.tres"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.modulate = Color(0.7, 0.8, 0.9)
	toolbar.add_child(_status_label)
	
	# ==========================================================================
	# 2. Main Work Area (Split: GraphEdit + Side Inspector)
	# ==========================================================================
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split)
	
	# GraphEdit
	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.snapping_enabled = true
	_graph_edit.snapping_distance = 20
	_graph_edit.right_disconnects = true
	
	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph_edit.node_deselected.connect(_on_node_deselected)
	split.add_child(_graph_edit)
	
	# Side Inspector Panel
	_setup_inspector_ui(split)
	
	# ==========================================================================
	# 3. Dialogs
	# ==========================================================================
	_file_dialog = FileDialog.new()
	_file_dialog.filters = ["*.tres, *.res ; Dialogue Graph Resources"]
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)
	
	_validation_dialog = AcceptDialog.new()
	_validation_dialog.title = "Dialogue Graph Validation"
	add_child(_validation_dialog)


func _setup_inspector_ui(parent: Control) -> void:
	_inspector_panel = PanelContainer.new()
	_inspector_panel.custom_minimum_size = Vector2(320, 0)
	parent.add_child(_inspector_panel)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector_panel.add_child(scroll)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	var title_lbl: Label = Label.new()
	title_lbl.text = "PROPERTIES INSPECTOR"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.96, 0.62, 0.07) # Amber
	vbox.add_child(title_lbl)
	vbox.add_child(HSeparator.new())
	
	# Node ID
	vbox.add_child(Label.new())
	var id_lbl: Label = vbox.get_child(vbox.get_child_count() - 1) as Label
	id_lbl.text = "Node ID:"
	_ins_node_id = LineEdit.new()
	_ins_node_id.text_changed.connect(_on_inspector_id_changed)
	vbox.add_child(_ins_node_id)
	
	# Speaker
	var spk_lbl: Label = Label.new()
	spk_lbl.text = "Speaker:"
	vbox.add_child(spk_lbl)
	_ins_speaker = OptionButton.new()
	_ins_speaker.add_item("caller", 0)
	_ins_speaker.add_item("dispatcher", 1)
	_ins_speaker.add_item("officer_dispatch", 2)
	_ins_speaker.add_item("unknown", 3)
	_ins_speaker.item_selected.connect(_on_inspector_speaker_selected)
	vbox.add_child(_ins_speaker)
	
	# Spoken Line Text
	var line_lbl: Label = Label.new()
	line_lbl.text = "Dialogue Line (Transcript):"
	vbox.add_child(line_lbl)
	_ins_line = TextEdit.new()
	_ins_line.custom_minimum_size = Vector2(0, 80)
	_ins_line.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_ins_line.text_changed.connect(_on_inspector_line_changed)
	vbox.add_child(_ins_line)
	
	# Audio Resource Path
	var audio_lbl: Label = Label.new()
	audio_lbl.text = "Audio Stream Path:"
	vbox.add_child(audio_lbl)
	_ins_audio_path = LineEdit.new()
	_ins_audio_path.placeholder_text = "res://audio/calls/..."
	_ins_audio_path.text_changed.connect(_on_inspector_audio_changed)
	vbox.add_child(_ins_audio_path)
	
	# On Enter Events
	var ev_lbl: Label = Label.new()
	ev_lbl.text = "On-Enter Events (comma-separated):"
	vbox.add_child(ev_lbl)
	_ins_events = LineEdit.new()
	_ins_events.placeholder_text = "event_calm, lead_farmhouse"
	_ins_events.text_changed.connect(_on_inspector_events_changed)
	vbox.add_child(_ins_events)
	
	# Auto Next & Delay
	var auto_lbl: Label = Label.new()
	auto_lbl.text = "Auto-Next Target & Delay:"
	vbox.add_child(auto_lbl)
	var auto_hbox: HBoxContainer = HBoxContainer.new()
	vbox.add_child(auto_hbox)
	
	_ins_auto_next = LineEdit.new()
	_ins_auto_next.placeholder_text = "target_node_id"
	_ins_auto_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_auto_next.text_changed.connect(_on_inspector_auto_next_changed)
	auto_hbox.add_child(_ins_auto_next)
	
	_ins_auto_delay = SpinBox.new()
	_ins_auto_delay.min_value = 0.0
	_ins_auto_delay.max_value = 60.0
	_ins_auto_delay.step = 0.5
	_ins_auto_delay.suffix = "s"
	_ins_auto_delay.value_changed.connect(_on_inspector_auto_delay_changed)
	auto_hbox.add_child(_ins_auto_delay)
	
	vbox.add_child(HSeparator.new())
	
	# Choices Editor
	var choices_header: HBoxContainer = HBoxContainer.new()
	vbox.add_child(choices_header)
	
	var ch_lbl: Label = Label.new()
	ch_lbl.text = "CHOICES BRANCHES:"
	ch_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_lbl.modulate = Color(0.06, 0.71, 0.83) # Cyan
	choices_header.add_child(ch_lbl)
	
	var add_ch_btn: Button = Button.new()
	add_ch_btn.text = "+ Add"
	add_ch_btn.pressed.connect(_on_inspector_add_choice)
	choices_header.add_child(add_ch_btn)
	
	_ins_choices_container = VBoxContainer.new()
	vbox.add_child(_ins_choices_container)
	
	# Delete Node button
	vbox.add_child(HSeparator.new())
	var del_node_btn: Button = Button.new()
	del_node_btn.text = "🗑️ Delete Node"
	del_node_btn.modulate = Color(0.95, 0.3, 0.3)
	del_node_btn.pressed.connect(_on_inspector_delete_node)
	vbox.add_child(del_node_btn)


# ==============================================================================
# Graph State & Loading
# ==============================================================================

func new_graph() -> void:
	dialogue_graph = DialogueGraph.new()
	dialogue_graph.initial_node_id = &"start"
	current_file_path = ""
	is_dirty = false
	
	var start_node: DialogueNode = DialogueNode.new()
	start_node.id = &"start"
	start_node.speaker = &"caller"
	start_node.line = "911, what is your emergency?"
	start_node.editor_position = Vector2(80, 120)
	dialogue_graph.add_node(start_node)
	
	load_graph(dialogue_graph, "")


func load_graph(graph: DialogueGraph, path: String = "") -> void:
	dialogue_graph = graph
	current_file_path = path
	is_dirty = false
	_update_title()
	
	_nodes_map.clear()
	_graph_edit.clear_connections()
	for child in _graph_edit.get_children():
		if child is GraphNode:
			_graph_edit.remove_child(child)
			child.queue_free()
	
	# Instantiate visual nodes
	for d_node in dialogue_graph.nodes:
		if d_node == null:
			continue
		_create_graph_node_widget(d_node)
	
	# Re-create connections
	_reconnect_all_ports()
	
	if not dialogue_graph.nodes.is_empty():
		inspect_node(dialogue_graph.nodes[0])


func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var res: Resource = ResourceLoader.load(path)
	if res is DialogueGraph:
		load_graph(res as DialogueGraph, path)
		return true
	return false


func save_graph() -> bool:
	if current_file_path == "":
		_on_save_as_pressed()
		return false
	return save_to_file(current_file_path)


func save_to_file(path: String) -> bool:
	if dialogue_graph == null:
		return false
	
	# Sync node positions before saving
	for d_node in dialogue_graph.nodes:
		if d_node != null and _nodes_map.has(d_node.id):
			d_node.editor_position = _nodes_map[d_node.id].position_offset
	
	var err: Error = ResourceSaver.save(dialogue_graph, path)
	if err == OK:
		current_file_path = path
		is_dirty = false
		_update_title()
		return true
	return false


func _update_title() -> void:
	var fname: String = current_file_path.get_file() if current_file_path != "" else "Untitled.tres"
	_status_label.text = fname + (" *" if is_dirty else "")


func _mark_dirty() -> void:
	is_dirty = true
	_update_title()
	graph_modified.emit()


# ==============================================================================
# Node & Port Creation
# ==============================================================================

func add_new_node(node_id: StringName = &"", pos: Vector2 = Vector2.ZERO) -> DialogueNode:
	if dialogue_graph == null:
		return null
	
	if node_id == &"":
		var idx: int = dialogue_graph.nodes.size() + 1
		node_id = StringName("node_%d" % idx)
		while dialogue_graph.has_node(node_id):
			idx += 1
			node_id = StringName("node_%d" % idx)
	
	if pos == Vector2.ZERO:
		pos = _graph_edit.scroll_offset + Vector2(250, 180)
	
	var d_node: DialogueNode = DialogueNode.new()
	d_node.id = node_id
	d_node.speaker = &"caller"
	d_node.line = ""
	d_node.editor_position = pos
	
	dialogue_graph.add_node(d_node)
	_create_graph_node_widget(d_node)
	inspect_node(d_node)
	_mark_dirty()
	return d_node


func _create_graph_node_widget(d_node: DialogueNode) -> GraphNode:
	var gn: GraphNode = DIALOGUE_GRAPH_NODE_SCRIPT.new() as GraphNode
	gn.call("setup", d_node, d_node.id == dialogue_graph.initial_node_id)
	
	gn.connect("node_changed", func() -> void:
		_mark_dirty()
		if _selected_node == d_node:
			inspect_node(d_node)
	)
	gn.connect("inspect_requested", inspect_node)
	gn.connect("delete_node_requested", func() -> void:
		delete_node(d_node.id)
	)
	gn.connect("add_choice_requested", func() -> void:
		add_choice_to_node(d_node)
	)
	gn.connect("remove_choice_requested", func(c_idx: int) -> void:
		remove_choice_from_node(d_node, c_idx)
	)
	
	_graph_edit.add_child(gn)
	_nodes_map[d_node.id] = gn
	return gn


func delete_node(node_id: StringName) -> void:
	if dialogue_graph == null:
		return
	
	var d_node: DialogueNode = dialogue_graph.get_node(node_id)
	if d_node == null:
		return
	
	# Disconnect all connections connected to this node
	var conn_list: Array[Dictionary] = _graph_edit.get_connection_list()
	var g_name: StringName = StringName(_nodes_map[node_id].name if _nodes_map.has(node_id) else "")
	for conn in conn_list:
		if conn.get("from_node", &"") == g_name or conn.get("to_node", &"") == g_name:
			_graph_edit.disconnect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
	
	if _nodes_map.has(node_id):
		var gn: GraphNode = _nodes_map[node_id] as GraphNode
		_nodes_map.erase(node_id)
		gn.queue_free()
	
	dialogue_graph.remove_node(node_id)
	
	if _selected_node == d_node:
		_selected_node = null
		_clear_inspector()
	
	_mark_dirty()


func add_choice_to_node(d_node: DialogueNode) -> DialogueChoice:
	var ch: DialogueChoice = DialogueChoice.new()
	ch.text = "Response option"
	d_node.choices.append(ch)
	
	if _nodes_map.has(d_node.id):
		_nodes_map[d_node.id].rebuild_ui()
		_reconnect_node_outputs(d_node)
	
	if _selected_node == d_node:
		inspect_node(d_node)
	
	_mark_dirty()
	return ch


func remove_choice_from_node(d_node: DialogueNode, c_idx: int) -> void:
	if c_idx < 0 or c_idx >= d_node.choices.size():
		return
	
	d_node.choices.remove_at(c_idx)
	if _nodes_map.has(d_node.id):
		_nodes_map[d_node.id].rebuild_ui()
		_reconnect_node_outputs(d_node)
	
	if _selected_node == d_node:
		inspect_node(d_node)
	
	_mark_dirty()


# ==============================================================================
# Port Connection Logic
# ==============================================================================

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_gn: GraphNode = _get_gn_by_element_name(from_node)
	var to_gn: GraphNode = _get_gn_by_element_name(to_node)
	if from_gn == null or to_gn == null:
		return
	
	var src_dnode: DialogueNode = from_gn.get("dialogue_node") as DialogueNode
	var tgt_dnode: DialogueNode = to_gn.get("dialogue_node") as DialogueNode
	if src_dnode == null or tgt_dnode == null:
		return
	
	# If choices exist, from_port is the choice index
	if not src_dnode.choices.is_empty():
		if from_port >= 0 and from_port < src_dnode.choices.size():
			src_dnode.choices[from_port].next = tgt_dnode.id
	else:
		# Auto-next
		src_dnode.auto_next = tgt_dnode.id
	
	_graph_edit.connect_node(from_node, from_port, to_node, to_port)
	from_gn.call("rebuild_ui")
	if _selected_node == src_dnode:
		inspect_node(src_dnode)
	_mark_dirty()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_gn: GraphNode = _get_gn_by_element_name(from_node)
	if from_gn != null and from_gn.get("dialogue_node") != null:
		var src_dnode: DialogueNode = from_gn.get("dialogue_node") as DialogueNode
		if not src_dnode.choices.is_empty():
			if from_port >= 0 and from_port < src_dnode.choices.size():
				src_dnode.choices[from_port].next = &""
		else:
			src_dnode.auto_next = &""
		from_gn.call("rebuild_ui")
		if _selected_node == src_dnode:
			inspect_node(src_dnode)
	
	_graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_mark_dirty()


func _reconnect_all_ports() -> void:
	_graph_edit.clear_connections()
	for d_node in dialogue_graph.nodes:
		if d_node != null:
			_reconnect_node_outputs(d_node)


func _reconnect_node_outputs(d_node: DialogueNode) -> void:
	if not _nodes_map.has(d_node.id):
		return
	var src_gn: GraphNode = _nodes_map[d_node.id] as GraphNode
	var from_elem_name: StringName = StringName(src_gn.name)
	
	# Connect choices
	for i in range(d_node.choices.size()):
		var ch: DialogueChoice = d_node.choices[i]
		if ch != null and ch.next != &"" and _nodes_map.has(ch.next):
			var tgt_gn: GraphNode = _nodes_map[ch.next] as GraphNode
			_graph_edit.connect_node(from_elem_name, i, StringName(tgt_gn.name), 0)
	
	# Connect auto_next if choices is empty
	if d_node.choices.is_empty() and d_node.auto_next != &"" and _nodes_map.has(d_node.auto_next):
		var tgt_gn: GraphNode = _nodes_map[d_node.auto_next] as GraphNode
		_graph_edit.connect_node(from_elem_name, 0, StringName(tgt_gn.name), 0)


func _get_gn_by_element_name(elem_name: StringName) -> GraphNode:
	for gn in _nodes_map.values():
		if gn != null and gn.name == elem_name:
			return gn as GraphNode
	return null


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	for n_name in node_names:
		var gn: GraphNode = _get_gn_by_element_name(n_name)
		if gn != null and gn.get("dialogue_node") != null:
			var d_node: DialogueNode = gn.get("dialogue_node") as DialogueNode
			delete_node(d_node.id)


func _on_node_deselected(_node: Node) -> void:
	# Keep inspector active on last selected node for smooth usability
	pass


# ==============================================================================
# Side Inspector Integration
# ==============================================================================

func inspect_node(d_node: DialogueNode) -> void:
	_selected_node = d_node
	if d_node == null:
		_clear_inspector()
		return
	
	_ins_node_id.text = String(d_node.id)
	
	match String(d_node.speaker):
		"caller": _ins_speaker.selected = 0
		"dispatcher": _ins_speaker.selected = 1
		"officer_dispatch": _ins_speaker.selected = 2
		"unknown": _ins_speaker.selected = 3
		_: _ins_speaker.selected = 0
	
	_ins_line.text = d_node.line
	_ins_audio_path.text = d_node.audio.resource_path if d_node.audio != null else ""
	_ins_events.text = ", ".join(d_node.on_enter_events.map(func(s: StringName) -> String: return String(s)))
	_ins_auto_next.text = String(d_node.auto_next)
	_ins_auto_delay.value = d_node.auto_delay
	
	_rebuild_inspector_choices(d_node)


func _clear_inspector() -> void:
	_ins_node_id.text = ""
	_ins_line.text = ""
	_ins_audio_path.text = ""
	_ins_events.text = ""
	_ins_auto_next.text = ""
	_ins_auto_delay.value = 0.0
	for c in _ins_choices_container.get_children():
		c.queue_free()


func _rebuild_inspector_choices(d_node: DialogueNode) -> void:
	for c in _ins_choices_container.get_children():
		c.queue_free()
	
	for i in range(d_node.choices.size()):
		var ch: DialogueChoice = d_node.choices[i]
		if ch == null:
			continue
		
		var panel: PanelContainer = PanelContainer.new()
		var card: VBoxContainer = VBoxContainer.new()
		panel.add_child(card)
		_ins_choices_container.add_child(panel)
		
		var header: HBoxContainer = HBoxContainer.new()
		card.add_child(header)
		
		var num_lbl: Label = Label.new()
		num_lbl.text = "Choice #%d" % (i + 1)
		num_lbl.modulate = Color(0.16, 0.75, 0.44) # Green
		num_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(num_lbl)
		
		var del_btn: Button = Button.new()
		del_btn.text = "×"
		del_btn.flat = true
		var c_idx: int = i
		del_btn.pressed.connect(func() -> void:
			remove_choice_from_node(d_node, c_idx)
		)
		header.add_child(del_btn)
		
		# Choice Text
		var txt_edit: LineEdit = LineEdit.new()
		txt_edit.text = ch.text
		txt_edit.placeholder_text = "Response option text..."
		txt_edit.text_changed.connect(func(new_t: String) -> void:
			ch.text = new_t
			if _nodes_map.has(d_node.id):
				_nodes_map[d_node.id].rebuild_ui()
			_mark_dirty()
		)
		card.add_child(txt_edit)
		
		# Target next node
		var target_row: HBoxContainer = HBoxContainer.new()
		card.add_child(target_row)
		var tgt_lbl: Label = Label.new()
		tgt_lbl.text = "Target ID:"
		target_row.add_child(tgt_lbl)
		var tgt_edit: LineEdit = LineEdit.new()
		tgt_edit.text = String(ch.next)
		tgt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tgt_edit.text_changed.connect(func(nt: String) -> void:
			ch.next = StringName(nt)
			if _nodes_map.has(d_node.id):
				_nodes_map[d_node.id].rebuild_ui()
				_reconnect_node_outputs(d_node)
			_mark_dirty()
		)
		target_row.add_child(tgt_edit)
		
		# Required Class
		var class_row: HBoxContainer = HBoxContainer.new()
		card.add_child(class_row)
		var cl_lbl: Label = Label.new()
		cl_lbl.text = "Class:"
		class_row.add_child(cl_lbl)
		var class_opt: OptionButton = OptionButton.new()
		class_opt.add_item("Any", 0)
		class_opt.add_item("profiler", 1)
		class_opt.add_item("tech", 2)
		class_opt.add_item("breacher", 3)
		class_opt.add_item("medic", 4)
		match String(ch.required_class):
			"profiler": class_opt.selected = 1
			"tech": class_opt.selected = 2
			"breacher": class_opt.selected = 3
			"medic": class_opt.selected = 4
			_: class_opt.selected = 0
		class_opt.item_selected.connect(func(idx: int) -> void:
			if idx == 0:
				ch.required_class = &""
			else:
				ch.required_class = StringName(class_opt.get_item_text(idx))
			if _nodes_map.has(d_node.id):
				_nodes_map[d_node.id].rebuild_ui()
			_mark_dirty()
		)
		class_row.add_child(class_opt)
		
		# Patience Delta
		var pat_lbl: Label = Label.new()
		pat_lbl.text = "Patience Δ:"
		class_row.add_child(pat_lbl)
		var pat_spin: SpinBox = SpinBox.new()
		pat_spin.min_value = -60.0
		pat_spin.max_value = 60.0
		pat_spin.step = 1.0
		pat_spin.value = ch.patience_delta
		pat_spin.suffix = "s"
		pat_spin.value_changed.connect(func(v: float) -> void:
			ch.patience_delta = v
			if _nodes_map.has(d_node.id):
				_nodes_map[d_node.id].rebuild_ui()
			_mark_dirty()
		)
		class_row.add_child(pat_spin)
		
		# Required Evidence
		var ev_lbl: Label = Label.new()
		ev_lbl.text = "Required Evidence:"
		card.add_child(ev_lbl)
		var ev_edit: LineEdit = LineEdit.new()
		ev_edit.text = ", ".join(ch.required_evidence.map(func(e: StringName) -> String: return String(e)))
		ev_edit.placeholder_text = "evidence_loop_detected, evidence_emf_hum"
		ev_edit.text_changed.connect(func(et: String) -> void:
			var parsed: Array[StringName] = []
			for s in et.split(","):
				var stripped: String = s.strip_edges()
				if stripped != "":
					parsed.append(StringName(stripped))
			ch.required_evidence = parsed
			if _nodes_map.has(d_node.id):
				_nodes_map[d_node.id].rebuild_ui()
			_mark_dirty()
		)
		card.add_child(ev_edit)
		
		# Reveals
		var rev_lbl: Label = Label.new()
		rev_lbl.text = "Reveals (Intel keys):"
		card.add_child(rev_lbl)
		var rev_edit: LineEdit = LineEdit.new()
		rev_edit.text = ", ".join(ch.reveals.map(func(r: StringName) -> String: return String(r)))
		rev_edit.placeholder_text = "intel_cult_leader, clue_weapon"
		rev_edit.text_changed.connect(func(rt: String) -> void:
			var parsed: Array[StringName] = []
			for s in rt.split(","):
				var stripped: String = s.strip_edges()
				if stripped != "":
					parsed.append(StringName(stripped))
			ch.reveals = parsed
			_mark_dirty()
		)
		card.add_child(rev_edit)


func _on_inspector_id_changed(new_id: String) -> void:
	if _selected_node != null:
		var old_id: StringName = _selected_node.id
		var new_sn: StringName = StringName(new_id)
		_selected_node.id = new_sn
		if _nodes_map.has(old_id):
			var gn: GraphNode = _nodes_map[old_id] as GraphNode
			_nodes_map.erase(old_id)
			_nodes_map[new_sn] = gn
			gn.name = new_id if new_id != "" else "node"
			gn.call("rebuild_ui")
		_mark_dirty()


func _on_inspector_speaker_selected(idx: int) -> void:
	if _selected_node != null:
		_selected_node.speaker = StringName(_ins_speaker.get_item_text(idx))
		if _nodes_map.has(_selected_node.id):
			_nodes_map[_selected_node.id].rebuild_ui()
		_mark_dirty()


func _on_inspector_line_changed() -> void:
	if _selected_node != null:
		_selected_node.line = _ins_line.text
		if _nodes_map.has(_selected_node.id):
			_nodes_map[_selected_node.id].rebuild_ui()
		_mark_dirty()


func _on_inspector_audio_changed(new_path: String) -> void:
	if _selected_node != null:
		if FileAccess.file_exists(new_path):
			var aud: Resource = ResourceLoader.load(new_path)
			if aud is AudioStream:
				_selected_node.audio = aud as AudioStream
		elif new_path.strip_edges() == "":
			_selected_node.audio = null
		_mark_dirty()


func _on_inspector_events_changed(events_str: String) -> void:
	if _selected_node != null:
		var ev_list: Array[StringName] = []
		for item in events_str.split(","):
			var clean: String = item.strip_edges()
			if clean != "":
				ev_list.append(StringName(clean))
		_selected_node.on_enter_events = ev_list
		_mark_dirty()


func _on_inspector_auto_next_changed(new_target: String) -> void:
	if _selected_node != null:
		_selected_node.auto_next = StringName(new_target)
		if _nodes_map.has(_selected_node.id):
			_nodes_map[_selected_node.id].rebuild_ui()
			_reconnect_node_outputs(_selected_node)
		_mark_dirty()


func _on_inspector_auto_delay_changed(val: float) -> void:
	if _selected_node != null:
		_selected_node.auto_delay = val
		_mark_dirty()


func _on_inspector_add_choice() -> void:
	if _selected_node != null:
		add_choice_to_node(_selected_node)


func _on_inspector_delete_node() -> void:
	if _selected_node != null:
		delete_node(_selected_node.id)


# ==============================================================================
# Toolbar Actions
# ==============================================================================

func _on_set_selected_as_start() -> void:
	if _selected_node != null and dialogue_graph != null:
		dialogue_graph.initial_node_id = _selected_node.id
		for d_node in dialogue_graph.nodes:
			if d_node != null and _nodes_map.has(d_node.id):
				_nodes_map[d_node.id].is_initial_node = (d_node.id == dialogue_graph.initial_node_id)
		_mark_dirty()


func _on_validate_pressed() -> void:
	if dialogue_graph == null:
		return
	
	var res: Dictionary = dialogue_graph.validate_graph()
	var is_valid: bool = res.get("valid", false) == true
	var errors: Array = res.get("errors", [])
	var warnings: Array = res.get("warnings", [])
	
	var msg: String = ""
	if is_valid:
		msg += "✅ Dialogue Graph is VALID!\n\n"
	else:
		msg += "❌ Graph has %d ERROR(S):\n" % errors.size()
		for e in errors:
			msg += "  • %s\n" % str(e)
		msg += "\n"
	
	if not warnings.is_empty():
		msg += "⚠️ %d WARNING(S):\n" % warnings.size()
		for w in warnings:
			msg += "  • %s\n" % str(w)
	
	_validation_dialog.dialog_text = msg
	_validation_dialog.popup_centered(Vector2i(450, 300))


func auto_layout_nodes() -> void:
	if dialogue_graph == null or dialogue_graph.nodes.is_empty():
		return
	
	# BFS hierarchy assignment from initial_node_id
	var depth_map: Dictionary[StringName, int] = {}
	var queue: Array[StringName] = [dialogue_graph.initial_node_id]
	depth_map[dialogue_graph.initial_node_id] = 0
	
	while not queue.is_empty():
		var curr_id: StringName = queue.pop_front()
		var curr_depth: int = depth_map[curr_id]
		var dnode: DialogueNode = dialogue_graph.get_node(curr_id)
		if dnode == null:
			continue
		
		# Traverse choice targets
		for ch in dnode.choices:
			if ch != null and ch.next != &"" and not depth_map.has(ch.next):
				depth_map[ch.next] = curr_depth + 1
				queue.append(ch.next)
		
		# Traverse auto_next target
		if dnode.choices.is_empty() and dnode.auto_next != &"" and not depth_map.has(dnode.auto_next):
			depth_map[dnode.auto_next] = curr_depth + 1
			queue.append(dnode.auto_next)
	
	# Group nodes by depth
	var depth_groups: Dictionary[int, Array] = {}
	var max_depth: int = 0
	for d_node in dialogue_graph.nodes:
		if d_node == null:
			continue
		var d: int = depth_map.get(d_node.id, -1)
		if d < 0:
			d = 999 # Unconnected nodes placed on far right
		max_depth = maxi(max_depth, d if d != 999 else 0)
		if not depth_groups.has(d):
			depth_groups[d] = []
		depth_groups[d].append(d_node)
	
	# Position nodes
	var col_spacing: float = 340.0
	var row_spacing: float = 240.0
	var start_pos: Vector2 = Vector2(60, 60)
	
	for depth in depth_groups.keys():
		var col_idx: int = depth if depth != 999 else max_depth + 1
		var nodes_in_col: Array = depth_groups[depth]
		for row_idx in range(nodes_in_col.size()):
			var node: DialogueNode = nodes_in_col[row_idx] as DialogueNode
			var new_pos: Vector2 = start_pos + Vector2(col_idx * col_spacing, row_idx * row_spacing)
			node.editor_position = new_pos
			if _nodes_map.has(node.id):
				_nodes_map[node.id].position_offset = new_pos
	
	_mark_dirty()


func _on_open_pressed() -> void:
	_dialog_mode = 0
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.title = "Open Dialogue Graph"
	_file_dialog.popup_centered(Vector2i(700, 500))


func _on_save_as_pressed() -> void:
	_dialog_mode = 1
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.title = "Save Dialogue Graph As..."
	_file_dialog.popup_centered(Vector2i(700, 500))


func _on_file_selected(path: String) -> void:
	if _dialog_mode == 0:
		load_from_file(path)
	elif _dialog_mode == 1:
		save_to_file(path)
