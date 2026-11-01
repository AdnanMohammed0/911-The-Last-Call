## The non-combat objective for the Route 9 crash response.
class_name RoadsideAssist
extends Interactable


func _ready() -> void:
	super()
	prompt_text = "Stabilize injured driver and call ambulance"
	hold_duration = 3.0
	max_distance = 2.8
	single_use = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.75
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)
	var torso: MeshInstance3D = MeshInstance3D.new()
	var torso_mesh: CapsuleMesh = CapsuleMesh.new()
	torso_mesh.radius = 0.3
	torso_mesh.height = 1.1
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.65, 0)
	torso.rotation.z = 0.65
	torso.material_override = _material(Color(0.85, 0.46, 0.18))
	add_child(torso)
	var head: MeshInstance3D = MeshInstance3D.new()
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position = Vector3(-0.42, 0.77, 0)
	head.material_override = _material(Color(0.64, 0.42, 0.32))
	add_child(head)
	MissionDirector.state_changed.connect(_refresh)
	_refresh(MissionDirector.state)


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _refresh(_state: MissionDirector.State) -> void:
	var active: bool = MissionDirector.mission_kind == &"assist" and MissionDirector.mission_call_id == &"call_highway_crash"
	visible = active
	enabled = active and MissionDirector.state == MissionDirector.State.DEPLOYED


func _can_interact(_peer_id: int) -> bool:
	return enabled


func _on_interact(_peer_id: int) -> void:
	MissionDirector.complete_assist()
