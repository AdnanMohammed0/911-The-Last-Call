## The game's UI theme, built in code so every menu and HUD shares one look: dark translucent panels,
## amber accent for focus / hover / selection, consistent paddings and font sizes.
## GameSettings assigns it to the root window, so every Control inherits it.
## Authority: LOCAL
class_name GameTheme
extends RefCounted

const BG: Color = Color(0.045, 0.05, 0.06, 0.94)
const BG_SOFT: Color = Color(0.09, 0.1, 0.115, 0.95)
const BG_HOVER: Color = Color(0.14, 0.15, 0.17, 1.0)
const BORDER: Color = Color(1, 1, 1, 0.08)
const ACCENT: Color = Color(0.95, 0.7, 0.25)
const ACCENT_DIM: Color = Color(0.95, 0.7, 0.25, 0.35)
const TEXT: Color = Color(0.9, 0.92, 0.94)
const TEXT_DIM: Color = Color(0.6, 0.64, 0.68)
const DANGER: Color = Color(0.9, 0.3, 0.28)
const FONT_SIZE: int = 18
const RADIUS: int = 4


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE

	# Panels.
	var panel: StyleBoxFlat = _box(BG, RADIUS, 28, 22)
	panel.border_color = BORDER
	panel.set_border_width_all(1)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"panel", &"Panel", panel)
	theme.set_stylebox(&"panel", &"PopupPanel", panel)
	theme.set_stylebox(&"panel", &"PopupMenu", _box(BG, RADIUS, 8, 6))

	# Labels.
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0.45))
	theme.set_constant(&"shadow_offset_y", &"Label", 1)
	theme.set_constant(&"line_spacing", &"Label", 4)

	# Buttons (Button, OptionButton, CheckBox / CheckButton share the colors).
	for type: StringName in [&"Button", &"OptionButton", &"MenuButton"]:
		var normal: StyleBoxFlat = _box(BG_SOFT, RADIUS, 18, 10)
		normal.border_color = BORDER
		normal.set_border_width_all(1)
		var hover: StyleBoxFlat = _box(BG_HOVER, RADIUS, 18, 10)
		hover.border_color = ACCENT_DIM
		hover.set_border_width_all(1)
		var pressed: StyleBoxFlat = _box(BG_HOVER, RADIUS, 18, 10)
		pressed.border_color = ACCENT
		pressed.set_border_width_all(1)
		var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), RADIUS, 18, 10)
		focus.border_color = ACCENT
		focus.set_border_width_all(2)
		focus.draw_center = false
		var disabled: StyleBoxFlat = _box(Color(0.07, 0.07, 0.08, 0.8), RADIUS, 18, 10)
		theme.set_stylebox(&"normal", type, normal)
		theme.set_stylebox(&"hover", type, hover)
		theme.set_stylebox(&"pressed", type, pressed)
		theme.set_stylebox(&"hover_pressed", type, pressed)
		theme.set_stylebox(&"focus", type, focus)
		theme.set_stylebox(&"disabled", type, disabled)
		theme.set_color(&"font_color", type, TEXT)
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, ACCENT)
		theme.set_color(&"font_focus_color", type, Color.WHITE)
		theme.set_color(&"font_disabled_color", type, TEXT_DIM * Color(1, 1, 1, 0.6))
		theme.set_constant(&"h_separation", type, 10)
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		var clear: StyleBoxEmpty = StyleBoxEmpty.new()
		clear.content_margin_top = 6
		clear.content_margin_bottom = 6
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			theme.set_stylebox(state, type, clear)
		theme.set_color(&"font_color", type, TEXT)
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, TEXT)
		theme.set_color(&"font_hover_pressed_color", type, Color.WHITE)
		theme.set_constant(&"h_separation", type, 12)

	# Text input.
	var line: StyleBoxFlat = _box(Color(0.02, 0.025, 0.03, 0.95), RADIUS, 12, 8)
	line.border_color = BORDER
	line.set_border_width_all(1)
	var line_focus: StyleBoxFlat = line.duplicate() as StyleBoxFlat
	line_focus.border_color = ACCENT
	theme.set_stylebox(&"normal", &"LineEdit", line)
	theme.set_stylebox(&"focus", &"LineEdit", line_focus)
	theme.set_color(&"font_color", &"LineEdit", TEXT)
	theme.set_color(&"caret_color", &"LineEdit", ACCENT)
	theme.set_color(&"selection_color", &"LineEdit", ACCENT_DIM)

	# Sliders and bars.
	var track: StyleBoxFlat = _box(Color(1, 1, 1, 0.12), 2, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled: StyleBoxFlat = _box(ACCENT, 2, 0, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", filled)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	var grabber: Image = Image.create(18, 18, false, Image.FORMAT_RGBA8)
	for y: int in 18:
		for x: int in 18:
			var d: float = Vector2(x - 8.5, y - 8.5).length()
			grabber.set_pixel(x, y, Color(TEXT, clampf(8.5 - d, 0.0, 1.0)))
	var grabber_texture: ImageTexture = ImageTexture.create_from_image(grabber)
	theme.set_icon(&"grabber", &"HSlider", grabber_texture)
	theme.set_icon(&"grabber_highlight", &"HSlider", grabber_texture)
	theme.set_stylebox(&"background", &"ProgressBar", _box(Color(1, 1, 1, 0.1), 2, 0, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _box(ACCENT, 2, 0, 0))
	theme.set_color(&"font_color", &"ProgressBar", TEXT)

	# Tabs.
	var tab_selected: StyleBoxFlat = _box(Color(0, 0, 0, 0), 0, 22, 12)
	tab_selected.border_color = ACCENT
	tab_selected.border_width_bottom = 3
	var tab_idle: StyleBoxFlat = _box(Color(0, 0, 0, 0), 0, 22, 12)
	tab_idle.border_color = BORDER
	tab_idle.border_width_bottom = 1
	var tab_hover: StyleBoxFlat = tab_idle.duplicate() as StyleBoxFlat
	tab_hover.border_color = ACCENT_DIM
	tab_hover.border_width_bottom = 3
	theme.set_stylebox(&"tab_selected", &"TabContainer", tab_selected)
	theme.set_stylebox(&"tab_unselected", &"TabContainer", tab_idle)
	theme.set_stylebox(&"tab_hovered", &"TabContainer", tab_hover)
	theme.set_stylebox(&"tab_focus", &"TabContainer", StyleBoxEmpty.new())
	theme.set_stylebox(&"panel", &"TabContainer", _box(Color(0, 0, 0, 0), 0, 0, 18))
	theme.set_color(&"font_selected_color", &"TabContainer", Color.WHITE)
	theme.set_color(&"font_unselected_color", &"TabContainer", TEXT_DIM)
	theme.set_color(&"font_hovered_color", &"TabContainer", TEXT)
	theme.set_font_size(&"font_size", &"TabContainer", 17)

	# Lists and scroll bars.
	theme.set_stylebox(&"panel", &"ItemList", _box(Color(0.02, 0.025, 0.03, 0.8), RADIUS, 8, 8))
	theme.set_stylebox(&"selected", &"ItemList", _box(ACCENT_DIM, 2, 4, 2))
	theme.set_stylebox(&"selected_focus", &"ItemList", _box(ACCENT_DIM, 2, 4, 2))
	theme.set_color(&"font_color", &"ItemList", TEXT)
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", bar, _box(Color(1, 1, 1, 0.04), 3, 0, 0))
		theme.set_stylebox(&"grabber", bar, _box(Color(1, 1, 1, 0.22), 3, 3, 3))
		theme.set_stylebox(&"grabber_hover", bar, _box(ACCENT_DIM, 3, 3, 3))
		theme.set_stylebox(&"grabber_pressed", bar, _box(ACCENT, 3, 3, 3))

	# Separators and tooltips.
	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = BORDER
	separator.thickness = 1
	theme.set_stylebox(&"separator", &"HSeparator", separator)
	theme.set_constant(&"separation", &"HSeparator", 16)
	theme.set_stylebox(&"panel", &"TooltipPanel", _box(BG, RADIUS, 10, 6))
	theme.set_constant(&"separation", &"VBoxContainer", 10)
	theme.set_constant(&"separation", &"HBoxContainer", 10)
	return theme


static func _box(color: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	return box


## Section heading used by menus (small caps, accent).
static func heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.add_theme_color_override(&"font_color", ACCENT)
	label.add_theme_font_size_override(&"font_size", 14)
	return label


## Large screen title.
static func title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 34)
	return label
