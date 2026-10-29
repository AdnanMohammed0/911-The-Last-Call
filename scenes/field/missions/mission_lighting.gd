extends WorldEnvironment
## Per-map lighting budget. The mission builder and saved scenes use the same profiles.

@export_enum("warehouse", "aspen", "farmhouse", "lake", "highway") var profile: String = "warehouse"

const SHADOW_FIXTURES := {
	"warehouse": ["FloodWest", "FloodEast", "Pendant0", "LampYard"],
	"aspen": ["PorchLight", "LivingRoomLamp", "GaragePendant"],
	"farmhouse": ["LaneLamp"],
	"lake": ["RoadLight"],
	"highway": ["SouthSodium"],
}


func _ready() -> void:
	if environment == null:
		return
	# Scenes own their environment; duplicate protects a shared resource if a map is instanced twice.
	environment = environment.duplicate()
	apply_profile(environment, profile)
	var lighting := get_parent().get_node_or_null("Lighting")
	if lighting != null:
		_budget_shadows(lighting)


static func apply_profile(env: Environment, map_name: String) -> void:
	# Contact shading is kept on all maps. Screen-space bounce and SDFGI are exclusive.
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.45
	env.sdfgi_enabled = map_name == "warehouse"
	env.ssil_enabled = map_name in ["aspen", "farmhouse", "lake"]
	env.ssil_intensity = 0.45
	env.sdfgi_cascades = 2
	env.sdfgi_min_cell_size = 0.5
	env.sdfgi_energy = 0.65
	env.glow_intensity = 0.35
	env.glow_strength = 0.65
	env.volumetric_fog_enabled = true
	env.volumetric_fog_ambient_inject = 0.12
	match map_name:
		"warehouse":
			env.volumetric_fog_density = 0.008
			env.volumetric_fog_length = 45.0
			env.volumetric_fog_albedo = Color(0.52, 0.59, 0.7)
		"aspen":
			env.volumetric_fog_density = 0.012
			env.volumetric_fog_length = 42.0
			env.volumetric_fog_albedo = Color(0.62, 0.58, 0.52)
		"farmhouse":
			env.volumetric_fog_density = 0.011
			env.volumetric_fog_length = 36.0
			env.volumetric_fog_albedo = Color(0.52, 0.58, 0.63)
		"lake":
			env.volumetric_fog_density = 0.021
			env.volumetric_fog_length = 32.0
			env.volumetric_fog_albedo = Color(0.37, 0.58, 0.59)
		"highway":
			env.volumetric_fog_density = 0.015
			env.volumetric_fog_length = 65.0
			env.volumetric_fog_albedo = Color(0.65, 0.54, 0.39)


func _budget_shadows(node: Node) -> void:
	for child in node.get_children():
		if child is SpotLight3D or child is OmniLight3D:
			var light := child as Light3D
			var fixture := child.get_parent()
			if fixture.name == "Head":
				fixture = fixture.get_parent()
			light.shadow_enabled = fixture.name in SHADOW_FIXTURES.get(profile, [])
			if light.shadow_enabled:
				light.distance_fade_enabled = true
				light.distance_fade_begin = 24.0
				light.distance_fade_shadow = 18.0
				light.distance_fade_length = 12.0
		_budget_shadows(child)
