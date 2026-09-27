## Usable station furniture bought in StationMart: coffee machine, vending machine, water cooler, first aid
## station, infirmary beds, safe-room med kit (heal), trauma kit cabinet (hands out trauma kits), and fun
## props (arcade, pool table, TV) that just show a line.
## Builds its own interaction box from `box_size` so StationFurniture only has to place it.
## Authority: HOST (healing / kits are applied on the host and replicate through the player)
class_name StationAppliance
extends Interactable

enum Kind { HEAL, TRAUMA_KIT, FLAVOR }

const MAX_TRAUMA_KITS: int = 2

@export var kind: Kind = Kind.HEAL
@export var heal_amount: float = 15.0
@export var box_size: Vector3 = Vector3(0.8, 1.0, 0.6)
## Shown to the user after a successful use (local toast).
@export var use_message: String = ""


func _ready() -> void:
	super._ready()
	cooldown = 1.0
	if get_child_count() == 0 or get_node_or_null(^"Shape") == null:
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = "Shape"
		var box: BoxShape3D = BoxShape3D.new()
		box.size = box_size
		shape.shape = box
		add_child(shape)


func _can_interact(peer_id: int) -> bool:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null or not player.get_health().is_alive():
		return false
	if kind == Kind.TRAUMA_KIT:
		return player.trauma_kits < MAX_TRAUMA_KITS
	return true


func get_prompt_text() -> String:
	if kind == Kind.TRAUMA_KIT:
		var local: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
		if local != null and local.trauma_kits >= MAX_TRAUMA_KITS:
			return "Trauma kits (you carry the max %d)" % MAX_TRAUMA_KITS
	return prompt_text


func _on_interact(peer_id: int) -> void:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	if player == null:
		return
	match kind:
		Kind.HEAL:
			player.get_health().heal(heal_amount)
		Kind.TRAUMA_KIT:
			player.trauma_kits = mini(player.trauma_kits + 1, MAX_TRAUMA_KITS)


func _on_interacted(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id() and use_message != "":
		Economy.show_toast(use_message, 2.5)
