## Downed / critical overlay for the local player: desaturating red screen, big state title, the bleed-out
## countdown on a draining ring and who (if anyone) is reviving you.
## Authority: LOCAL
class_name HealthHud
extends Control

@export var player: Player

var _overlay: ColorRect
var _title: Label
var _status: Label
var _ring: CountdownRing


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0.3, 0.0, 0.0)
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 scene = textureLod(screen_tex, SCREEN_UV, 1.5).rgb;
	float grey = dot(scene, vec3(0.3, 0.59, 0.11));
	float edge = smoothstep(0.2, 0.8, length(UV - vec2(0.5)));
	vec3 tinted = mix(vec3(grey) * vec3(1.0, 0.55, 0.5), COLOR.rgb, 0.35 + edge * 0.5);
	COLOR = vec4(tinted, 1.0);
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_overlay.material = material
	_overlay.visible = false
	add_child(_overlay)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 10)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(column)
	_ring = CountdownRing.new()
	_ring.custom_minimum_size = Vector2(120, 120)
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_ring)
	_title = UiKit.label("DOWNED", 72, Color(1, 0.9, 0.88), &"black_italic")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_status = UiKit.label("", 20, Color(1, 0.85, 0.82), &"medium")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)


func _process(_delta: float) -> void:
	if player == null:
		return
	var health: HealthComponent = player.get_health()
	match health.state:
		HealthComponent.State.ALIVE:
			_overlay.visible = false
		HealthComponent.State.DOWNED:
			_overlay.visible = true
			_title.text = "DOWNED"
			_ring.visible = true
			_ring.seconds = health.bleed_out_remaining
			_ring.ratio = health.bleed_out_remaining / maxf(HealthComponent.BLEED_OUT_SEC, 0.01)
			_ring.queue_redraw()
			_status.text = ("Being revived by %s…" % NetManager.get_player_name(health.reviver_peer)) if health.reviver_peer != 0 \
				else "Bleeding out — call a Medic or a teammate with a Trauma Kit"
		HealthComponent.State.CRITICAL:
			_overlay.visible = true
			_ring.visible = false
			_title.text = "CRITICAL"
			_status.text = "You are out for the rest of the mission"


class CountdownRing:
	extends Control

	var seconds: float = 0.0
	var ratio: float = 1.0

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 4.0
		draw_arc(centre, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.15), 5.0, true)
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 64, Color(1, 0.3, 0.26), 5.0, true)
		var font: Font = GameTheme.font(&"black_italic")
		var text: String = str(ceili(seconds))
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 46)
		draw_string(font, centre + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color.WHITE)
