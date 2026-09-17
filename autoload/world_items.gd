## Dropped weapons lying in the level. The host decides every spawn / removal and broadcasts it, so each
## pickup exists under the same path (current scene / WorldItems / name) on every peer and its Interactable
## RPCs resolve everywhere. Level changes clear them with the scene.
## Authority: HOST
extends Node

const CONTAINER: String = "WorldItems"

var _next_id: int = 0


## Host: drop `weapon_id` with its ammo at `at` (feet position) for everyone.
func spawn_weapon(weapon_id: StringName, magazine: int, reserve: int, at: Vector3, yaw: float) -> String:
	if not multiplayer.is_server() or WeaponCatalog.get_data(weapon_id) == null:
		return ""
	_next_id += 1
	var pickup_name: String = "Weapon_%d" % _next_id
	_spawn.rpc(pickup_name, weapon_id, magazine, reserve, at, yaw)
	return pickup_name


## Host: remove a pickup everywhere.
func remove(pickup_name: String) -> void:
	if multiplayer.is_server():
		_remove.rpc(pickup_name)


func find(pickup_name: String) -> WeaponPickup:
	var holder: Node = _container(false)
	return holder.get_node_or_null(pickup_name) as WeaponPickup if holder != null else null


func pickups() -> Array[WeaponPickup]:
	var result: Array[WeaponPickup] = []
	var holder: Node = _container(false)
	if holder != null:
		for child: Node in holder.get_children():
			var pickup: WeaponPickup = child as WeaponPickup
			if pickup != null and not pickup.is_queued_for_deletion():
				result.append(pickup)
	return result


func _container(create: bool) -> Node:
	# The running level (tests without a current scene use the root instead).
	var scene: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var holder: Node = scene.get_node_or_null(CONTAINER)
	if holder == null and create:
		holder = Node3D.new()
		holder.name = CONTAINER
		scene.add_child(holder)
	return holder


@rpc("authority", "call_local", "reliable")
func _spawn(pickup_name: String, weapon_id: StringName, magazine: int, reserve: int, at: Vector3, yaw: float) -> void:
	var holder: Node = _container(true)
	if holder == null or holder.has_node(pickup_name):
		return
	var pickup: WeaponPickup = WeaponPickup.new()
	pickup.name = pickup_name
	pickup.weapon_id = weapon_id
	pickup.magazine = magazine
	pickup.reserve = reserve
	holder.add_child(pickup)
	pickup.global_position = at
	pickup.rotation.y = yaw


@rpc("authority", "call_local", "reliable")
func _remove(pickup_name: String) -> void:
	var pickup: WeaponPickup = find(pickup_name)
	if pickup != null:
		pickup.enabled = false
		pickup.queue_free()
