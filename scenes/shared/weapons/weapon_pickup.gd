## A weapon lying on the floor (dropped by a player). Interact to pick it up with its remaining ammo; a
## weapon already in that slot is dropped in its place (swap).
## Authority: HOST (spawned / removed through WorldItems)
class_name WeaponPickup
extends Interactable

var weapon_id: StringName = &""
var magazine: int = 0
var reserve: int = 0


func _ready() -> void:
	super._ready()
	cooldown = 0.3
	max_distance = 2.2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 0.35, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 0.15, 0)
	add_child(shape)
	var data: WeaponData = WeaponCatalog.get_data(weapon_id)
	if data != null and DisplayServer.get_name() != "headless":
		var model: WeaponModel = WeaponModel.build(data)
		# Lying on its side on the floor.
		model.rotation_degrees = Vector3(0, 90, 90)
		model.position = Vector3(0, 0.05, data.body_length * 0.5)
		add_child(model)


func get_prompt_text() -> String:
	var data: WeaponData = WeaponCatalog.get_data(weapon_id)
	if data == null:
		return ""
	var local: Player = Player.find_by_peer(get_tree(), multiplayer.get_unique_id())
	if local != null and not data.is_allowed_for(local.class_id):
		return "%s — not qualified" % data.display_name
	if local != null and local.get_weapons().has_weapon(data.slot):
		return "Swap for %s (%d/%d)" % [data.display_name, magazine, reserve]
	return "Pick up %s (%d/%d)" % [data.display_name, magazine, reserve]


func _can_interact(peer_id: int) -> bool:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	var data: WeaponData = WeaponCatalog.get_data(weapon_id)
	return player != null and data != null and player.get_health().is_alive() and data.is_allowed_for(player.class_id)


func _on_interact(peer_id: int) -> void:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	var data: WeaponData = WeaponCatalog.get_data(weapon_id)
	if player == null or data == null:
		return
	var weapons: WeaponHolder = player.get_weapons()
	if weapons.has_weapon(data.slot):
		weapons.host_drop(peer_id, data.slot, global_position)
	weapons.set_weapon(data.slot, weapon_id)
	weapons.set_ammo(data.slot, magazine, reserve)
	# Remove a moment later so every peer processes this interaction's confirmation first.
	enabled = false
	get_tree().create_timer(0.25).timeout.connect(WorldItems.remove.bind(String(name)))
