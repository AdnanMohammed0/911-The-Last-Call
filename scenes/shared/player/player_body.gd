## Third-person body of a player: a HumanoidRig in police uniform and plate carrier with the class colour on
## the armbands, holding the player's active weapon, animated with a BodyDynamics cartoon-body layer. Reads the replicated player state every frame (aim pitch,
## crouch, lean, sprint, ADS, reload) so remote players look exactly like what their owner is doing.
## The owner's copy renders on RENDER_LAYER_FIRST_PERSON, which the owner's camera culls (it still casts
## shadows).
## Authority: LOCAL (purely visual; reads replicated state from the parent Player)
class_name PlayerBody
extends Node3D

## Visual layer 11: hidden from the owning player's own camera.
const RENDER_LAYER_FIRST_PERSON: int = 1 << 10
const CROUCH_RATIO: float = 1.1 / 1.8

@export_group("Movement Personality")
@export_range(0.0, 0.2, 0.005) var wobble_strength: float = 0.11
@export_range(0.0, 0.2, 0.005) var bounce_strength: float = 0.11
@export_range(0.0, 0.015, 0.0005) var acceleration_lean: float = 0.007
@export_range(0.0, 0.08, 0.001) var turn_lean: float = 0.04
@export_range(1.0, 10.0, 0.25) var spring_frequency: float = 4.5
@export_range(0.3, 1.5, 0.05) var spring_damping: float = 0.78
@export_range(0.0, 0.03, 0.001) var idle_breathing: float = 0.008
@export_range(0.0, 0.15, 0.005) var squash_strength: float = 0.07
@export_range(0.5, 2.0, 0.05) var run_exaggeration: float = 1.5

@export_group("Cartoon Body")
## Master strength of the secondary-motion layer (BodyDynamics); 0 turns it off.
@export_range(0.0, 1.5, 0.05) var cartoon_amount: float = 1.0
## Metres the hips trail per m/s² of acceleration.
@export_range(0.0, 0.03, 0.001) var hip_lag: float = 0.011
## Radians of spring lean per m/s² of acceleration (forward when speeding up, back when braking).
@export_range(0.0, 0.03, 0.001) var lean_gain: float = 0.011
@export_range(0.0, 2.0, 0.05) var head_wobble: float = 0.85
@export_range(0.0, 2.0, 0.05) var arm_flop: float = 1.0
## How much of a sudden turn the body lags behind before swinging round (0..1).
@export_range(0.0, 1.0, 0.05) var turn_lag: float = 0.55
@export_range(0.0, 2.0, 0.05) var dizziness: float = 1.0
@export_range(0.0, 2.0, 0.05) var idle_fidgets: float = 1.0
@export_range(0.0, 2.0, 0.05) var step_springiness: float = 1.0

var rig: HumanoidRig
var _player: Player
var _class_color: Color = Color(0.3, 0.8, 0.4)
var _height_ratio: float = 1.0
var _applied_look: StringName = &""


func _ready() -> void:
	_player = get_parent() as Player
	rig = HumanoidRig.new()
	rig.name = "Rig"
	rig.wobble_strength = wobble_strength
	rig.bounce_strength = bounce_strength
	rig.acceleration_lean = acceleration_lean
	rig.turn_lean = turn_lean
	rig.spring_frequency = spring_frequency
	rig.spring_damping = spring_damping
	rig.idle_breathing = idle_breathing
	rig.squash_strength = squash_strength
	rig.run_exaggeration = run_exaggeration
	if cartoon_amount > 0.0:
		rig.dynamics = _make_dynamics()
	_apply_class_look()
	add_child(rig)


func _process(_delta: float) -> void:
	if _player == null or rig == null:
		return
	if _applied_look != _look_for_class(_player.class_id):
		_apply_class_look()
	rig.aim_pitch = _player.get_camera().rotation.x
	rig.crouch = clampf((1.0 - _height_ratio) / (1.0 - CROUCH_RATIO), 0.0, 1.0)
	rig.lean = _player.lean_amount
	rig.sprinting = _player.is_sprinting
	var weapons: WeaponHolder = _player.get_weapons()
	if weapons != null:
		rig.aiming = weapons.aiming
		rig.reloading = weapons.is_reloading()


func _make_dynamics() -> BodyDynamics:
	var dynamics: BodyDynamics = BodyDynamics.new()
	dynamics.amount = cartoon_amount
	dynamics.hip_lag = hip_lag
	dynamics.lean_gain = lean_gain
	dynamics.head_wobble = head_wobble
	dynamics.arm_flop = arm_flop
	dynamics.turn_lag = turn_lag
	dynamics.dizziness = dizziness
	dynamics.fidgets = idle_fidgets
	dynamics.step_bounce = step_springiness
	return dynamics


func set_class_color(color: Color) -> void:
	_class_color = color
	if rig != null:
		_apply_class_look()


func _apply_class_look() -> void:
	if rig == null or _player == null:
		return
	_applied_look = _look_for_class(_player.class_id)
	rig.dress(_applied_look, {"armband": _class_color})


static func _look_for_class(class_id: StringName) -> StringName:
	return class_id if class_id in [&"tech", &"profiler", &"breacher", &"medic"] else &"police"


## Gun in the character's hands (null = empty hands). Called by WeaponHolder on every peer.
func set_weapon(model: WeaponModel, one_handed: bool) -> void:
	if rig != null:
		rig.set_weapon(model, HumanoidRig.Stance.PISTOL if one_handed else HumanoidRig.Stance.RIFLE)


func muzzle_position() -> Vector3:
	return rig.muzzle_position() if rig != null else global_position


func land(impact_speed: float) -> void:
	if rig != null:
		rig.land(impact_speed)


## First person: the whole body (including head parts registered by the Player) is hidden from our camera.
func set_first_person(nodes: Array[Node], first_person: bool) -> void:
	var layer: int = RENDER_LAYER_FIRST_PERSON if first_person else 1
	if rig != null:
		rig.set_render_layers(layer)
	for root: Node in nodes:
		for node: Node in [root] + root.find_children("*", "VisualInstance3D", true, false):
			var visual: VisualInstance3D = node as VisualInstance3D
			if visual == null or visual is Light3D:
				continue
			visual.layers = layer


## 0..1 of standing height (crouching bends the rig's knees).
func set_height_ratio(ratio: float) -> void:
	_height_ratio = ratio
