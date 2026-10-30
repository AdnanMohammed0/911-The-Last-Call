## Local, offline walkthrough for the station's real dispatch controls.
class_name TrainingNight
extends CanvasLayer

const CALL_ID: StringName = &"training_line_check"
const STATION_SCENE: String = "res://scenes/dispatch/operations_room.tscn"

enum Step { MOVE, COMPUTER, LEAVE_COMPUTER, PHONE, REPLY, VERDICT, COMPLETE }

var step: Step = Step.MOVE
var _start_position: Vector3 = Vector3.INF
var _computer: DispatchComputer
var _setup: DispatchSetup
var _title: Label
var _instruction: Label
var _progress: Label
var _finish_button: Button
var _retry_timer: float = 0.0
var _last_verdict: StringName = &""


func _ready() -> void:
	visible = GameState.training_active and not NetManager.is_online()
	if not visible:
		set_process(false)
		return
	layer = 60
	_setup = get_parent().get_node_or_null(^"DispatchSetup") as DispatchSetup
	_build_card()
	EventBus.call_connected.connect(_on_connected)
	EventBus.dialogue_node_changed.connect(_on_dialogue_node)
	EventBus.call_assessment_started.connect(_on_assessment)
	EventBus.call_classified.connect(_on_classified)
	EventBus.call_missed.connect(_on_missed)
	_show_step()


func _process(delta: float) -> void:
	if step == Step.MOVE:
		var player: Player = Player.find_by_peer(get_tree(), 1)
		if player == null:
			return
		if _start_position == Vector3.INF:
			_start_position = player.global_position
		elif player.global_position.distance_to(_start_position) >= 2.5:
			_set_step(Step.COMPUTER)
	elif step == Step.COMPUTER:
		if _find_active_computer():
			_set_step(Step.LEAVE_COMPUTER)
	elif step == Step.LEAVE_COMPUTER:
		if _computer != null and is_instance_valid(_computer) and not _computer._is_active:
			_set_step(Step.PHONE)
			_ring_call()
	elif step == Step.PHONE and _retry_timer > 0.0:
		_retry_timer -= delta
		if _retry_timer <= 0.0:
			_ring_call()


func _find_active_computer() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"dispatch_computers"):
		var computer: DispatchComputer = node as DispatchComputer
		if computer != null and computer._is_active:
			_computer = computer
			return true
	# The station's computer may not belong to a group in older room scenes.
	for node: Node in get_tree().get_nodes_in_group(&"interactables"):
		var computer: DispatchComputer = node as DispatchComputer
		if computer != null and computer._is_active:
			_computer = computer
			return true
	return false


func _ring_call() -> void:
	if not multiplayer.is_server() or CallDirector.current_state != CallDirector.CallState.IDLE:
		return
	if CallDirector.registered_calls.has(CALL_ID):
		CallDirector.ring_call(CALL_ID)


func _on_connected(call_id: StringName, _call: CallData) -> void:
	if call_id == CALL_ID and step == Step.PHONE:
		_set_step(Step.REPLY)


func _on_dialogue_node(node_id: StringName, _speaker: StringName, _line: String, _choices: Array) -> void:
	if CallDirector.active_call_id == CALL_ID and step == Step.REPLY and node_id != &"start":
		_set_step(Step.VERDICT)


func _on_assessment(call_id: StringName) -> void:
	if call_id == CALL_ID and step == Step.REPLY:
		_set_step(Step.VERDICT)


func _on_classified(call_id: StringName, verdict: StringName) -> void:
	if call_id == CALL_ID:
		_last_verdict = verdict
		_set_step(Step.COMPLETE)


func _on_missed(call_id: StringName) -> void:
	if call_id == CALL_ID and step == Step.PHONE:
		_retry_timer = 2.0
		_instruction.text = "The practice line timed out. It will ring again in a moment."


func _set_step(next_step: Step) -> void:
	step = next_step
	_show_step()


func _show_step() -> void:
	var messages: Array[String] = [
		"Move around Station 4 using WASD. Walk a few steps to get your bearings.",
		"Find the dispatch computer beside the phone and use it with F.",
		"Look at Station OS. Press Esc or Log off to stand up again.",
		"The training line is ringing. Go to the desk phone and answer with F.",
		"Read the caller's message on CAD and choose a reply.",
		"After the line closes, classify this drill as Prank on CAD.",
		"Training complete. You're ready for a regular shift."
	]
	_title.text = "TRAINING NIGHT  /  %s" % ("COMPLETE" if step == Step.COMPLETE else "STATION 4")
	_instruction.text = messages[int(step)]
	if step == Step.COMPLETE and _last_verdict != &"prank":
		_instruction.text += " The correct classification was Prank."
	_progress.text = "%d / 6" % mini(int(step) + 1, 6)
	_finish_button.visible = step == Step.COMPLETE


func _build_card() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "GuideCard"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = 20.0
	panel.custom_minimum_size.y = 130.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.07, 0.94)
	style.border_color = Color(0.93, 0.56, 0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override(&"panel", style)
	root.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	_title = Label.new()
	_title.add_theme_color_override(&"font_color", Color(1.0, 0.68, 0.28))
	_title.add_theme_font_size_override(&"font_size", 17)
	column.add_child(_title)
	_instruction = Label.new()
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.add_theme_font_size_override(&"font_size", 16)
	column.add_child(_instruction)
	var footer: HBoxContainer = HBoxContainer.new()
	column.add_child(footer)
	_progress = Label.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_progress)
	_finish_button = Button.new()
	_finish_button.text = "Start regular shift"
	_finish_button.pressed.connect(_leave_training)
	footer.add_child(_finish_button)
	var skip: Button = Button.new()
	skip.text = "Skip training"
	skip.pressed.connect(_leave_training)
	footer.add_child(skip)


func _leave_training() -> void:
	CallDirector.reset()
	CallDirector.registered_calls.clear()
	MissionDirector.reset()
	GameState.training_active = false
	get_tree().change_scene_to_file(STATION_SCENE)
