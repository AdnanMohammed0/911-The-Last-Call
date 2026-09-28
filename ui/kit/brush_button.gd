## Main-menu style button: big caps text on nothing, and on hover / focus a white brush stroke sweeps in
## behind it (the text turns dark over the paint). Keyboard / pad focus behaves exactly like hover.
## Authority: LOCAL
class_name BrushButton
extends Button

const INK: Color = Color(0.05, 0.055, 0.065)

@export var paint_colour: Color = Color(0.95, 0.95, 0.93)
@export var font_size: int = 26

var _stroke: BrushStroke


static func make(label_text: String, callback: Callable = Callable(), size_px: int = 26) -> BrushButton:
	var button: BrushButton = BrushButton.new()
	button.text = label_text.to_upper()
	button.font_size = size_px
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _ready() -> void:
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override(&"font", UiKit.tracked(&"bold", 2))
	add_theme_font_size_override(&"font_size", font_size)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = 14
	empty.content_margin_right = 26
	empty.content_margin_top = 5
	empty.content_margin_bottom = 7
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_color_override(&"font_color", Color(0.9, 0.91, 0.92))
	add_theme_color_override(&"font_hover_color", INK)
	add_theme_color_override(&"font_focus_color", INK)
	add_theme_color_override(&"font_pressed_color", INK)
	add_theme_color_override(&"font_hover_pressed_color", INK)
	add_theme_color_override(&"font_disabled_color", Color(0.9, 0.91, 0.92, 0.28))
	_stroke = BrushStroke.new()
	_stroke.colour = paint_colour
	_stroke.seed_text = text
	_stroke.show_behind_parent = true
	_stroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stroke)
	_stroke.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_entered.connect(_update)
	mouse_exited.connect(_update)
	focus_entered.connect(_update)
	focus_exited.connect(_update)
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())


func _update() -> void:
	var active: bool = not disabled and (has_focus() or is_hovered())
	_stroke.sweep(active)


## The paint itself: a ragged horizontal stroke with dry-brush streaks, revealed left to right.
class BrushStroke:
	extends Control

	var colour: Color = Color.WHITE
	var seed_text: String = ""
	var reveal: float = 0.0
	var _tween: Tween
	var _jitter: PackedFloat32Array = PackedFloat32Array()

	func sweep(active: bool) -> void:
		if _tween != null:
			_tween.kill()
		_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		_tween.tween_method(_set_reveal, reveal, 1.0 if active else 0.0, 0.28 if active else 0.18)

	func _set_reveal(value: float) -> void:
		reveal = value
		queue_redraw()

	func _draw() -> void:
		if reveal <= 0.001:
			return
		if _jitter.is_empty():
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash(seed_text)
			for i: int in 64:
				_jitter.append(rng.randf())
		var width: float = size.x * reveal
		var top: float = size.y * 0.1
		var bottom: float = size.y * 0.92
		var steps: int = 24
		var outline: PackedVector2Array = PackedVector2Array()
		# Top edge (left -> right), ragged.
		for i: int in steps + 1:
			var t: float = float(i) / steps
			outline.append(Vector2(t * width, top + (_jitter[i % 64] - 0.5) * size.y * 0.1))
		# Frayed right end.
		for i: int in 6:
			var t: float = float(i) / 5.0
			var y: float = lerpf(top, bottom, t)
			outline.append(Vector2(width + (_jitter[(i * 7) % 64] - 0.2) * 14.0 * reveal, y))
		# Bottom edge (right -> left).
		for i: int in range(steps, -1, -1):
			var t: float = float(i) / steps
			outline.append(Vector2(t * width, bottom + (_jitter[(i + 31) % 64] - 0.5) * size.y * 0.12))
		draw_colored_polygon(outline, colour)
		# Dry-brush streaks trailing past the stroke.
		for i: int in 5:
			var y: float = lerpf(top + 3.0, bottom - 3.0, _jitter[(i * 11) % 64])
			var length: float = (18.0 + _jitter[(i * 5) % 64] * 40.0) * reveal
			draw_line(Vector2(width - 6.0, y), Vector2(width + length, y + (_jitter[i] - 0.5) * 3.0), Color(colour, 0.55), 1.5 + _jitter[(i * 3) % 64] * 2.0, true)
