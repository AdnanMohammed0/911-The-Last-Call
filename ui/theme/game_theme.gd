## The game's UI theme, built in code so every menu and HUD shares one look: Barlow type, near-black glass
## panels, emergency-red accent (siren blue as the secondary), 6 px corners, soft borders and consistent
## paddings. GameSettings assigns it to the root window, so every Control inherits it; UiKit builds the
## richer pieces (brush buttons, acrylic panels, icons) on top of these tokens.
## Authority: LOCAL
class_name GameTheme
extends RefCounted

const INK: Color = Color(0.027, 0.032, 0.04, 1.0)
const BG: Color = Color(0.035, 0.04, 0.05, 0.9)
const BG_SOFT: Color = Color(0.085, 0.095, 0.11, 0.92)
const BG_HOVER: Color = Color(0.14, 0.15, 0.17, 0.96)
const BORDER: Color = Color(1, 1, 1, 0.08)
const BORDER_STRONG: Color = Color(1, 1, 1, 0.16)
const ACCENT: Color = Color(0.93, 0.24, 0.21)
const ACCENT_DIM: Color = Color(0.93, 0.24, 0.21, 0.35)
const SIREN_BLUE: Color = Color(0.26, 0.52, 1.0)
const SUCCESS: Color = Color(0.36, 0.86, 0.52)
const WARNING: Color = Color(1.0, 0.72, 0.26)
const TEXT: Color = Color(0.94, 0.95, 0.96)
const TEXT_DIM: Color = Color(0.58, 0.62, 0.67)
const TEXT_FAINT: Color = Color(0.4, 0.43, 0.47)
const DANGER: Color = Color(0.93, 0.3, 0.27)
const FONT_SIZE: int = 18
const RADIUS: int = 6

const FONT_DIR: String = "res://assets/fonts/barlow/"
const FONT_FILES: Dictionary[StringName, String] = {
	&"light": "Barlow-Light.ttf", &"regular": "Barlow-Regular.ttf", &"medium": "Barlow-Medium.ttf",
	&"semibold": "Barlow-SemiBold.ttf", &"bold": "Barlow-Bold.ttf", &"extrabold": "Barlow-ExtraBold.ttf",
	&"black": "Barlow-Black.ttf", &"black_italic": "Barlow-BlackItalic.ttf", &"bold_italic": "Barlow-BoldItalic.ttf",
}

static var _fonts: Dictionary[StringName, Font] = {}


## Barlow weight (see FONT_FILES); falls back to the engine font when the file is missing.
static func font(weight: StringName = &"medium") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var path: String = FONT_DIR + FONT_FILES.get(weight, FONT_FILES[&"medium"])
	var loaded: Font = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Font
	if loaded == null:
		loaded = ThemeDB.fallback_font
	_fonts[weight] = loaded
	return loaded


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = font(&"medium")
	theme.default_font_size = FONT_SIZE

	# Panels.
	var panel: StyleBoxFlat = _box(BG, RADIUS + 2, 28, 22)
	panel.border_color = BORDER
	panel.set_border_width_all(1)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 18
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"panel", &"Panel", panel)
	theme.set_stylebox(&"panel", &"PopupPanel", panel)
	var popup: StyleBoxFlat = _box(Color(0.06, 0.065, 0.08, 0.98), RADIUS, 6, 6)
	popup.border_color = BORDER_STRONG
	popup.set_border_width_all(1)
	theme.set_stylebox(&"panel", &"PopupMenu", popup)
	theme.set_stylebox(&"hover", &"PopupMenu", _box(ACCENT_DIM, 4, 8, 4))
	theme.set_color(&"font_color", &"PopupMenu", TEXT)
	theme.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	theme.set_font(&"font", &"PopupMenu", font(&"medium"))

	# Labels.
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0.35))
	theme.set_constant(&"shadow_offset_y", &"Label", 1)
	theme.set_constant(&"line_spacing", &"Label", 3)
	theme.set_font(&"normal_font", &"RichTextLabel", font(&"regular"))
	theme.set_font(&"bold_font", &"RichTextLabel", font(&"bold"))
	theme.set_font(&"italics_font", &"RichTextLabel", font(&"bold_italic"))
	theme.set_color(&"default_color", &"RichTextLabel", TEXT)

	# Buttons (Button, OptionButton, MenuButton share the look).
	for type: StringName in [&"Button", &"OptionButton", &"MenuButton"]:
		var normal: StyleBoxFlat = _box(BG_SOFT, RADIUS, 18, 10)
		normal.border_color = BORDER
		normal.set_border_width_all(1)
		var hover: StyleBoxFlat = _box(BG_HOVER, RADIUS, 18, 10)
		hover.border_color = Color(ACCENT, 0.6)
		hover.set_border_width_all(1)
		var pressed: StyleBoxFlat = _box(Color(ACCENT, 0.22), RADIUS, 18, 10)
		pressed.border_color = ACCENT
		pressed.set_border_width_all(1)
		var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), RADIUS, 18, 10)
		focus.border_color = Color(ACCENT, 0.85)
		focus.set_border_width_all(2)
		focus.draw_center = false
		var disabled: StyleBoxFlat = _box(Color(0.06, 0.065, 0.075, 0.7), RADIUS, 18, 10)
		disabled.border_color = Color(1, 1, 1, 0.03)
		disabled.set_border_width_all(1)
		theme.set_stylebox(&"normal", type, normal)
		theme.set_stylebox(&"hover", type, hover)
		theme.set_stylebox(&"pressed", type, pressed)
		theme.set_stylebox(&"hover_pressed", type, pressed)
		theme.set_stylebox(&"focus", type, focus)
		theme.set_stylebox(&"disabled", type, disabled)
		theme.set_font(&"font", type, font(&"semibold"))
		theme.set_color(&"font_color", type, TEXT)
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, Color.WHITE)
		theme.set_color(&"font_hover_pressed_color", type, Color.WHITE)
		theme.set_color(&"font_focus_color", type, Color.WHITE)
		theme.set_color(&"font_disabled_color", type, Color(TEXT_DIM, 0.45))
		theme.set_constant(&"h_separation", type, 10)
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		var clear: StyleBoxEmpty = StyleBoxEmpty.new()
		clear.content_margin_top = 6
		clear.content_margin_bottom = 6
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			theme.set_stylebox(state, type, clear)
		theme.set_font(&"font", type, font(&"medium"))
		theme.set_color(&"font_color", type, TEXT)
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, TEXT)
		theme.set_color(&"font_hover_pressed_color", type, Color.WHITE)
		theme.set_constant(&"h_separation", type, 12)
	theme.set_icon(&"checked", &"CheckButton", _switch_icon(true))
	theme.set_icon(&"unchecked", &"CheckButton", _switch_icon(false))
	theme.set_icon(&"checked_disabled", &"CheckButton", _switch_icon(true, 0.4))
	theme.set_icon(&"unchecked_disabled", &"CheckButton", _switch_icon(false, 0.4))
	theme.set_icon(&"checked", &"CheckBox", _check_icon(true))
	theme.set_icon(&"unchecked", &"CheckBox", _check_icon(false))

	# Text input.
	var line: StyleBoxFlat = _box(Color(0.015, 0.018, 0.024, 0.9), RADIUS, 14, 10)
	line.border_color = BORDER_STRONG
	line.set_border_width_all(1)
	var line_focus: StyleBoxFlat = line.duplicate() as StyleBoxFlat
	line_focus.border_color = ACCENT
	line_focus.border_width_bottom = 2
	theme.set_stylebox(&"normal", &"LineEdit", line)
	theme.set_stylebox(&"focus", &"LineEdit", line_focus)
	theme.set_stylebox(&"read_only", &"LineEdit", line)
	theme.set_font(&"font", &"LineEdit", font(&"medium"))
	theme.set_color(&"font_color", &"LineEdit", TEXT)
	theme.set_color(&"font_placeholder_color", &"LineEdit", TEXT_FAINT)
	theme.set_color(&"caret_color", &"LineEdit", ACCENT)
	theme.set_color(&"selection_color", &"LineEdit", ACCENT_DIM)

	# Sliders and bars.
	var track: StyleBoxFlat = _box(Color(1, 1, 1, 0.1), 3, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled: StyleBoxFlat = _box(ACCENT, 3, 0, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", filled)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", filled)
	var grabber_texture: ImageTexture = _dot_texture(18, TEXT, 8.5)
	theme.set_icon(&"grabber", &"HSlider", grabber_texture)
	theme.set_icon(&"grabber_highlight", &"HSlider", _dot_texture(20, Color.WHITE, 9.5))
	theme.set_stylebox(&"background", &"ProgressBar", _box(Color(1, 1, 1, 0.08), 3, 0, 0))
	theme.set_stylebox(&"fill", &"ProgressBar", _box(ACCENT, 3, 0, 0))
	theme.set_color(&"font_color", &"ProgressBar", TEXT)

	# Tabs.
	var tab_selected: StyleBoxFlat = _box(Color(1, 1, 1, 0.04), 0, 22, 12)
	tab_selected.border_color = ACCENT
	tab_selected.border_width_bottom = 3
	var tab_idle: StyleBoxFlat = _box(Color(0, 0, 0, 0), 0, 22, 12)
	tab_idle.border_color = BORDER
	tab_idle.border_width_bottom = 1
	var tab_hover: StyleBoxFlat = tab_idle.duplicate() as StyleBoxFlat
	tab_hover.border_color = Color(ACCENT, 0.5)
	tab_hover.border_width_bottom = 3
	theme.set_stylebox(&"tab_selected", &"TabContainer", tab_selected)
	theme.set_stylebox(&"tab_unselected", &"TabContainer", tab_idle)
	theme.set_stylebox(&"tab_hovered", &"TabContainer", tab_hover)
	theme.set_stylebox(&"tab_focus", &"TabContainer", StyleBoxEmpty.new())
	theme.set_stylebox(&"panel", &"TabContainer", _box(Color(0, 0, 0, 0), 0, 0, 18))
	theme.set_stylebox(&"tabbar_background", &"TabContainer", StyleBoxEmpty.new())
	theme.set_font(&"font", &"TabContainer", font(&"bold"))
	theme.set_color(&"font_selected_color", &"TabContainer", Color.WHITE)
	theme.set_color(&"font_unselected_color", &"TabContainer", TEXT_DIM)
	theme.set_color(&"font_hovered_color", &"TabContainer", TEXT)
	theme.set_font_size(&"font_size", &"TabContainer", 16)

	# Lists and scroll bars.
	theme.set_stylebox(&"panel", &"ItemList", _box(Color(0.015, 0.018, 0.024, 0.75), RADIUS, 8, 8))
	theme.set_stylebox(&"selected", &"ItemList", _box(ACCENT_DIM, 4, 4, 2))
	theme.set_stylebox(&"selected_focus", &"ItemList", _box(ACCENT_DIM, 4, 4, 2))
	theme.set_stylebox(&"hovered", &"ItemList", _box(Color(1, 1, 1, 0.05), 4, 4, 2))
	theme.set_stylebox(&"focus", &"ItemList", StyleBoxEmpty.new())
	theme.set_color(&"font_color", &"ItemList", TEXT)
	theme.set_constant(&"v_separation", &"ItemList", 6)
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		var scroll: StyleBoxFlat = _box(Color(1, 1, 1, 0.03), 4, 0, 0)
		scroll.content_margin_left = 2
		scroll.content_margin_right = 2
		theme.set_stylebox(&"scroll", bar, scroll)
		theme.set_stylebox(&"grabber", bar, _box(Color(1, 1, 1, 0.2), 4, 3, 3))
		theme.set_stylebox(&"grabber_highlight", bar, _box(Color(1, 1, 1, 0.35), 4, 3, 3))
		theme.set_stylebox(&"grabber_pressed", bar, _box(ACCENT, 4, 3, 3))

	# Separators and tooltips.
	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = BORDER
	separator.thickness = 1
	theme.set_stylebox(&"separator", &"HSeparator", separator)
	var vertical: StyleBoxLine = separator.duplicate() as StyleBoxLine
	vertical.vertical = true
	theme.set_stylebox(&"separator", &"VSeparator", vertical)
	theme.set_constant(&"separation", &"HSeparator", 16)
	var tooltip: StyleBoxFlat = _box(Color(0.06, 0.065, 0.08, 0.98), RADIUS, 12, 8)
	tooltip.border_color = BORDER_STRONG
	tooltip.set_border_width_all(1)
	theme.set_stylebox(&"panel", &"TooltipPanel", tooltip)
	theme.set_color(&"font_color", &"TooltipLabel", TEXT)
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


static func _dot_texture(size: int, colour: Color, radius: float) -> ImageTexture:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre: float = (size - 1) * 0.5
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(x - centre, y - centre).length()
			image.set_pixel(x, y, Color(colour, clampf(radius - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## Pill-shaped toggle switch (Windows 11 style) for CheckButton.
static func _switch_icon(on: bool, alpha: float = 1.0) -> ImageTexture:
	var width: int = 44
	var height: int = 24
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var track: Color = ACCENT if on else Color(1, 1, 1, 0.0)
	var outline: Color = ACCENT if on else Color(1, 1, 1, 0.55)
	var knob: Color = Color.WHITE if on else Color(1, 1, 1, 0.75)
	var radius: float = height * 0.5 - 1.0
	var knob_x: float = width - height * 0.5 if on else height * 0.5
	for y: int in height:
		for x: int in width:
			var px: Vector2 = Vector2(x + 0.5, y + 0.5)
			var cx: float = clampf(px.x, height * 0.5, width - height * 0.5)
			var d: float = px.distance_to(Vector2(cx, height * 0.5))
			var inside: float = clampf(radius - d + 0.5, 0.0, 1.0)
			var ring: float = clampf(1.5 - absf(d - radius + 0.75), 0.0, 1.0)
			var colour: Color = Color(track, track.a * inside)
			colour = colour.blend(Color(outline, ring * outline.a))
			var kd: float = px.distance_to(Vector2(knob_x, height * 0.5))
			colour = colour.blend(Color(knob, clampf((radius - 4.0) - kd + 0.5, 0.0, 1.0)))
			image.set_pixel(x, y, Color(colour, colour.a * alpha))
	return ImageTexture.create_from_image(image)


static func _check_icon(on: bool) -> ImageTexture:
	var size: int = 22
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var px: Vector2 = Vector2(x + 0.5, y + 0.5)
			var q: Vector2 = (px - Vector2(size, size) * 0.5).abs() - Vector2(size * 0.5 - 4.0, size * 0.5 - 4.0)
			var d: float = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 3.0
			var colour: Color = Color(0, 0, 0, 0)
			if on:
				colour = Color(ACCENT, clampf(0.5 - d, 0.0, 1.0))
			else:
				colour = Color(1, 1, 1, clampf(1.0 - absf(d + 0.5), 0.0, 1.0) * 0.6)
			image.set_pixel(x, y, colour)
	if on:
		for i: int in 12:
			var t: float = i / 11.0
			var a: Vector2 = Vector2(6, 11).lerp(Vector2(9.5, 14.5), t) if t < 0.35 else Vector2(9.5, 14.5).lerp(Vector2(16, 7.5), (t - 0.35) / 0.65)
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					image.set_pixel(clampi(int(a.x) + ox, 0, size - 1), clampi(int(a.y) + oy, 0, size - 1), Color.WHITE)
	return ImageTexture.create_from_image(image)


## Section heading used by menus (small caps, accent).
static func heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.add_theme_color_override(&"font_color", ACCENT)
	label.add_theme_font_override(&"font", font(&"bold"))
	label.add_theme_font_size_override(&"font_size", 13)
	return label


## Large screen title.
static func title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override(&"font", font(&"black_italic"))
	label.add_theme_font_size_override(&"font_size", 40)
	return label
