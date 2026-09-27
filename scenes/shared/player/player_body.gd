## Third-person body of a player: a HumanoidRig in police uniform and plate carrier with the class colour on
## the armbands, holding the player's active weapon. Reads the replicated player state every frame (aim pitch,
## crouch, lean, sprint, ADS, reload) so remote players look exactly like what their owner is doing.
## The owner's copy renders on RENDER_LAYER_FIRST_PERSON, which the owner's camera culls (it still casts
## shadows).
## Authority: LOCAL (purely visual; reads replicated state from the parent Player)
class_name PlayerBody
extends Node3D

## Visual layer 11: hidden from the owning player's own camera.
const RENDER_LAYER_FIRST_PERSON: int = 1 << 10
const CROUCH_RATIO: float = 1.1 / 1.8

var rig: HumanoidRig
var _player: Player
var _class_color: Color = Color(0.3, 0.8, 0.4)
var _height_ratio: float = 1.0


func _ready() -> void:
	_player = get_parent() as Player
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.dress(&"police", {"armband": _class_color})


func _process(_delta: float) -> void:
	if _player == null or rig == null:
		return
	rig.aim_pitch = _player.get_camera().rotation.x
	rig.crouch = clampf((1.0 - _height_ratio) / (1.0 - CROUCH_RATIO), 0.0, 1.0)
	rig.lean = _player.lean_amount
	rig.sprinting = _player.is_sprinting
	var weapons: WeaponHolder = _player.get_weapons()
	if weapons != null:
		rig.aiming = weapons.aiming
		rig.reloading = weapons.is_reloading()


func set_class_color(color: Color) -> void:
	_class_color = color
	if rig != null:
		rig.dress(&"police", {"armband": color})


## Gun in the character's hands (null = empty hands). Called by WeaponHolder on every peer.
func set_weapon(model: WeaponModel, one_handed: bool) -> void:
	if rig != null:
		rig.set_weapon(model, HumanoidRig.Stance.PISTOL if one_handed else HumanoidRig.Stance.RIFLE)


func muzzle_position() -> Vector3:
	return rig.muzzle_position() if rig != null else global_position


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
