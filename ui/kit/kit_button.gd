## Themed button with an optional vector icon and a style variant:
##   default — dark glass, primary — solid accent, ghost — transparent until hovered, danger — red outline,
##   tile — large square app / category tile (icon above text).
## Authority: LOCAL
class_name KitButton
extends Button

enum Variant { DEFAULT, PRIMARY, GHOST, DANGER, TILE, SUBTLE }

var icon_name: StringName = &""
var variant: Variant = Variant.DEFAULT
var icon_size: float = 18.0
var icon_tint: Color = Color(0, 0, 0, 0)
var accent: Color = GameTheme.ACCENT


static func make(text_value: String, icon_value: StringName = &"", style_variant: Variant = Variant.DEFAULT, callback: Callable = Callable()) -> KitButton:
	var button: KitButton = KitButton.new()
	button.text = text_value
	button.icon_name = icon_value
	button.variant = style_variant
	if callback.is_valid():
		button.pressed.connect(callback)
	return button


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_variant()
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func apply_variant() -> void:
	var pad_left: int = 16
	if icon_name != &"" and variant != Variant.TILE:
		pad_left = int(16 + icon_size + 10)
	if text.is_empty() and icon_name != &"":
		pad_left = int(10 + icon_size * 0.5)
	var right: int = 16 if not text.is_empty() else pad_left
	var states: Dictionary[StringName, StyleBoxFlat] = {}
	match variant:
		Variant.PRIMARY:
			states[&"normal"] = UiKit.style(accent, GameTheme.RADIUS, pad_left, 11)
			states[&"hover"] = UiKit.style(accent.lightened(0.12), GameTheme.RADIUS, pad_left, 11)
			states[&"pressed"] = UiKit.style(accent.darkened(0.15), GameTheme.RADIUS, pad_left, 11)
			states[&"disabled"] = UiKit.style(Color(accent, 0.25), GameTheme.RADIUS, pad_left, 11)
			add_theme_color_override(&"font_color", Color.WHITE)
		Variant.GHOST:
			states[&"normal"] = UiKit.style(Color(1, 1, 1, 0.0), GameTheme.RADIUS, pad_left, 9)
			states[&"hover"] = UiKit.style(Color(1, 1, 1, 0.07), GameTheme.RADIUS, pad_left, 9)
			states[&"pressed"] = UiKit.style(Color(1, 1, 1, 0.12), GameTheme.RADIUS, pad_left, 9)
			states[&"disabled"] = UiKit.style(Color(1, 1, 1, 0.0), GameTheme.RADIUS, pad_left, 9)
		Variant.SUBTLE:
			states[&"normal"] = UiKit.style(Color(1, 1, 1, 0.045), GameTheme.RADIUS, pad_left, 9, Color(1, 1, 1, 0.06), 1)
			states[&"hover"] = UiKit.style(Color(1, 1, 1, 0.09), GameTheme.RADIUS, pad_left, 9, Color(1, 1, 1, 0.1), 1)
			states[&"pressed"] = UiKit.style(Color(1, 1, 1, 0.05), GameTheme.RADIUS, pad_left, 9, Color(1, 1, 1, 0.1), 1)
			states[&"disabled"] = UiKit.style(Color(1, 1, 1, 0.02), GameTheme.RADIUS, pad_left, 9)
		Variant.DANGER:
			states[&"normal"] = UiKit.style(Color(GameTheme.DANGER, 0.1), GameTheme.RADIUS, pad_left, 11, Color(GameTheme.DANGER, 0.6), 1)
			states[&"hover"] = UiKit.style(Color(GameTheme.DANGER, 0.25), GameTheme.RADIUS, pad_left, 11, GameTheme.DANGER, 1)
			states[&"pressed"] = UiKit.style(Color(GameTheme.DANGER, 0.4), GameTheme.RADIUS, pad_left, 11, GameTheme.DANGER, 1)
			states[&"disabled"] = UiKit.style(Color(GameTheme.DANGER, 0.04), GameTheme.RADIUS, pad_left, 11)
		Variant.TILE:
			var top: int = int(icon_size + 26)
			states[&"normal"] = UiKit.style(Color(1, 1, 1, 0.04), 10, 10, 10, Color(1, 1, 1, 0.06), 1)
			states[&"hover"] = UiKit.style(Color(1, 1, 1, 0.09), 10, 10, 10, Color(accent, 0.5), 1)
			states[&"pressed"] = UiKit.style(Color(accent, 0.18), 10, 10, 10, accent, 1)
			states[&"disabled"] = UiKit.style(Color(1, 1, 1, 0.02), 10, 10, 10)
			for box: StyleBoxFlat in states.values():
				box.content_margin_top = top
			vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
			alignment = HORIZONTAL_ALIGNMENT_CENTER
		_:
			states[&"normal"] = UiKit.style(GameTheme.BG_SOFT, GameTheme.RADIUS, pad_left, 11, GameTheme.BORDER, 1)
			states[&"hover"] = UiKit.style(GameTheme.BG_HOVER, GameTheme.RADIUS, pad_left, 11, Color(accent, 0.55), 1)
			states[&"pressed"] = UiKit.style(Color(accent, 0.2), GameTheme.RADIUS, pad_left, 11, accent, 1)
			states[&"disabled"] = UiKit.style(Color(0.06, 0.065, 0.075, 0.6), GameTheme.RADIUS, pad_left, 11)
	for key: StringName in states:
		var box: StyleBoxFlat = states[key]
		box.content_margin_right = right
		add_theme_stylebox_override(key, box)
	add_theme_stylebox_override(&"hover_pressed", states[&"pressed"])
	var focus: StyleBoxFlat = UiKit.style(Color(0, 0, 0, 0), 10 if variant == Variant.TILE else GameTheme.RADIUS, 0, 0, Color(accent, 0.9), 2)
	focus.draw_center = false
	add_theme_stylebox_override(&"focus", focus)
	if variant != Variant.TILE and icon_name != &"" and text.is_empty():
		custom_minimum_size.x = maxf(custom_minimum_size.x, icon_size + 22.0)
	queue_redraw()


func _draw() -> void:
	if icon_name == &"":
		return
	var tint: Color = icon_tint if icon_tint.a > 0.0 else get_theme_color(&"font_color")
	if disabled:
		tint = Color(tint, 0.35)
	elif variant == Variant.PRIMARY:
		tint = Color.WHITE
	var rect: Rect2
	if variant == Variant.TILE:
		rect = Rect2(Vector2((size.x - icon_size) * 0.5, 14.0), Vector2(icon_size, icon_size))
	elif text.is_empty():
		rect = Rect2((size - Vector2(icon_size, icon_size)) * 0.5, Vector2(icon_size, icon_size))
	else:
		rect = Rect2(Vector2(15.0, (size.y - icon_size) * 0.5), Vector2(icon_size, icon_size))
	IconView.paint(self, icon_name, rect, tint, 1.8)
