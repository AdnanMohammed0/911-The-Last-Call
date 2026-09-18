## Trace Mini-game UI — Three rotating dials (frequency, phase, gain) for 3-tower triangulation.
## Opens in DispatchTerminal for Tech Operator. Authority: LOCAL (UI), host validates result.
class_name TraceMiniGame
extends Control

const GROUP: StringName = &"trace_minigame"
const DIAL_SIZE: int = 120
const TOWER_ICON_SIZE: int = 32

signal trace_completed(location: Vector2, radius: float, is_dead_freq: bool)
signal trace_cancelled()

var _trace_console: TraceConsole = null
var _is_open: bool = false

var _dial_frequency: TraceDial = null
var _dial_phase: TraceDial = null
var _dial_gain: TraceDial = null

var _tower_indicators: Array[TextureRect] = []
var _status_label: Label = null
var _progress_bar: ProgressBar = null
var _tower_label: Label = null
var _result_label: RichTextLabel = null
var _close_button: Button = null
var _lock_button: Button = null

var _local_dial_freq: float = 0.5
var _local_dial_phase: float = 0.5
var _local_dial_gain: float = 0.5

var _update_timer: Timer = null


func _ready() -> void:
	add_to_group(GROUP)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	
	_update_timer = Timer.new()
	_update_timer.wait_time = 1.0 / 60.0
	_update_timer.one_shot = false
	_update_timer.timeout.connect(_on_update_tick)
	add_child(_update_timer)


## Opens the trace mini-game for the given call.
func open(trace_console: TraceConsole) -> void:
	if _is_open:
		return
	
	_trace_console = trace_console
	_local_dial_freq = 0.5
	_local_dial_phase = 0.5
	_local_dial_gain = 0.5
	
	_dial_frequency.set_value(_local_dial_freq)
	_dial_phase.set_value(_local_dial_phase)
	_dial_gain.set_value(_local_dial_gain)
	
	_refresh_towers()
	_refresh_status()
	
	_is_open = true
	visible = true
	_update_timer.start()
	
	var player: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if player != null:
		player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Closes the trace mini-game.
func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	visible = false
	_update_timer.stop()
	
	var player: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if player != null and is_instance_valid(player):
		player.set_input_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	trace_cancelled.emit()


func _on_update_tick() -> void:
	if not _is_open or _trace_console == null:
		return
	
	# Update trace console with current dial values
	var state_changed: bool = _trace_console.update(
		_update_timer.wait_time,
		_local_dial_freq,
		_local_dial_phase,
		_local_dial_gain
	)
	
	_refresh_towers()
	_refresh_status()
	
	# Update target indicators on dials
	var target: Dictionary = _trace_console.get_current_target()
	_dial_frequency.set_target(target["frequency"])
	_dial_phase.set_target(target["phase"])
	_dial_gain.set_target(target["gain"])
	
	if _trace_console.is_trace_complete():
		_on_trace_complete()


func _on_trace_complete() -> void:
	_update_timer.stop()
	
	var location: Vector2 = _trace_console.get_result_location()
	var radius: float = _trace_console.get_result_radius()
	var is_dead: bool = _trace_console.is_dead_frequency
	
	_result_label.text = "TRACE COMPLETE\nLocation: %.0f, %.0f\nRadius: %.0f m" % [location.x, location.y, radius]
	if is_dead:
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_result_label.text += "\n[DEAD FREQUENCY — IMPOSSIBLE LOCATION]"
	else:
		_result_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	
	_result_label.visible = true
	_lock_button.disabled = true
	_close_button.text = "Close"
	
	trace_completed.emit(location, radius, is_dead)


func _refresh_towers() -> void:
	if _trace_console == null:
		return
	
	for i in 3:
		var indicator: TextureRect = _tower_indicators[i]
		var state: int = int(_trace_console.get_tower_state(i))
		
		match state:
			TraceConsole.TowerState.UNLOCKED:
				indicator.modulate = Color(0.4, 0.4, 0.4)
			TraceConsole.TowerState.LOCKING:
				if i == _trace_console.get_current_tower():
					indicator.modulate = Color(1.0, 0.7, 0.2)
				else:
					indicator.modulate = Color(0.5, 0.5, 0.5)
			TraceConsole.TowerState.LOCKED:
				indicator.modulate = Color(0.4, 1.0, 0.5)
	
	var current: int = _trace_console.get_current_tower()
	_tower_label.text = "TOWER %d / 3" % (current + 1)


func _refresh_status() -> void:
	if _trace_console == null:
		return
	
	if _trace_console.is_trace_complete():
		_status_label.text = "TRACE COMPLETE"
		_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		_progress_bar.visible = false
		return
	
	var locked: int = _trace_console.get_towers_locked()
	var current: int = _trace_console.get_current_tower()
	var progress: float = _trace_console.get_lock_progress()
	
	_status_label.text = "LOCKING TOWER %d — %d/3 LOCKED" % [current + 1, locked]
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	
	_progress_bar.visible = true
	_progress_bar.value = progress


## Dial value changed callbacks
func _on_dial_freq_changed(value: float) -> void:
	_local_dial_freq = value


func _on_dial_phase_changed(value: float) -> void:
	_local_dial_phase = value


func _on_dial_gain_changed(value: float) -> void:
	_local_dial_gain = value


func _on_close_pressed() -> void:
	if _trace_console != null and _trace_console.is_trace_complete():
		close()
	else:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	
	var frame: PanelContainer = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = Vector2(600, 500)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.08, 0.98)
	style.border_color = Color(0.2, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)
	
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 15)
	frame.add_child(root)
	
	# Header
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	var title: Label = _label("TRACE CONSOLE — 3-TOWER TRIANGULATION", 22, Color(0.4, 0.9, 1.0), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = _button("Cancel", _on_close_pressed)
	header.add_child(_close_button)
	
	# Tower indicators
	var towers_box: HBoxContainer = HBoxContainer.new()
	towers_box.add_theme_constant_override("separation", 20)
	towers_box.alignment = HBoxContainer.ALIGNMENT_CENTER
	root.add_child(towers_box)
	
	for i: int in 3:
		var tower_box: VBoxContainer = VBoxContainer.new()
		tower_box.add_theme_constant_override("separation", 5)
		towers_box.add_child(tower_box)
		
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(TOWER_ICON_SIZE, TOWER_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		# Create a simple tower icon
		var img: Image = Image.create(TOWER_ICON_SIZE, TOWER_ICON_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var rect: Rect2 = Rect2(TOWER_ICON_SIZE * 0.3, TOWER_ICON_SIZE * 0.2, TOWER_ICON_SIZE * 0.4, TOWER_ICON_SIZE * 0.6)
		img.fill_rect(rect, Color(0.5, 0.5, 0.5))
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		icon.texture = tex
		tower_box.add_child(icon)
		_tower_indicators.append(icon)
		
		var num: Label = _label("TOWER %d" % [i + 1], 12, Color(0.7, 0.8, 0.9))
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tower_box.add_child(num)
	
	# Three dials
	var dials_box: HBoxContainer = HBoxContainer.new()
	dials_box.add_theme_constant_override("separation", 30)
	dials_box.alignment = HBoxContainer.ALIGNMENT_CENTER
	root.add_child(dials_box)
	
	_dial_frequency = TraceDial.new("FREQUENCY", _on_dial_freq_changed)
	_dial_frequency.custom_minimum_size = Vector2(DIAL_SIZE, DIAL_SIZE)
	dials_box.add_child(_dial_frequency)
	
	_dial_phase = TraceDial.new("PHASE", _on_dial_phase_changed)
	_dial_phase.custom_minimum_size = Vector2(DIAL_SIZE, DIAL_SIZE)
	dials_box.add_child(_dial_phase)
	
	_dial_gain = TraceDial.new("GAIN", _on_dial_gain_changed)
	_dial_gain.custom_minimum_size = Vector2(DIAL_SIZE, DIAL_SIZE)
	dials_box.add_child(_dial_gain)
	
	# Status and progress
	_status_label = _label("LOCKING TOWER 1 — 0/3 LOCKED", 18, Color(1.0, 0.7, 0.2), false)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)
	
	_tower_label = _label("TOWER 1 / 3", 14, Color(0.7, 0.8, 0.9), false)
	_tower_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_tower_label)
	
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(300, 20)
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.4, 0.9, 0.5)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	root.add_child(_progress_bar)
	
	# Result label (hidden until complete)
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.visible = false
	_result_label.add_theme_font_size_override("normal_font_size", 16)
	root.add_child(_result_label)
	
	# Lock button (for manual lock attempt)
	_lock_button = _button("Hold Alignment", func() -> void: pass)
	_lock_button.disabled = true  # Auto-locks when aligned
	root.add_child(_lock_button)
	
	# Hint
	var hint: Label = _label("Align all three dials (frequency, phase, gain) to lock each tower.\nNoise drifts targets — hold alignment for 6-10 seconds per tower.", 14, Color(0.6, 0.7, 0.8), false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)


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
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(callback)
	return button


# --- Trace Dial Sub-class -----------------------------------------------------

class TraceDial extends Control:
	var _label: Label
	var _value: float = 0.5
	var _target: float = 0.5
	var _knob_angle: float = 0.0
	var _dragging: bool = false
	var _on_changed: Callable
	var _size: int = DIAL_SIZE
	
	func _init(dial_name: String, on_changed: Callable) -> void:
		_on_changed = on_changed
		set_process_input(true)
	
	func _ready() -> void:
		custom_minimum_size = Vector2(_size, _size)
	
	func _gui_input(event: InputEvent) -> void:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mb != null:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = true
					_update_from_mouse(mb.position)
				else:
					_dragging = false
		elif mm != null and _dragging:
			_update_from_mouse(mm.position)
	
	func _update_from_mouse(mouse_pos: Vector2) -> void:
		var center: Vector2 = Vector2(_size * 0.5, _size * 0.5)
		var dir: Vector2 = mouse_pos - center
		var angle: float = atan2(dir.y, dir.x)
		# Convert angle (-PI..PI) to 0..1
		_value = (angle + PI) / (2.0 * PI)
		_value = fposmod(_value, 1.0)
		_knob_angle = angle
		_on_changed.call(_value)
		queue_redraw()
	
	func _draw() -> void:
		var center: Vector2 = Vector2(_size * 0.5, _size * 0.5)
		var radius: float = _size * 0.45
		
		# Background circle
		draw_circle(center, radius, Color(0.05, 0.1, 0.15))
		draw_circle(center, radius, Color(0.2, 0.5, 0.8), false, 2)
		
		# Target marker
		var target_angle: float = (_target * 2.0 * PI) - PI
		var target_pos: Vector2 = center + Vector2(cos(target_angle), sin(target_angle)) * (radius - 8)
		draw_circle(target_pos, 6, Color(1.0, 0.7, 0.2, 0.8))
		draw_circle(target_pos, 6, Color(1.0, 0.9, 0.5), false, 2)
		
		# Tick marks
		for i: int in 12:
			var tick_angle: float = (i / 12.0) * 2.0 * PI - PI
			var inner: Vector2 = center + Vector2(cos(tick_angle), sin(tick_angle)) * (radius - 15)
			var outer: Vector2 = center + Vector2(cos(tick_angle), sin(tick_angle)) * radius
			draw_line(inner, outer, Color(0.3, 0.5, 0.7), 1)
		
		# Knob
		var knob_pos: Vector2 = center + Vector2(cos(_knob_angle), sin(_knob_angle)) * (radius - 20)
		draw_circle(center, 8, Color(0.15, 0.3, 0.5))
		draw_line(center, knob_pos, Color(0.4, 0.9, 1.0), 3)
		draw_circle(knob_pos, 10, Color(0.3, 0.6, 1.0))
		draw_circle(knob_pos, 10, Color(0.2, 0.5, 0.8), false, 2)
		
		# Value text
		var value_text: String = "%.0f%%" % [_value * 100]
		draw_string(get_theme_font("font"), center - Vector2(30, 0), value_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.8, 0.9, 1.0))
	
	func set_value(val: float) -> void:
		_value = clampf(val, 0.0, 1.0)
		_knob_angle = (_value * 2.0 * PI) - PI
		queue_redraw()
	
	func set_target(val: Variant) -> void:
		var f: float = val
		_target = clampf(f, 0.0, 1.0)
		queue_redraw()