## Objective tracker (top-left) and centred announcement banner driven by MissionDirector.
## Authority: LOCAL
class_name ObjectiveHud
extends Control

const ACCENT: Color = Color(0.95, 0.72, 0.25)
const TEXT: Color = Color(0.92, 0.94, 0.96)
const BANNER_SECONDS: float = 4.5

var _tracker: PanelContainer
var _tracker_title: Label
var _tracker_text: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_subtitle: Label
var _banner_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	MissionDirector.objective_changed.connect(func(_text: String) -> void: _refresh())
	MissionDirector.announcement.connect(_show_banner)
	_refresh()


func _build() -> void:
	_tracker = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.55)
	style.border_color = ACCENT
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_tracker.add_theme_stylebox_override(&"panel", style)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.position = Vector2(32, 32)
	_tracker.custom_minimum_size = Vector2(320, 0)
	add_child(_tracker)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	_tracker.add_child(column)
	_tracker_title = _label(column, 13, ACCENT)
	_tracker_text = _label(column, 17, TEXT)
	_tracker_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker_text.custom_minimum_size = Vector2(300, 0)

	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override(&"separation", 6)
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 150
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_title = _label(_banner, 40, ACCENT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _label(_banner, 18, TEXT)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0


func _label(parent: Node, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _refresh() -> void:
	var text: String = MissionDirector.objective_text
	_tracker.visible = text != ""
	if text == "":
		return
	var title: String = "RESPONSE" if MissionDirector.state == MissionDirector.State.RESPONSE else MissionDirector.mission_name().to_upper()
	_tracker_title.text = title
	if MissionDirector.state == MissionDirector.State.DEPLOYED and MissionDirector.hostiles_total > 0:
		text += "\nSuspects remaining: %d / %d" % [MissionDirector.hostiles_left, MissionDirector.hostiles_total]
	_tracker_text.text = text


func _show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_left = BANNER_SECONDS
	_refresh()


func _process(delta: float) -> void:
	if _banner_left <= 0.0:
		return
	_banner_left -= delta
	var fade_in: float = clampf((BANNER_SECONDS - _banner_left) / 0.3, 0.0, 1.0)
	var fade_out: float = clampf(_banner_left / 0.6, 0.0, 1.0)
	_banner.modulate.a = minf(fade_in, fade_out)
