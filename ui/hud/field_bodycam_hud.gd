## Lightweight local field camera frame. Sanity distortion is an overlay, not a screen copy.
class_name FieldBodycamHud
extends Control

const FRAME: Color = Color(0.86, 0.92, 0.92, 0.65)
const WARNING: Color = Color(1.0, 0.32, 0.28)

@export var player: Player

var _sanity_overlay: ColorRect
var _rec: Label
var _clock: Label
var _site: Label
var _last_second: int = -1
var _last_intensity: float = -1.0
var _started_msec: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_overlay()
	_build_labels()
	visibility_changed.connect(queue_redraw)
	_update_visibility()


func _build_overlay() -> void:
	_sanity_overlay = ColorRect.new()
	_sanity_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sanity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float edge = smoothstep(0.24, 0.72, length(p * vec2(1.25, 1.0)));
	float grain = fract(sin(dot(floor(UV * vec2(420.0, 240.0)) + floor(TIME * 14.0), vec2(12.9898, 78.233))) * 43758.5453);
	float pulse = 0.86 + 0.14 * sin(TIME * 2.1);
	COLOR = vec4(vec3(0.10, 0.025, 0.12) + grain * 0.035, edge * intensity * pulse);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_sanity_overlay.material = material
	add_child(_sanity_overlay)


func _build_labels() -> void:
	_rec = UiKit.caps("● REC  //  S4 BODYCAM", 13, WARNING, &"bold", 2)
	_rec.position = Vector2(36, 25)
	add_child(_rec)
	_clock = UiKit.caps("00:00:00", 13, FRAME, &"bold", 2)
	_clock.position = Vector2(36, 49)
	add_child(_clock)
	_site = UiKit.caps("", 12, FRAME, &"bold", 1)
	_site.position = Vector2(36, 72)
	add_child(_site)


func _process(_delta: float) -> void:
	_update_visibility()
	if not visible:
		return
	var elapsed: int = int((Time.get_ticks_msec() - _started_msec) / 1000)
	if elapsed != _last_second:
		_last_second = elapsed
		_clock.text = "%02d:%02d:%02d" % [int(elapsed / 3600), int(elapsed / 60) % 60, elapsed % 60]
		_rec.modulate.a = 1.0 if elapsed % 2 == 0 else 0.55
		_site.text = MissionDirector.mission_name().to_upper()
	if player == null or not is_instance_valid(player):
		return
	var strength: float = sanity_intensity(player.sanity)
	_sanity_overlay.visible = strength > 0.005
	if absf(strength - _last_intensity) > 0.005:
		_last_intensity = strength
		(_sanity_overlay.material as ShaderMaterial).set_shader_parameter(&"intensity", strength)


func _update_visibility() -> void:
	var should_show: bool = MissionDirector.is_in_mission()
	if visible != should_show:
		if should_show:
			_started_msec = Time.get_ticks_msec()
			_last_second = -1
		visible = should_show
		queue_redraw()


static func sanity_intensity(sanity: float) -> float:
	return clampf((70.0 - sanity) / 70.0, 0.0, 0.68)


func _draw() -> void:
	if not visible:
		return
	var inset: float = 24.0
	var length: float = 18.0
	var corners: Array[Vector2] = [Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)]
	for corner: Vector2 in corners:
		var sx: float = 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy: float = 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(sx * length, 0), FRAME, 1.0)
		draw_line(corner, corner + Vector2(0, sy * length), FRAME, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
