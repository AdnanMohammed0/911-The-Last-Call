## Lobby role card: class colour band and emblem, name, summary, stat bars (health, sanity, speed, sprint),
## weapon chips and the claim button. States: available / selected by you / taken by a teammate.
## Built in code; keeps the %SelectButton / %StatusBadge names the lobby and tests use.
class_name ClassCard
extends PanelContainer

signal class_selected(class_id: StringName)

const ICONS: Dictionary[StringName, StringName] = {&"tech": &"cpu", &"profiler": &"eye", &"breacher": &"door", &"medic": &"medkit"}
## Stat bar ranges: [label, min, max].
const STAT_RANGES: Array[Array] = [["HEALTH", 60.0, 150.0], ["SANITY", 60.0, 150.0], ["SPEED", 0.8, 1.2], ["SPRINT", 4.0, 10.0]]

@export var class_id: StringName = &""

var _data: ClassData = null
var _is_selected: bool = false
var _is_occupied: bool = false
var _occupied_by_name: String = ""
var _hovered: bool = false

var _band: Panel
var _emblem: IconView
var _title_label: Label
var _role_label: Label
var _summary_label: Label
var _stats: VBoxContainer
var _weapons: HFlowContainer
var _select_button: KitButton
var _status_badge: Label
var _check: IconView


func _ready() -> void:
	_build()
	mouse_entered.connect(func() -> void:
		_hovered = true
		refresh_state())
	mouse_exited.connect(func() -> void:
		_hovered = false
		refresh_state())
	if class_id != &"":
		setup_class(class_id)
	else:
		refresh_state()


func _build() -> void:
	custom_minimum_size = Vector2(250, 470)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	add_child(column)
	# Colour band with the emblem.
	var header: Control = Control.new()
	header.custom_minimum_size = Vector2(0, 112)
	header.clip_contents = true
	column.add_child(header)
	_band = Panel.new()
	_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_band)
	var fade: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.035, 0.04, 0.05, 1.0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	fade.texture = texture
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(fade)
	_emblem = IconView.make(&"badge", 56, Color(1, 1, 1, 0.92))
	_emblem.stroke = 1.6
	_emblem.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_emblem.position -= Vector2(28, 36)
	header.add_child(_emblem)
	_check = IconView.make(&"check", 22, Color.WHITE)
	_check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_check.position += Vector2(-34, 12)
	_check.visible = false
	header.add_child(_check)

	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.margin(body, 18, 0, 18, 16))
	(body.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_badge = UiKit.caps("[ AVAILABLE ]", 11, GameTheme.TEXT_DIM, &"bold", 2)
	_status_badge.name = "StatusBadge"
	body.add_child(_status_badge)
	_title_label = UiKit.label("ROLE", 28, GameTheme.TEXT, &"black_italic")
	body.add_child(_title_label)
	_role_label = UiKit.caps("", 11, GameTheme.TEXT_DIM, &"semibold", 1)
	body.add_child(_role_label)
	_summary_label = UiKit.paragraph("", 14)
	_summary_label.custom_minimum_size = Vector2(210, 58)
	body.add_child(_summary_label)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override(&"separation", 5)
	body.add_child(_stats)
	_weapons = HFlowContainer.new()
	_weapons.add_theme_constant_override(&"h_separation", 5)
	_weapons.add_theme_constant_override(&"v_separation", 5)
	body.add_child(_weapons)
	body.add_child(UiKit.expand(UiKit.spacer(4), false, true))
	_select_button = KitButton.make("CHOOSE ROLE", &"check", KitButton.Variant.DEFAULT, _on_select_pressed)
	_select_button.name = "SelectButton"
	body.add_child(_select_button)
	for node: Control in [_status_badge, _select_button]:
		node.owner = self
		node.unique_name_in_owner = true


func setup_class(id: StringName) -> void:
	class_id = id
	_data = ClassCatalog.get_data(id)
	if _data == null or _title_label == null:
		return
	_title_label.text = _data.display_name.to_upper()
	_summary_label.text = _data.summary
	var band: StyleBoxFlat = UiKit.style(_data.color.darkened(0.25), 0, 0, 0)
	band.corner_radius_top_left = 11
	band.corner_radius_top_right = 11
	_band.add_theme_stylebox_override(&"panel", band)
	_emblem.icon = ICONS.get(id, &"badge")
	_role_label.text = "%d CARRY SLOTS  ·  AIM %.0f%%" % [_data.carry_slots, _data.aim_stability * 100.0]
	for child: Node in _stats.get_children():
		child.queue_free()
	var values: Array[float] = [_data.max_health, _data.max_sanity, _data.move_speed_multiplier, _data.sprint_duration]
	for i: int in STAT_RANGES.size():
		var spec: Array = STAT_RANGES[i]
		var low: float = spec[1]
		var high: float = spec[2]
		var stat_name: String = spec[0]
		_stats.add_child(_stat_row(stat_name, values[i], clampf((values[i] - low) / (high - low), 0.08, 1.0)))
	for child: Node in _weapons.get_children():
		child.queue_free()
	for weapon: String in _data.weapon_access:
		var data: WeaponData = WeaponCatalog.get_data(StringName(weapon))
		_weapons.add_child(UiKit.pill(data.display_name if data != null else weapon.replace("_", " ").capitalize(), GameTheme.TEXT_DIM, false, 10))
	refresh_state()


func _stat_row(stat_name: String, value: float, ratio: float) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var name_label: Label = UiKit.caps(stat_name, 10, GameTheme.TEXT_DIM, &"bold", 1)
	name_label.custom_minimum_size = Vector2(58, 0)
	row.add_child(name_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = ratio
	bar.custom_minimum_size = Vector2(0, 5)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override(&"fill", UiKit.style(_data.color.lightened(0.1), 3, 0, 0))
	bar.add_theme_stylebox_override(&"background", UiKit.style(Color(1, 1, 1, 0.08), 3, 0, 0))
	row.add_child(bar)
	var number: String = ("%.2f×" % value) if value < 5.0 and stat_name == "SPEED" else ("%.0fs" % value if stat_name == "SPRINT" else str(roundi(value)))
	var value_label: Label = UiKit.label(number, 12, GameTheme.TEXT, &"semibold")
	value_label.custom_minimum_size = Vector2(38, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row


func set_card_state(selected_by_me: bool, occupied: bool, occupant_name: String = "") -> void:
	_is_selected = selected_by_me
	_is_occupied = occupied
	_occupied_by_name = occupant_name
	refresh_state()


func refresh_state() -> void:
	if not is_inside_tree() or _select_button == null:
		return
	var colour: Color = _data.color if _data != null else GameTheme.ACCENT
	var border: Color = Color(1, 1, 1, 0.08)
	var tint: Color = Color(0.035, 0.04, 0.05, 0.9)
	if _is_selected:
		_select_button.disabled = true
		_select_button.text = "CLAIMED · YOU"
		_status_badge.text = "[ SELECTED ]"
		_status_badge.add_theme_color_override(&"font_color", colour.lightened(0.3))
		border = colour
		tint = Color(colour.darkened(0.82), 0.95)
		modulate = Color.WHITE
	elif _is_occupied:
		_select_button.disabled = true
		_select_button.text = "TAKEN"
		_status_badge.text = "[ %s ]" % _occupied_by_name.to_upper()
		_status_badge.add_theme_color_override(&"font_color", GameTheme.DANGER)
		modulate = Color(0.72, 0.72, 0.76, 0.85)
	else:
		_select_button.disabled = false
		_select_button.text = "CHOOSE ROLE"
		_status_badge.text = "[ AVAILABLE ]"
		_status_badge.add_theme_color_override(&"font_color", GameTheme.TEXT_DIM)
		if _hovered:
			border = Color(colour, 0.7)
		modulate = Color.WHITE
	_check.visible = _is_selected
	var box: StyleBoxFlat = UiKit.style(tint, 12, 0, 0, border, 2 if _is_selected else 1)
	box.shadow_color = Color(colour, 0.35) if _is_selected else Color(0, 0, 0, 0.35)
	box.shadow_size = 22 if _is_selected else 14
	add_theme_stylebox_override(&"panel", box)
	_select_button.accent = colour
	_select_button.variant = KitButton.Variant.PRIMARY if not _is_selected and not _is_occupied and _hovered else KitButton.Variant.DEFAULT
	_select_button.apply_variant()


func _on_select_pressed() -> void:
	class_selected.emit(class_id)
