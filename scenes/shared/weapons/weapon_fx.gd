## Short-lived gunfire effects: muzzle flash light + sprite, tracer streak, impact puff.
## Authority: LOCAL (cosmetic, never replicated)
class_name WeaponFx
extends RefCounted

static var _tracer_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D
static var _dust_material: StandardMaterial3D


static func muzzle_flash(parent: Node, at: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 3.5
	light.omni_range = 6.0
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = at
	var sprite: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flash_material.albedo_color = Color(1.0, 0.75, 0.35, 0.9)
		_flash_material.albedo_texture = _radial_texture(Color(1.0, 0.95, 0.8), Color(1.0, 0.55, 0.15, 0.0))
	quad.material = _flash_material
	sprite.mesh = quad
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.rotation.z = randf() * TAU
	parent.add_child(sprite)
	sprite.global_position = at
	_expire(parent, light, 0.05)
	_expire(parent, sprite, 0.04)


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 0.5:
		return
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tracer_material.albedo_color = Color(1.0, 0.85, 0.55, 0.55)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.006
	mesh.bottom_radius = 0.006
	mesh.height = minf(length, 6.0)
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.material = _tracer_material
	var streak: MeshInstance3D = MeshInstance3D.new()
	streak.mesh = mesh
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(streak)
	var direction: Vector3 = (to - from).normalized()
	streak.global_position = from + direction * mesh.height * 0.5
	streak.look_at(streak.global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)
	streak.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tween: Tween = streak.create_tween()
	tween.tween_property(streak, "global_position", to - direction * mesh.height * 0.5, clampf(length / 400.0, 0.02, 0.2))
	tween.tween_callback(streak.queue_free)


static func impact(parent: Node, at: Vector3) -> void:
	if _dust_material == null:
		_dust_material = StandardMaterial3D.new()
		_dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_dust_material.albedo_color = Color(0.55, 0.5, 0.45, 0.6)
		_dust_material.albedo_texture = _radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	var puff: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	quad.material = _dust_material
	puff.mesh = quad
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(puff)
	puff.global_position = at
	var tween: Tween = puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector3.ONE * 2.2, 0.35)
	tween.tween_property(puff, "position:y", puff.position.y + 0.15, 0.35)
	tween.chain().tween_callback(puff.queue_free)


## Soft round sprite (centre colour fading to the edge) so flashes and puffs never render as squares.
static func _radial_texture(inner: Color, outer: Color) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


static func _expire(parent: Node, node: Node, seconds: float) -> void:
	parent.get_tree().create_timer(seconds).timeout.connect(node.queue_free)
