## Factories for the game's UI building blocks on top of GameTheme: typed labels (Barlow weights, tracked
## caps), acrylic glass panels, pills / key caps, separators, and small tween helpers for entrances.
## Every screen builds its widgets through here so the look stays consistent.
## Authority: LOCAL
class_name UiKit
extends RefCounted

const ACRYLIC: Shader = preload("res://ui/shaders/acrylic.gdshader")

static var _tracked: Dictionary[String, FontVariation] = {}


## Label in a Barlow weight.
static func label(text: String, font_size: int = 18, colour: Color = GameTheme.TEXT, weight: StringName = &"medium") -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_override(&"font", GameTheme.font(weight))
	node.add_theme_font_size_override(&"font_size", font_size)
	node.add_theme_color_override(&"font_color", colour)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Upper-case label with letter spacing (section headings, captions, HUD titles).
static func caps(text: String, font_size: int = 13, colour: Color = GameTheme.TEXT_DIM, weight: StringName = &"bold", spacing: int = 2) -> Label:
	var node: Label = label(text.to_upper(), font_size, colour, weight)
	node.add_theme_font_override(&"font", tracked(weight, spacing))
	return node


## Barlow weight with extra glyph spacing (cached).
static func tracked(weight: StringName, spacing: int) -> FontVariation:
	var key: String = "%s_%d" % [weight, spacing]
	if not _tracked.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = GameTheme.font(weight)
		variation.spacing_glyph = spacing
		_tracked[key] = variation
	return _tracked[key]


## Wrapping body text.
static func paragraph(text: String, font_size: int = 16, colour: Color = GameTheme.TEXT_DIM) -> Label:
	var node: Label = label(text, font_size, colour, &"regular")
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func rich(font_size: int = 16) -> RichTextLabel:
	var node: RichTextLabel = RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.add_theme_font_size_override(&"normal_font_size", font_size)
	node.add_theme_font_size_override(&"bold_font_size", font_size)
	node.add_theme_font_size_override(&"italics_font_size", font_size)
	return node


static func style(colour: Color, radius: int = GameTheme.RADIUS, pad_x: int = 16, pad_y: int = 12,
		border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box


## Plain translucent panel (no blur) — cheap, for HUD elements.
static func panel(colour: Color = Color(0.03, 0.035, 0.045, 0.62), radius: int = 8, pad_x: int = 18, pad_y: int = 14) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	node.add_theme_stylebox_override(&"panel", style(colour, radius, pad_x, pad_y))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Frosted-glass panel: blurs whatever is behind it (menus over the 3D scene, Station OS windows).
static func glass(tint: Color = Color(0.05, 0.055, 0.07), radius: int = 12, pad_x: int = 24, pad_y: int = 20,
		tint_amount: float = 0.62, blur: float = 3.2, border: Color = Color(1, 1, 1, 0.09)) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	apply_glass(node, tint, radius, pad_x, pad_y, tint_amount, blur, border)
	return node


static func apply_glass(node: Control, tint: Color, radius: int, pad_x: int, pad_y: int, tint_amount: float = 0.62,
		blur: float = 3.2, border: Color = Color(1, 1, 1, 0.09)) -> void:
	var box: StyleBoxFlat = style(Color(tint, 1.0), radius, pad_x, pad_y, border, 1 if border.a > 0.0 else 0)
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 24
	box.shadow_offset = Vector2(0, 8)
	node.add_theme_stylebox_override(&"panel", box)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ACRYLIC
	material.set_shader_parameter(&"tint_amount", tint_amount)
	material.set_shader_parameter(&"blur_lod", blur)
	node.material = material


## Keyboard key cap ("F", "ESC", "1").
static func key_cap(key: String, font_size: int = 14) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = style(Color(0.94, 0.95, 0.96, 0.95), 5, 8, 2)
	box.border_color = Color(0, 0, 0, 0.35)
	box.border_width_bottom = 3
	cap.add_theme_stylebox_override(&"panel", box)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text: Label = label(key.to_upper(), font_size, Color(0.05, 0.06, 0.07), &"extrabold")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(font_size, 0)
	cap.add_child(text)
	return cap


## Small rounded tag ("READY", "HOST", "LOCKED").
static func pill(text: String, colour: Color, filled: bool = false, font_size: int = 12) -> PanelContainer:
	var tag: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = style(Color(colour, 0.9) if filled else Color(colour, 0.14), 20, 10, 3, Color(colour, 0.55), 0 if filled else 1)
	tag.add_theme_stylebox_override(&"panel", box)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_colour: Color = Color(0.04, 0.05, 0.06) if filled else colour.lightened(0.15)
	tag.add_child(caps(text, font_size, text_colour, &"bold", 1))
	return tag


## Horizontal row with an icon and a label.
static func icon_row(icon: StringName, text: String, font_size: int = 16, colour: Color = GameTheme.TEXT, icon_colour: Color = GameTheme.TEXT_DIM) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: IconView = IconView.make(icon, font_size + 4.0, icon_colour)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(view)
	row.add_child(label(text, font_size, colour))
	return row


static func separator(colour: Color = GameTheme.BORDER) -> HSeparator:
	var line: HSeparator = HSeparator.new()
	var box: StyleBoxLine = StyleBoxLine.new()
	box.color = colour
	box.thickness = 1
	line.add_theme_stylebox_override(&"separator", box)
	return line


static func spacer(height: float = 8.0, width: float = 0.0) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(width, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


static func expand(control: Control, horizontal: bool = true, vertical: bool = false) -> Control:
	if horizontal:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control


static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box: MarginContainer = MarginContainer.new()
	box.add_theme_constant_override(&"margin_left", left)
	box.add_theme_constant_override(&"margin_top", top)
	box.add_theme_constant_override(&"margin_right", right)
	box.add_theme_constant_override(&"margin_bottom", bottom)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(child)
	return box


## Fade + slide a control in (after it has been laid out).
static func reveal(control: Control, delay: float = 0.0, offset: Vector2 = Vector2(0, 14), duration: float = 0.35) -> void:
	if not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		var target: Vector2 = control.position
		control.position = target + offset
		var move: Tween = control.create_tween().set_parallel()
		move.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		move.tween_property(control, "position", target, duration)
		move.tween_property(control, "modulate:a", 1.0, duration))


## Reveal every visible child in sequence.
static func stagger(container: Control, step: float = 0.05, start: float = 0.0) -> void:
	var index: int = 0
	for child: Node in container.get_children():
		var control: Control = child as Control
		if control != null and control.visible:
			reveal(control, start + step * index, Vector2(-18, 0))
			index += 1


static func money(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out
