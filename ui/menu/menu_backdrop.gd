## Live 3D backdrop for the main menu: a rainy night street outside Station 4 — police cruiser with its light
## bar strobing red / blue, the armored truck, barriers, a sodium street lamp, wet reflective asphalt, fog and
## rain — seen through a slowly drifting camera framed to the right of the menu sidebar.
## Authority: LOCAL (purely visual)
class_name MenuBackdrop
extends SubViewportContainer

const RAIN_COUNT: int = 2600

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _red: Array[OmniLight3D] = []
var _blue: Array[OmniLight3D] = []
var _bar_red: StandardMaterial3D
var _bar_blue: StandardMaterial3D
var _time: float = 0.0
var _kit: LevelKit


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport.positional_shadow_atlas_size = 4096
	add_child(_viewport)
	if DisplayServer.get_name() == "headless":
		return
	_world = Node3D.new()
	_world.name = "Street"
	_viewport.add_child(_world)
	_kit = LevelKit.new(_world)
	_build_environment()
	_build_street()
	_build_vehicles()
	_build_rain()
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.h_offset = -1.4
	_world.add_child(_camera)
	_camera.current = true


func _process(delta: float) -> void:
	if _camera == null:
		return
	_time += delta
	# Slow orbit around the cruiser.
	var angle: float = -0.55 + sin(_time * 0.06) * 0.22
	var radius: float = 8.6 + sin(_time * 0.09) * 0.6
	var target: Vector3 = Vector3(0.4, 0.9, 0.0)
	_camera.position = target + Vector3(sin(angle) * radius, 1.35 + sin(_time * 0.11) * 0.15, cos(angle) * radius)
	_camera.look_at(target, Vector3.UP)
	# Light bar: fast alternating double-flash.
	var cycle: float = fmod(_time * 1.6, 1.0)
	var red_on: bool = (cycle < 0.12) or (cycle > 0.2 and cycle < 0.32)
	var blue_on: bool = (cycle > 0.5 and cycle < 0.62) or (cycle > 0.7 and cycle < 0.82)
	for light: OmniLight3D in _red:
		light.light_energy = lerpf(light.light_energy, 9.0 if red_on else 0.0, clampf(40.0 * delta, 0.0, 1.0))
	for light: OmniLight3D in _blue:
		light.light_energy = lerpf(light.light_energy, 10.0 if blue_on else 0.0, clampf(40.0 * delta, 0.0, 1.0))
	if _bar_red != null:
		_bar_red.emission_energy_multiplier = 6.0 if red_on else 0.3
		_bar_blue.emission_energy_multiplier = 6.0 if blue_on else 0.3


func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.18)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.1, 0.16)
	env.fog_density = 0.035
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.025
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.85)
	env.volumetric_fog_emission = Color(0.01, 0.012, 0.02)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.9
	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.environment = env
	_world.add_child(holder)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.8)
	moon.light_energy = 0.25
	moon.rotation_degrees = Vector3(-35, 140, 0)
	moon.shadow_enabled = true
	_world.add_child(moon)


func _build_street() -> void:
	# Wet asphalt: dark, glossy, so the light bar and lamp reflect in it.
	var asphalt: StandardMaterial3D = StandardMaterial3D.new()
	var source: StandardMaterial3D = load("res://assets/materials/asphalt.tres") as StandardMaterial3D
	if source != null:
		asphalt = source.duplicate() as StandardMaterial3D
	asphalt.albedo_color = asphalt.albedo_color.darkened(0.55)
	asphalt.roughness = 0.12
	asphalt.metallic = 0.1
	asphalt.uv1_scale = Vector3(12, 12, 12)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(90, 90)
	ground.mesh = plane
	ground.material_override = asphalt
	_world.add_child(ground)
	# Kerb + pavement behind the car.
	var kerb: StandardMaterial3D = StandardMaterial3D.new()
	kerb.albedo_color = Color(0.18, 0.18, 0.19)
	kerb.roughness = 0.4
	_kit.box(_world, "Pavement", Vector3(0, 0.08, -6.5), Vector3(60, 0.16, 5.0), kerb, 0.0, false)
	# Building silhouettes with a few lit windows.
	var wall: StandardMaterial3D = StandardMaterial3D.new()
	wall.albedo_color = Color(0.05, 0.055, 0.065)
	wall.roughness = 0.9
	var window_lit: StandardMaterial3D = StandardMaterial3D.new()
	window_lit.albedo_color = Color(1.0, 0.78, 0.45)
	window_lit.emission_enabled = true
	window_lit.emission = Color(1.0, 0.72, 0.4)
	window_lit.emission_energy_multiplier = 2.2
	var window_cold: StandardMaterial3D = window_lit.duplicate() as StandardMaterial3D
	window_cold.albedo_color = Color(0.55, 0.75, 1.0)
	window_cold.emission = Color(0.5, 0.7, 1.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 911
	var x: float = -26.0
	while x < 26.0:
		var width: float = rng.randf_range(5.0, 9.0)
		var height: float = rng.randf_range(6.0, 16.0)
		_kit.box(_world, "Building", Vector3(x + width * 0.5, height * 0.5, -12.0 - rng.randf_range(0.0, 3.0)), Vector3(width, height, 6.0), wall, 0.0, false)
		for row: int in int(height / 2.6):
			for col: int in int(width / 1.8):
				if rng.randf() < 0.22:
					var pane: BoxMesh = BoxMesh.new()
					pane.size = Vector3(0.9, 1.1, 0.05)
					_kit.mesh(_world, "Window", pane, Vector3(x + 0.9 + col * 1.8, 1.6 + row * 2.6, -8.95), window_lit if rng.randf() < 0.75 else window_cold, Vector3.ZERO, false)
		x += width + rng.randf_range(0.2, 1.5)
	# Station sign glowing over the door.
	var sign_label: Label3D = Label3D.new()
	sign_label.text = "BLACKVALE COUNTY SHERIFF · STATION 4"
	sign_label.font = GameTheme.font(&"bold")
	sign_label.font_size = 96
	sign_label.pixel_size = 0.006
	sign_label.modulate = Color(0.85, 0.9, 1.0)
	sign_label.outline_size = 0
	sign_label.position = Vector3(1.5, 4.6, -8.9)
	_world.add_child(sign_label)
	# Street lamp with sodium light.
	var lamp_pole: Vector3 = Vector3(-4.8, 0.0, -4.3)
	_kit.cylinder(_world, "LampPole", lamp_pole + Vector3(0, 3.2, 0), 0.08, 6.4, _kit.material("metal_dark"))
	_kit.box(_world, "LampArm", lamp_pole + Vector3(0.8, 6.3, 0), Vector3(1.6, 0.08, 0.2), _kit.material("metal_dark"), 0.0, false)
	var sodium: SpotLight3D = SpotLight3D.new()
	sodium.light_color = Color(1.0, 0.62, 0.3)
	sodium.light_energy = 14.0
	sodium.spot_range = 14.0
	sodium.spot_angle = 48.0
	sodium.shadow_enabled = true
	sodium.light_volumetric_fog_energy = 2.0
	sodium.position = lamp_pole + Vector3(1.5, 6.2, 0)
	sodium.rotation_degrees = Vector3(-90, 0, 0)
	_world.add_child(sodium)
	# Barriers and cones around the scene.
	_kit.jersey_barrier(_world, "Barrier0", Vector3(-2.4, 0.0, -3.6), 8.0)
	_kit.jersey_barrier(_world, "Barrier1", Vector3(5.6, 0.0, -1.8), -20.0)
	var cone: StandardMaterial3D = StandardMaterial3D.new()
	cone.albedo_color = Color(1.0, 0.38, 0.05)
	for i: int in 4:
		var cone_mesh: CylinderMesh = CylinderMesh.new()
		cone_mesh.top_radius = 0.03
		cone_mesh.bottom_radius = 0.17
		cone_mesh.height = 0.55
		_kit.mesh(_world, "Cone", cone_mesh, Vector3(2.6 + i * 0.8, 0.28, 2.2 + i * 0.35), cone, Vector3.ZERO, true)


func _build_vehicles() -> void:
	var cruiser: Node3D = ModelKit.prop(_world, &"cruiser", "Cruiser", Vector3(0.0, 0.0, 0.0), -28.0)
	var roof: float = 1.6
	if cruiser != null:
		roof = ModelKit.size_of(cruiser).y
	var bar: Node3D = Node3D.new()
	bar.name = "LightBar"
	bar.position = Vector3(0.0, roof + 0.08, 0.1)
	bar.rotation_degrees.y = -28.0
	_world.add_child(bar)
	_bar_red = StandardMaterial3D.new()
	_bar_red.albedo_color = Color(1.0, 0.1, 0.08)
	_bar_red.emission_enabled = true
	_bar_red.emission = Color(1.0, 0.08, 0.05)
	_bar_blue = StandardMaterial3D.new()
	_bar_blue.albedo_color = Color(0.1, 0.3, 1.0)
	_bar_blue.emission_enabled = true
	_bar_blue.emission = Color(0.1, 0.35, 1.0)
	for side: float in [-1.0, 1.0]:
		var lens: BoxMesh = BoxMesh.new()
		lens.size = Vector3(0.5, 0.1, 0.22)
		var lens_node: MeshInstance3D = MeshInstance3D.new()
		lens_node.mesh = lens
		lens_node.material_override = _bar_red if side < 0.0 else _bar_blue
		lens_node.position = Vector3(side * 0.3, 0, 0)
		bar.add_child(lens_node)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.12, 0.08) if side < 0.0 else Color(0.15, 0.35, 1.0)
		light.omni_range = 16.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		light.light_volumetric_fog_energy = 3.0
		light.position = Vector3(side * 0.4, 0.25, 0)
		bar.add_child(light)
		if side < 0.0:
			_red.append(light)
		else:
			_blue.append(light)
	# Headlights.
	for side: float in [-0.65, 0.65]:
		var head: SpotLight3D = SpotLight3D.new()
		head.light_color = Color(0.9, 0.93, 1.0)
		head.light_energy = 6.0
		head.spot_range = 18.0
		head.spot_angle = 26.0
		head.light_volumetric_fog_energy = 1.5
		var forward: Basis = Basis(Vector3.UP, deg_to_rad(-28.0))
		head.position = forward * Vector3(side, 0.75, -2.45)
		head.basis = forward * Basis(Vector3.RIGHT, deg_to_rad(-6.0))
		_world.add_child(head)
	var truck: Node3D = ModelKit.prop(_world, &"armored_truck", "Truck", Vector3(-6.2, 0.0, -2.2), 62.0)
	if truck == null:
		_kit.cruiser(_world, "Van", Vector3(-6.2, 0.0, -2.2), 62.0, true)


func _build_rain() -> void:
	var rain: GPUParticles3D = GPUParticles3D.new()
	rain.amount = RAIN_COUNT
	rain.lifetime = 1.2
	rain.preprocess = 1.2
	rain.visibility_aabb = AABB(Vector3(-14, -2, -14), Vector3(28, 16, 28))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12, 0.5, 12)
	process.direction = Vector3(0.08, -1, 0.02)
	process.spread = 2.0
	process.initial_velocity_min = 14.0
	process.initial_velocity_max = 17.0
	process.gravity = Vector3(0, -9.8, 0)
	rain.process_material = process
	var drop: QuadMesh = QuadMesh.new()
	drop.size = Vector2(0.012, 0.38)
	var drop_material: StandardMaterial3D = StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.75, 0.8, 0.9, 0.28)
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = drop_material
	rain.draw_pass_1 = drop
	rain.position = Vector3(0, 11, 0)
	_world.add_child(rain)
