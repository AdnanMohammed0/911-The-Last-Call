## Objective tracker (top-left) and centred announcement banner driven by MissionDirector.
## Authority: LOCAL
class_name ObjectiveHud
extends Control

const ACCENT: Color = Color(0.95, 0.72, 0.25)
const TEXT: Color = Color(0.92, 0.94, 0.96)
const BANNER_SECONDS: float = 6.0
const XP_GAIN: Color = Color(0.55, 0.9, 0.55)
const XP_LOSS: Color = Color(0.95, 0.4, 0.35)
const FEED_SECONDS: float = 3.5

var _tracker: PanelContainer
var _tracker_title: Label
var _tracker_text: Label
var _banner: PanelContainer
var _banner_title: Label
var _banner_subtitle: Label
var _banner_left: float = 0.0
var _feed: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	MissionDirector.objective_changed.connect(func(_text: String) -> void: _refresh())
	MissionDirector.announcement.connect(_show_banner)
	MissionDirector.shift_changed.connect(_refresh)
	Career.xp_gained.connect(_on_xp_gained)
	Career.promoted.connect(func(_rank: int, rank_title: String, unlocks: PackedStringArray) -> void:
		var unlocked: String = ("  ·  Unlocked: " + ", ".join(unlocks)) if not unlocks.is_empty() else ""
		_show_banner("PROMOTED — %s" % rank_title.to_upper(), "Keep answering calls to climb the ranks%s" % unlocked))
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

	_banner = PanelContainer.new()
	var backdrop: StyleBoxFlat = StyleBoxFlat.new()
	backdrop.bg_color = Color(0.02, 0.025, 0.03, 0.72)
	backdrop.border_color = ACCENT
	backdrop.border_width_top = 2
	backdrop.content_margin_left = 48
	backdrop.content_margin_right = 48
	backdrop.content_margin_top = 16
	backdrop.content_margin_bottom = 18
	_banner.add_theme_stylebox_override(&"panel", backdrop)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 140
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var banner_column: VBoxContainer = VBoxContainer.new()
	banner_column.add_theme_constant_override(&"separation", 4)
	_banner.add_child(banner_column)
	_banner_title = _label(banner_column, 36, ACCENT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _label(banner_column, 18, TEXT)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0

	_feed = VBoxContainer.new()
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.add_theme_constant_override(&"separation", 4)
	add_child(_feed)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_feed.offset_left = -360
	_feed.offset_right = -32
	_feed.offset_top = -60
	_feed.offset_bottom = 120
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN


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
	if text == "":
		# Between calls: the shift is the goal.
		_tracker.visible = true
		_tracker_title.text = "SHIFT %d" % MissionDirector.shift_number
		var total: String = str(MissionDirector.calls_total) if MissionDirector.calls_total > 0 else "?"
		_tracker_text.text = "Work the 911 line — answer calls at the CAD desks\nCalls handled %d / %s  ·  Public trust %d" % [
			MissionDirector.calls_handled, total, MissionDirector.public_trust]
		return
	_tracker.visible = true
	var title: String = "RESPONSE" if MissionDirector.state == MissionDirector.State.RESPONSE else MissionDirector.mission_name().to_upper()
	_tracker_title.text = title
	if MissionDirector.state == MissionDirector.State.DEPLOYED and MissionDirector.hostiles_total > 0:
		text += "\nSuspects remaining: %d / %d" % [MissionDirector.hostiles_left, MissionDirector.hostiles_total]
	if MissionDirector.is_in_mission():
		text += "\nWait at the police van to leave"
	_tracker_text.text = text


func _show_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_subtitle.text = subtitle
	_banner_left = BANNER_SECONDS
	_refresh()


func _on_xp_gained(amount: int, reason: String) -> void:
	var label: Label = _label(_feed, 17, XP_GAIN if amount >= 0 else XP_LOSS)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = "%+d XP  ·  %s" % [amount, reason]
	var tween: Tween = label.create_tween()
	tween.tween_interval(FEED_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))


func _process(delta: float) -> void:
	if _banner_left <= 0.0:
		return
	_banner_left -= delta
	var fade_in: float = clampf((BANNER_SECONDS - _banner_left) / 0.3, 0.0, 1.0)
	var fade_out: float = clampf(_banner_left / 0.6, 0.0, 1.0)
	_banner.modulate.a = minf(fade_in, fade_out)
