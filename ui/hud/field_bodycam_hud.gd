## Lightweight local field camera frame. Sanity distortion is an overlay, not a screen copy.
class_name FieldBodycamHud
extends Control

const FRAME: Color = Color(0.86, 0.92, 0.92, 0.65)
const WARNING: Color = Color(1.0, 0.32, 0.28)
const POST_SHADER: Shader = preload("res://ui/shaders/bodycam_post.gdshader")

@export var player: Player
@export_group("Bodycam Image")
@export var post_process_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var film_strength: float = 0.55
@export_range(0.0, 0.2, 0.005) var grain_strength: float = 0.035
@export_range(0.0, 0.2, 0.005) var scanline_strength: float = 0.05
@export_range(0.0, 4.0, 0.1) var aberration_px: float = 1.1

var _sanity_overlay: ColorRect
var _post_process: ColorRect
var _post_material: ShaderMaterial
var _frame: BodycamFrame
var _rec: Label
var _clock: Label
var _site: Label
var _timestamp: Label
var _last_second: int = -1
var _last_intensity: float = -1.0
var _started_msec: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_overlay()
	_build_frame()
	_build_labels()
	_update_visibility()


func _build_overlay() -> void:
	_post_process = ColorRect.new()
	_post_process.name = "BodycamPostProcess"
	_post_process.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_process.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_material = ShaderMaterial.new()
	_post_material.shader = POST_SHADER
	_post_process.material = _post_material
	add_child(_post_process)
	_apply_post_settings()
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


func _build_frame() -> void:
	_frame = BodycamFrame.new()
	_frame.name = "FrameCorners"
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)


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
	_timestamp = UiKit.caps("", 15, FRAME, &"bold", 1)
	_timestamp.anchor_left = 0.5
	_timestamp.anchor_right = 0.5
	_timestamp.offset_left = -170.0
	_timestamp.offset_right = 170.0
	_timestamp.offset_top = 25.0
	_timestamp.offset_bottom = 49.0
	_timestamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_timestamp)


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
		_timestamp.text = Time.get_datetime_string_from_system(false, true).replace("T", "  ")
	if player == null or not is_instance_valid(player):
		return
	var strength: float = 0.0 if GameSettings.reduced_horror_effects else sanity_intensity(player.sanity)
	_sanity_overlay.visible = strength > 0.005
	if absf(strength - _last_intensity) > 0.005:
		_last_intensity = strength
		(_sanity_overlay.material as ShaderMaterial).set_shader_parameter(&"intensity", strength)
		_post_material.set_shader_parameter(&"sanity_strength", strength)
	_post_process.visible = post_process_enabled and not GameSettings.reduced_horror_effects


func _update_visibility() -> void:
	var should_show: bool = MissionDirector.is_in_mission()
	if visible != should_show:
		if should_show:
			_started_msec = Time.get_ticks_msec()
			_last_second = -1
		visible = should_show


func _apply_post_settings() -> void:
	if _post_material == null:
		return
	_post_material.set_shader_parameter(&"film_strength", film_strength)
	_post_material.set_shader_parameter(&"grain_strength", grain_strength)
	_post_material.set_shader_parameter(&"scanline_strength", scanline_strength)
	_post_material.set_shader_parameter(&"aberration_px", aberration_px)


static func sanity_intensity(sanity: float) -> float:
	return clampf((70.0 - sanity) / 70.0, 0.0, 0.68)
