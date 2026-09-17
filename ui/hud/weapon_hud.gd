## Owner HUD for firearms: dynamic crosshair sized from the live spread, hit marker, and an ammo panel
## (weapon name, magazine / reserve, reload progress, slot hints).
## Authority: LOCAL (owning player only)
class_name WeaponHud
extends Control

const ACCENT: Color = Color(0.92, 0.94, 0.96)
const DIM: Color = Color(0.62, 0.66, 0.7)
const WARN: Color = Color(0.95, 0.35, 0.3)
const KILL: Color = Color(0.95, 0.25, 0.2)

var holder: WeaponHolder

var _gap: float = 8.0
var _hit_time: float = 0.0
var _hit_kill: bool = false
var _reload_elapsed: float = 0.0
var _panel: PanelContainer
var _name_label: Label
var _mag_label: Label
var _reserve_label: Label
var _slots_label: Label
var _reload_bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	holder.hit_confirmed.connect(_on_hit)
	holder.fired.connect(func(_slot: int) -> void: _gap += 6.0)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.55)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 32)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	_panel.add_child(column)
	_name_label = _label(column, 15, DIM)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)
	_mag_label = _label(row, 40, ACCENT)
	_reserve_label = _label(row, 20, DIM)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_reload_bar = ProgressBar.new()
	_reload_bar.custom_minimum_size = Vector2(170, 4)
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = ACCENT
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	_reload_bar.add_theme_stylebox_override(&"fill", fill)
	_reload_bar.add_theme_stylebox_override(&"background", back)
	column.add_child(_reload_bar)
	_slots_label = _label(column, 12, DIM)


func _label(parent: Node, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var weapon: WeaponData = holder.get_active_weapon()
	_panel.visible = weapon != null
	if weapon != null:
		var slot: int = holder.active_slot
		var mag: int = holder.displayed_magazine(slot)
		_name_label.text = weapon.display_name.to_upper()
		_mag_label.text = str(mag)
		_mag_label.add_theme_color_override(&"font_color", WARN if mag <= weapon.magazine_size / 4 else ACCENT)
		_reserve_label.text = "/ %d" % holder.reserve(slot)
		var reloading: bool = holder.reloading_slot == slot
		_reload_elapsed = _reload_elapsed + delta if reloading else 0.0
		_reload_bar.visible = reloading
		_reload_bar.value = clampf(_reload_elapsed / maxf(weapon.reload_seconds, 0.01), 0.0, 1.0)
		var hints: PackedStringArray = PackedStringArray()
		if holder.has_weapon(WeaponData.Slot.PRIMARY):
			hints.append("[1] %s" % holder.weapon_data(WeaponData.Slot.PRIMARY).display_name)
		if holder.has_weapon(WeaponData.Slot.SIDEARM):
			hints.append("[2] %s" % holder.weapon_data(WeaponData.Slot.SIDEARM).display_name)
		_slots_label.text = "   ".join(hints)
	var target_gap: float = 4.0 + holder.current_spread() * 7.0
	_gap = lerpf(_gap, target_gap, clampf(12.0 * delta, 0.0, 1.0))
	_hit_time = maxf(_hit_time - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if holder == null or not is_instance_valid(holder):
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
		return  # a menu is open
	var center: Vector2 = size * 0.5
	var weapon: WeaponData = holder.get_active_weapon()
	var shadow: Color = Color(0, 0, 0, 0.5)
	if weapon == null or holder.aiming:
		draw_circle(center, 2.5, shadow)
		draw_circle(center, 1.6, ACCENT)
	else:
		var length: float = 9.0
		for axis: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a: Vector2 = center + axis * _gap
			var b: Vector2 = center + axis * (_gap + length)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 2.0)
			draw_line(a, b, ACCENT, 2.0)
	if _hit_time > 0.0:
		var alpha: float = clampf(_hit_time / 0.25, 0.0, 1.0)
		var color: Color = (KILL if _hit_kill else ACCENT)
		color.a = alpha
		for axis: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + axis * 7.0, center + axis * 15.0, color, 2.5)


func _on_hit(killed: bool, _headshot: bool) -> void:
	_hit_time = 0.35 if killed else 0.25
	_hit_kill = killed
