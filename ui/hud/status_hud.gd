## Bottom-left status block for the local player: name + class, health, vest armor and stamina bars with
## numeric readouts, plus a red damage vignette that pulses when hit and stays while health is low.
## Authority: LOCAL
class_name StatusHud
extends Control

const HEALTH_COLOR: Color = Color(0.86, 0.25, 0.22)
const HEALTH_LOW: Color = Color(1.0, 0.12, 0.1)
const ARMOR_COLOR: Color = Color(0.35, 0.62, 0.95)
const STAMINA_COLOR: Color = Color(0.85, 0.85, 0.8)
const BAR_WIDTH: float = 300.0

@export var player: Player

var _name_label: Label
var _health_bar: ProgressBar
var _health_value: Label
var _armor_row: HBoxContainer
var _armor_bar: ProgressBar
var _armor_value: Label
var _stamina_bar: ProgressBar
var _vignette: ColorRect
var _hit_flash: float = 0.0
var _shown_health: float = -1.0
var _last_hp: float = -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_vignette()
	_build_panel()


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
	float edge = smoothstep(0.28, 0.75, length(centered * vec2(1.25, 1.0)));
	COLOR = vec4(0.55, 0.0, 0.0, edge * intensity);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	add_child(_vignette)


func _build_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.55)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 32)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	panel.add_child(column)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override(&"font_size", 14)
	_name_label.add_theme_color_override(&"font_color", GameTheme.TEXT_DIM)
	column.add_child(_name_label)
	var health: Array = _bar_row(column, HEALTH_COLOR, 12.0, 22)
	_health_bar = health[1]
	_health_value = health[2]
	var armor: Array = _bar_row(column, ARMOR_COLOR, 6.0, 15)
	_armor_row = armor[0]
	_armor_bar = armor[1]
	_armor_value = armor[2]
	_stamina_bar = _bar(STAMINA_COLOR, 3.0)
	_stamina_bar.modulate.a = 0.7
	column.add_child(_stamina_bar)


func _bar_row(parent: Container, color: Color, height: float, font_size: int) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	parent.add_child(row)
	var bar: ProgressBar = _bar(color, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(44, 0)
	value.add_theme_font_size_override(&"font_size", font_size)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [row, bar, value]


func _bar(color: Color, height: float) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	back.set_corner_radius_all(2)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", back)
	return bar


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var health: HealthComponent = player.get_health()
	var class_data: ClassData = ClassCatalog.get_data(player.class_id)
	_name_label.text = "%s  ·  %s" % [NetManager.get_player_name(player.peer_id).to_upper(), class_data.display_name.to_upper() if class_data != null else ""]
	if _shown_health < 0.0:
		_shown_health = health.hp
		_last_hp = health.hp
	if health.hp < _last_hp - 0.5:
		_hit_flash = clampf(_hit_flash + (_last_hp - health.hp) / 40.0, 0.35, 0.85)
	_last_hp = health.hp
	_shown_health = lerpf(_shown_health, health.hp, clampf(10.0 * delta, 0.0, 1.0))
	_health_bar.max_value = health.max_hp
	_health_bar.value = _shown_health
	_health_value.text = str(ceili(health.hp))
	var ratio: float = health.hp / maxf(health.max_hp, 1.0)
	(_health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color = HEALTH_LOW if ratio <= 0.3 else HEALTH_COLOR
	_armor_row.visible = health.armor > 0.0
	_armor_bar.max_value = HealthComponent.MAX_ARMOR
	_armor_bar.value = health.armor
	_armor_value.text = str(ceili(health.armor))
	_stamina_bar.max_value = player.get_max_stamina()
	_stamina_bar.value = player.stamina
	_stamina_bar.visible = player.stamina < player.get_max_stamina() - 0.05

	_hit_flash = maxf(_hit_flash - delta * 1.8, 0.0)
	var low: float = clampf((0.35 - ratio) / 0.35, 0.0, 1.0) * (0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.006))
	var shader_material: ShaderMaterial = _vignette.material as ShaderMaterial
	shader_material.set_shader_parameter(&"intensity", clampf(maxf(_hit_flash, low), 0.0, 0.9))

