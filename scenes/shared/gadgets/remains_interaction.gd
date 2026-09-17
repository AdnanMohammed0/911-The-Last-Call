## Remains Interaction — burial objective for anomaly resolution (GAMEPLAY_MECHANICS §9.2, §10.2).
## Find and bury remains to permanently banish the Drowned Woman anomaly.
## Authority: HOST (validates interaction, updates flags).
class_name RemainsInteraction
extends Interactable

signal remains_found(position: Vector3)
signal burial_started()
signal burial_completed(flag_id: StringName)
signal burial_progress(progress: float)

@export var interaction_time: float = 4.0
@export var required_tool: StringName = &"shovel"  # or "hands" for bare-hand burial
@export var flag_on_complete: StringName = &"lake_house_cleared"
@export var reward_evidence: StringName = &""

var _burial_state: int = 0  # 0 = intact, 1 = dug_up, 2 = buried
var _dig_progress: float = 0.0
var _dig_timer: Timer = null
var _shovel_item_id: StringName = &"shovel"


func _ready() -> void:
	super()
	prompt_text = "Bury remains"
	max_distance = 2.5
	cooldown = 1.0
	
	# Visual: skeletal remains on ground
	_create_remains_visual()


func _create_remains_visual() -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "RemainsMesh"
	
	# Simple skeleton shape
	var cs: CSGSphere3D = CSGSphere3D.new()
	cs.radius = 0.15
	cs.operation = CSGCombiner3D.OPERATION_UNION
	
	var skel: Node3D = Node3D.new()
	skel.name = "Skeleton"
	
	# Skull
	var skull: CSGSphere3D = CSGSphere3D.new()
	skull.radius = 0.12
	skull.transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.4, 0)
	skel.add_child(skull)
	
	# Ribcage
	var ribs: CSGBox3D = CSGBox3D.new()
	ribs.size = Vector3(0.25, 0.2, 0.1)
	ribs.transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.2, 0)
	skel.add_child(ribs)
	
	# Arms
	for side in [-1, 1]:
		var arm: CSGCylinder3D = CSGCylinder3D.new()
		arm.radius = 0.03
		arm.height = 0.35
		arm.rotation_degrees = Vector3(90, 0, side * 30)
		arm.transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, side * 0.2, 0.2, 0)
		skel.add_child(arm)
	
	# Legs
	for side in [-1, 1]:
		var leg: CSGCylinder3D = CSGCylinder3D.new()
		leg.radius = 0.04
		leg.height = 0.4
		leg.rotation_degrees = Vector3(-90, 0, side * 15)
		leg.transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, side * 0.1, -0.3, 0)
		skel.add_child(leg)
	
	mesh.mesh = _skel_to_mesh(skel)
	mesh.material_override = _make_bone_material()
	add_child(mesh)


func _skel_to_mesh(skel: Node3D) -> ArrayMesh:
	# Use a simple ArrayMesh for the remains
	var mesh: ArrayMesh = ArrayMesh.new()
	# Just return a simple box for now - in production use proper skeleton mesh
	var arr: Array = []
	arr.resize(ArrayMesh.ARRAY_MAX)
	var verts: PackedVector3Array = PackedVector3Array([
		Vector3(-0.15, -0.3, -0.1), Vector3(0.15, -0.3, -0.1), Vector3(0.15, 0.1, -0.1), Vector3(-0.15, 0.1, -0.1),
		Vector3(-0.15, -0.3, 0.1), Vector3(0.15, -0.3, 0.1), Vector3(0.15, 0.1, 0.1), Vector3(-0.15, 0.1, 0.1)
	])
	var indices: PackedInt32Array = PackedInt32Array([0,1,2,2,3,0, 4,5,6,6,7,4, 0,1,5,5,4,0, 2,3,7,7,6,2, 0,3,7,7,4,0, 1,2,6,6,5,1])
	arr[ArrayMesh.ARRAY_VERTEX] = verts
	arr[ArrayMesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVES_TRIANGLES, arr)
	return mesh


func _make_bone_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.75, 0.7, 1.0)
	mat.roughness = 0.9
	return mat


func _on_interacted(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _burial_state != 0:
		return
	
	# Check if player has required tool (shovel) or can dig by hand
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	
	var has_tool: bool = false
	if _required_tool != &"" and _required_tool != &"hands":
		var loadout: Dictionary = LoadoutManager.get_player_loadout(peer_id)
		has_tool = loadout.has(_required_tool)
	else:
		has_tool = true  # Can dig by hand
	
	if not has_tool:
		# Notify player they need a shovel
		return
	
	_start_burial(peer_id)


func _start_burial(peer_id: int) -> void:
	_burial_state = 1  # dug_up
	_dig_progress = 0.0
	burial_started.emit()
	
	# Visual feedback: show digging
	EventBus.noise_event.emit(global_position, 3.0, peer_id)
	
	# Start dig timer
	_dig_timer = Timer.new()
	_dig_timer.wait_time = interaction_time
	_dig_timer.one_shot = false
	_dig_timer.timeout.connect(_dig_tick.bind(peer_id))
	add_child(_dig_timer)
	_dig_timer.start()


func _dig_tick(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _burial_state != 1:
		_dig_timer.stop()
		_dig_timer.queue_free()
		return
	
	_dig_progress += _dig_timer.wait_time / interaction_time
	burial_progress.emit(_dig_progress)
	
	# Visual: particle effect while digging
	EventBus.noise_event.emit(global_position, 2.0, peer_id)
	
	if _dig_progress >= 1.0:
		_complete_burial(peer_id)


func _complete_burial(peer_id: int) -> void:
	_burial_state = 2  # buried
	_dig_timer.stop()
	_dig_timer.queue_free()
	
	# Set the flag
	FlagSystem.set_flag(flag_on_complete, true)
	
	# Reveal evidence if specified
	if reward_evidence != &"":
		FlagSystem.set_flag(reward_evidence, true)
	
	# Visual: remains disappear, peaceful effect
	queue_free()
	
	burial_completed.emit(flag_on_complete)
	
	# Notify anomaly system if needed
	EventBus.call_event.emit(&"", &"remains_buried")


## Checks if remains are still present (not buried)
func is_available() -> bool:
	return _burial_state == 0


## Gets the flag that will be set on completion
func get_completion_flag() -> StringName:
	return flag_on_complete