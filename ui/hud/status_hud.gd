## Bottom-left vitals for the local player: rank / callsign / role line with the class colour, XP sliver,
## segmented health bar with a big readout, armour plates, stamina line, the shout caption, and the red
## damage vignette that pulses when hit and stays while health is low.
## Authority: LOCAL
class_name StatusHud
extends Control

const HEALTH_COLOR: Color = Color(0.94, 0.95, 0.96)
const HEALTH_LOW: Color = Color(0.96, 0.22, 0.2)
const ARMOR_COLOR: Color = Color(0.36, 0.62, 1.0)
const STAMINA_COLOR: Color = Color(1.0, 0.8, 0.35)
const SEGMENTS: int = 10
const BAR_WIDTH: float = 300.0

@export var player: Player

var _name_label: Label
var _role_dot: ColorRect
var _xp_bar: ProgressBar
var _health_value: Label
var _health_icon: IconView
var _bars: VitalBars
var _vignette: ColorRect
var _hit_flash: float = 0.0
var _shown_health: float = -1.0
var _last_hp: float = -1.0
var _shout_label: Label
var _shout_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vignette()
	_build_panel()
	_build_shout()


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = smoothstep(0.25, 0.78, length(centered * vec2(1.2, 1.0)));
	float veins = 0.85 + 0.15 * sin(atan(centered.y, centered.x) * 18.0 + TIME * 0.5);
	COLOR = vec4(0.5, 0.0, 0.0, edge * intensity * veins);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	add_child(_vignette)


func _build_panel() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 40)
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override(&"separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_row)
	_role_dot = ColorRect.new()
	_role_dot.custom_minimum_size = Vector2(4, 14)
	_role_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_role_dot)
	_name_label = UiKit.caps("", 12, GameTheme.TEXT_DIM, &"bold", 2)
	_shadow(_name_label)
	name_row.add_child(_name_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(BAR_WIDTH + 70, 2)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.add_theme_stylebox_override(&"fill", UiKit.style(Color(GameTheme.WARNING, 0.85), 1, 0, 0))
	_xp_bar.add_theme_stylebox_override(&"background", UiKit.style(Color(1, 1, 1, 0.08), 1, 0, 0))
	root.add_child(_xp_bar)
	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override(&"separation", 12)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(main)
	var readout: HBoxContainer = HBoxContainer.new()
	readout.add_theme_constant_override(&"separation", 6)
	readout.custom_minimum_size = Vector2(88, 0)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(readout)
	_health_icon = IconView.make(&"heart", 20, HEALTH_COLOR)
	_health_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health_icon.pivot_offset = Vector2(10, 10)
	readout.add_child(_health_icon)
	_health_value = UiKit.label("100", 44, HEALTH_COLOR, &"black_italic")
	_shadow(_health_value)
	readout.add_child(_health_value)
	_bars = VitalBars.new()
	_bars.custom_minimum_size = Vector2(BAR_WIDTH, 40)
	_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(_bars)


func _shadow(label: Label) -> void:
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override(&"shadow_offset_y", 1)


func _build_shout() -> void:
	_shout_label = UiKit.label("\"POLICE! HANDS UP! GET ON THE GROUND!\"", 26, Color(0.97, 0.97, 0.94), &"black_italic")
	_shout_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_shout_label.add_theme_constant_override(&"outline_size", 8)
	_shout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_shout_label)
	_shout_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_shout_label.offset_top = -190
	_shout_label.offset_bottom = -150
	_shout_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shout_label.modulate.a = 0.0
	if player != null:
		player.shouted.connect(func() -> void: _shout_left = 1.4)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var health: HealthComponent = player.get_health()
	var class_data: ClassData = ClassCatalog.get_data(player.class_id)
	_name_label.text = "%s  ·  %s  ·  %s" % [Career.rank_name(Career.rank()).to_upper(), NetManager.get_player_name(player.peer_id).to_upper(),
		class_data.display_name.to_upper() if class_data != null else "NO ROLE"]
	_role_dot.color = class_data.color if class_data != null else GameTheme.TEXT_DIM
	var bounds: Vector2i = Career.rank_bounds()
	_xp_bar.min_value = bounds.x
	_xp_bar.max_value = bounds.y if bounds.y > 0 else bounds.x + 1
	_xp_bar.value = Career.xp if bounds.y > 0 else _xp_bar.max_value
	_shout_left = maxf(_shout_left - delta, 0.0)
	_shout_label.modulate.a = clampf(_shout_left / 0.4, 0.0, 1.0)
	if _shown_health < 0.0:
		_shown_health = health.hp
		_last_hp = health.hp
	if health.hp < _last_hp - 0.5:
		_hit_flash = clampf(_hit_flash + (_last_hp - health.hp) / 40.0, 0.35, 0.85)
		_bars.damage_flash = 1.0
	_last_hp = health.hp
	_shown_health = lerpf(_shown_health, health.hp, clampf(10.0 * delta, 0.0, 1.0))
	var ratio: float = health.hp / maxf(health.max_hp, 1.0)
	var low: bool = ratio <= 0.3
	var colour: Color = HEALTH_LOW if low else HEALTH_COLOR
	_health_value.text = str(ceili(health.hp))
	_health_value.add_theme_color_override(&"font_color", colour)
	_health_icon.color = colour
	_health_icon.scale = Vector2.ONE * (1.0 + (0.12 * absf(sin(Time.get_ticks_msec() * 0.008)) if low else 0.0))
	_bars.health_ratio = _shown_health / maxf(health.max_hp, 1.0)
	_bars.armor_ratio = health.armor / HealthComponent.MAX_ARMOR
	_bars.stamina_ratio = player.stamina / maxf(player.get_max_stamina(), 0.01)
	_bars.health_colour = colour
	_bars.damage_flash = maxf(_bars.damage_flash - delta * 3.0, 0.0)
	_bars.queue_redraw()

	_hit_flash = maxf(_hit_flash - delta * 1.8, 0.0)
	var pulse: float = clampf((0.35 - ratio) / 0.35, 0.0, 1.0) * (0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.006))
	var shader_material: ShaderMaterial = _vignette.material as ShaderMaterial
	shader_material.set_shader_parameter(&"intensity", clampf(maxf(_hit_flash, pulse), 0.0, 0.9))


## Segmented health bar, armour plates underneath and a thin stamina line, drawn in one pass.
class VitalBars:
	extends Control

	var health_ratio: float = 1.0
	var armor_ratio: float = 0.0
	var stamina_ratio: float = 1.0
	var health_colour: Color = Color.WHITE
	var damage_flash: float = 0.0

	func _draw() -> void:
		var gap: float = 3.0
		var seg_w: float = (size.x - gap * (SEGMENTS - 1)) / SEGMENTS
		var shadow: Color = Color(0, 0, 0, 0.45)
		# Health segments (skewed parallelograms).
		for i: int in SEGMENTS:
			var x: float = i * (seg_w + gap)
			var fill: float = clampf(health_ratio * SEGMENTS - i, 0.0, 1.0)
			_skew_rect(Rect2(x + 1, 3, seg_w, 14), shadow)
			_skew_rect(Rect2(x, 2, seg_w, 14), Color(1, 1, 1, 0.1))
			if fill > 0.0:
				var colour: Color = health_colour.lerp(Color(1, 0.3, 0.25), damage_flash * 0.6)
				_skew_rect(Rect2(x, 2, seg_w * fill, 14), colour)
		# Armour plates (5).
		if armor_ratio > 0.0:
			var plate_w: float = (size.x * 0.6 - gap * 4) / 5.0
			for i: int in 5:
				var x: float = i * (plate_w + gap)
				var fill: float = clampf(armor_ratio * 5.0 - i, 0.0, 1.0)
				_skew_rect(Rect2(x, 21, plate_w, 7), Color(ARMOR_COLOR, 0.18))
				if fill > 0.0:
					_skew_rect(Rect2(x, 21, plate_w * fill, 7), ARMOR_COLOR)
			IconView.paint(self, &"shield", Rect2(size.x * 0.6 + 6, 17, 14, 14), ARMOR_COLOR, 2.0)
		# Stamina.
		if stamina_ratio < 0.995:
			draw_rect(Rect2(0, 33, size.x, 2), Color(1, 1, 1, 0.08))
			draw_rect(Rect2(0, 33, size.x * stamina_ratio, 2), STAMINA_COLOR.lerp(HEALTH_LOW, 1.0 - clampf(stamina_ratio * 3.0, 0.0, 1.0)))

	func _skew_rect(rect: Rect2, colour: Color) -> void:
		var skew: float = rect.size.y * 0.35
		var points: PackedVector2Array = PackedVector2Array([
			rect.position + Vector2(skew, 0), rect.position + Vector2(rect.size.x + skew, 0),
			rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(0, rect.size.y)])
		draw_colored_polygon(points, colour)
