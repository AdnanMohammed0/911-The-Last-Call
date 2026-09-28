## Owner HUD for firearms: dynamic crosshair sized from the live spread (dot while aiming), hit / kill
## markers, and the bottom-right weapon block — rendered gun silhouette, name, big magazine count with a
## row of rounds, reserve, reload ring, and the slot keys.
## Authority: LOCAL (owning player only)
class_name WeaponHud
extends Control

const ACCENT: Color = Color(0.95, 0.96, 0.97)
const DIM: Color = Color(0.62, 0.66, 0.7)
const WARN: Color = Color(0.96, 0.3, 0.26)
const KILL: Color = Color(0.96, 0.22, 0.2)

var holder: WeaponHolder

var _gap: float = 8.0
var _hit_time: float = 0.0
var _hit_kill: bool = false
var _hit_head: bool = false
var _reload_elapsed: float = 0.0
var _block: VBoxContainer
var _picture: TextureRect
var _picture_id: StringName = &""
var _name_label: Label
var _mag_label: Label
var _reserve_label: Label
var _rounds: RoundsStrip
var _slots: HBoxContainer
var _slots_key: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_block()
	holder.hit_confirmed.connect(_on_hit)
	holder.fired.connect(func(_slot: int) -> void: _gap += 6.0)


func _build_block() -> void:
	_block = VBoxContainer.new()
	_block.add_theme_constant_override(&"separation", 2)
	_block.alignment = BoxContainer.ALIGNMENT_END
	_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_block)
	_block.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	_block.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_block.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_picture = TextureRect.new()
	_picture.custom_minimum_size = Vector2(210, 70)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_END
	_picture.modulate = Color(1, 1, 1, 0.92)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(_picture)
	_name_label = UiKit.caps("", 12, DIM, &"bold", 2)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shadow(_name_label)
	_block.add_child(_name_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(row)
	_mag_label = UiKit.label("0", 58, ACCENT, &"black_italic")
	_shadow(_mag_label)
	row.add_child(_mag_label)
	_reserve_label = UiKit.label("/ 0", 22, DIM, &"bold")
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	_reserve_label.add_theme_constant_override(&"line_spacing", 0)
	_shadow(_reserve_label)
	row.add_child(UiKit.margin(_reserve_label, 0, 0, 0, 12))
	_rounds = RoundsStrip.new()
	_rounds.custom_minimum_size = Vector2(230, 12)
	_rounds.size_flags_horizontal = Control.SIZE_SHRINK_END
	_rounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(_rounds)
	_block.add_child(UiKit.spacer(8))
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_END
	_slots.add_theme_constant_override(&"separation", 14)
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_block.add_child(_slots)


func _shadow(label: Label) -> void:
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override(&"shadow_offset_y", 1)


func _process(delta: float) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var weapon: WeaponData = holder.get_active_weapon()
	_block.visible = weapon != null
	if weapon != null:
		var slot: int = holder.active_slot
		var mag: int = holder.displayed_magazine(slot)
		_name_label.text = weapon.display_name.to_upper()
		_mag_label.text = str(mag)
		_mag_label.add_theme_color_override(&"font_color", WARN if mag <= weapon.magazine_size / 4 else ACCENT)
		_reserve_label.text = "/ %d" % holder.reserve(slot)
		var reloading: bool = holder.reloading_slot == slot
		_reload_elapsed = _reload_elapsed + delta if reloading else 0.0
		_rounds.capacity = weapon.magazine_size
		_rounds.loaded = mag
		_rounds.reload = clampf(_reload_elapsed / maxf(weapon.reload_seconds, 0.01), 0.0, 1.0) if reloading else -1.0
		_rounds.queue_redraw()
		var model_id: StringName = weapon.get_model_id()
		if model_id != _picture_id:
			_picture_id = model_id
			_picture.texture = IconStudio.weapon(get_tree(), model_id, func(texture: Texture2D) -> void:
				if _picture_id == model_id:
					_picture.texture = texture)
		_refresh_slots()
	var target_gap: float = 4.0 + holder.current_spread() * 7.0
	_gap = lerpf(_gap, target_gap, clampf(12.0 * delta, 0.0, 1.0))
	_hit_time = maxf(_hit_time - delta, 0.0)
	queue_redraw()


func _refresh_slots() -> void:
	var key: String = "%s|%s|%d" % [holder.weapon_id(WeaponData.Slot.PRIMARY), holder.weapon_id(WeaponData.Slot.SIDEARM), holder.active_slot]
	if key == _slots_key:
		return
	_slots_key = key
	for child: Node in _slots.get_children():
		child.queue_free()
	for slot: int in [WeaponData.Slot.PRIMARY, WeaponData.Slot.SIDEARM]:
		if not holder.has_weapon(slot):
			continue
		var active: bool = holder.active_slot == slot
		var chip: HBoxContainer = HBoxContainer.new()
		chip.add_theme_constant_override(&"separation", 6)
		chip.modulate.a = 1.0 if active else 0.5
		chip.add_child(UiKit.key_cap("1" if slot == WeaponData.Slot.PRIMARY else "2", 11))
		var label: Label = UiKit.caps(holder.weapon_data(slot).display_name, 11, ACCENT if active else DIM, &"bold", 1)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(label)
		_slots.add_child(chip)
	var drop: HBoxContainer = HBoxContainer.new()
	drop.add_theme_constant_override(&"separation", 6)
	drop.modulate.a = 0.5
	drop.add_child(UiKit.key_cap(GameSettings.binding_text(&"drop_weapon"), 11))
	var drop_label: Label = UiKit.caps("Drop", 11, DIM, &"bold", 1)
	drop_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drop.add_child(drop_label)
	_slots.add_child(drop)


func _draw() -> void:
	if holder == null or not is_instance_valid(holder):
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
		return  # a menu is open
	var center: Vector2 = (size * 0.5).round()
	var weapon: WeaponData = holder.get_active_weapon()
	var shadow: Color = Color(0, 0, 0, 0.55)
	if weapon == null or holder.aiming:
		draw_circle(center, 3.0, shadow)
		draw_circle(center, 1.8, ACCENT)
	else:
		var length: float = 10.0
		for axis: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a: Vector2 = center + axis * _gap
			var b: Vector2 = center + axis * (_gap + length)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 3.0)
			draw_line(a, b, ACCENT, 2.0)
		draw_circle(center, 1.3, Color(ACCENT, 0.8))
	if _hit_time > 0.0:
		var alpha: float = clampf(_hit_time / 0.25, 0.0, 1.0)
		var colour: Color = KILL if _hit_kill else (Color(1.0, 0.8, 0.3) if _hit_head else ACCENT)
		colour.a = alpha
		var reach: float = 17.0 if _hit_kill else 14.0
		for axis: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(center + axis * 7.0 + Vector2(1, 1), center + axis * reach + Vector2(1, 1), Color(0, 0, 0, alpha * 0.5), 3.5)
			draw_line(center + axis * 7.0, center + axis * reach, colour, 2.5)


func _on_hit(killed: bool, headshot: bool) -> void:
	_hit_time = 0.4 if killed else 0.25
	_hit_kill = killed
	_hit_head = headshot


## A row of round pips for the magazine (compressed for big magazines), with the reload fill.
class RoundsStrip:
	extends Control

	var capacity: int = 30
	var loaded: int = 30
	var reload: float = -1.0

	func _draw() -> void:
		var count: int = mini(capacity, 30)
		if count <= 0:
			return
		var per_pip: float = float(capacity) / count
		var gap: float = 2.0
		var pip_w: float = minf((size.x - gap * (count - 1)) / count, 7.0)
		var total: float = pip_w * count + gap * (count - 1)
		var start: float = size.x - total
		for i: int in count:
			var index: int = count - 1 - i
			var full: bool = loaded >= ceili((index + 1) * per_pip - 0.001)
			var x: float = start + i * (pip_w + gap)
			var colour: Color = Color(0.95, 0.96, 0.97, 0.95) if full else Color(1, 1, 1, 0.14)
			if reload >= 0.0:
				colour = Color(1.0, 0.8, 0.35, 0.95) if float(i) / count < reload else Color(1, 1, 1, 0.14)
			draw_rect(Rect2(x, 0, pip_w, size.y), colour)
