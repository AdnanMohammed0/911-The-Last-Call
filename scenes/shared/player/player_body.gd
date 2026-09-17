## Placeholder third-person body built from primitives (until Ali's character model lands):
## class-coloured vest, police cap, name tag, and a procedural walk cycle driven by movement speed.
## The owner's copy renders on RENDER_LAYER_FIRST_PERSON, which the owner's camera culls.
## Authority: LOCAL (purely visual; reads replicated state from the parent Player)
class_name PlayerBody
extends Node3D

## Visual layer 11: hidden from the owning player's own camera.
const RENDER_LAYER_FIRST_PERSON: int = 1 << 10
const WALK_REFERENCE_SPEED: float = 3.5
const STRIDE_FREQUENCY: float = 2.4
const LEG_SWING: float = 0.65
const ARM_SWING: float = 0.45

var _phase: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _speed: float = 0.0

@onready var _vest_material: StandardMaterial3D = ($Torso/Vest as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
@onready var _leg_left: Node3D = $LegLeft
@onready var _leg_right: Node3D = $LegRight
@onready var _arm_left: Node3D = $Torso/ArmLeft
@onready var _arm_right: Node3D = $Torso/ArmRight


func _ready() -> void:
	# Each player needs its own vest colour.
	_vest_material = _vest_material.duplicate() as StandardMaterial3D
	($Torso/Vest as MeshInstance3D).set_surface_override_material(0, _vest_material)
	_last_position = global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved: Vector3 = global_position - _last_position
	_last_position = global_position
	var instant_speed: float = Vector2(moved.x, moved.z).length() / delta
	_speed = lerpf(_speed, instant_speed, clampf(10.0 * delta, 0.0, 1.0))
	var amount: float = clampf(_speed / WALK_REFERENCE_SPEED, 0.0, 1.4)
	if amount < 0.05:
		_phase = lerpf(_phase, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	else:
		_phase += delta * STRIDE_FREQUENCY * TAU * clampf(amount, 0.6, 1.4)
	var swing: float = sin(_phase) * amount
	_leg_left.rotation.x = swing * LEG_SWING
	_leg_right.rotation.x = -swing * LEG_SWING
	_arm_left.rotation.x = -swing * ARM_SWING
	_arm_right.rotation.x = swing * ARM_SWING


func set_class_color(color: Color) -> void:
	_vest_material.albedo_color = color


## First person: the whole body (including head parts registered by the Player) is hidden from our camera.
func set_first_person(nodes: Array[Node], first_person: bool) -> void:
	for root: Node in nodes:
		for node: Node in [root] + root.find_children("*", "VisualInstance3D", true, false):
			var visual: VisualInstance3D = node as VisualInstance3D
			if visual == null or visual is Light3D:
				continue
			visual.layers = RENDER_LAYER_FIRST_PERSON if first_person else 1


## 0..1 of standing height; squashes the body when crouching.
func set_height_ratio(ratio: float) -> void:
	scale.y = ratio
