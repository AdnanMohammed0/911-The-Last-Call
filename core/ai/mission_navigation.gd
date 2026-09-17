## Per-mission navigation: bakes the navmesh from the level geometry when the mission loads on the host
## and, if the level has no authored CoverPoints, generates them along the navmesh border next to walls.
## Place it in a mission scene; with `source_group` empty the level geometry must be its children,
## otherwise every node in that group (and its children) is parsed.
## Authority: HOST (clients do not run AI, so they never bake)
class_name MissionNavigation
extends NavigationRegion3D

signal navigation_ready(cover_points: int)

@export var bake_on_ready: bool = true
@export var auto_generate_cover: bool = true
## Parse nodes in this group instead of this region's children (lets you drop it into existing levels).
@export var source_group: StringName = &""
@export var agent_radius: float = 0.4
@export var cover_spacing: float = 1.6

var is_ready_for_ai: bool = false


func _ready() -> void:
	if navigation_mesh == null:
		navigation_mesh = NavigationMesh.new()
	var mesh: NavigationMesh = navigation_mesh
	mesh.agent_radius = agent_radius
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.35
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	if source_group != &"":
		mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
		mesh.geometry_source_group_name = source_group
	if bake_on_ready and multiplayer.is_server():
		bake_now.call_deferred()


## Synchronous bake + cover generation (a slice mission bakes in well under a second).
func bake_now() -> void:
	bake_navigation_mesh(false)
	await get_tree().physics_frame  # let the navigation map sync the new region
	await get_tree().physics_frame
	var generated: int = 0
	if auto_generate_cover and get_tree().get_nodes_in_group(CoverPoint.GROUP).is_empty():
		generated = CoverGenerator.generate(self, cover_spacing)
	is_ready_for_ai = true
	navigation_ready.emit(get_tree().get_nodes_in_group(CoverPoint.GROUP).size())
	if generated > 0:
		print_verbose("MissionNavigation: generated %d cover points" % generated)
