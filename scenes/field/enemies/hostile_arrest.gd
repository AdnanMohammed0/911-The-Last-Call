## "Hold [F] Arrest" on a suspect who gave up. Created as a child of every HostileAgent on every peer
## (same node path everywhere, so the Interactable RPCs resolve).
## Authority: HOST
class_name HostileArrest
extends Interactable

var hostile: HostileAgent


static func create(owner_agent: HostileAgent) -> HostileArrest:
	var point: HostileArrest = HostileArrest.new()
	point.name = "Arrest"
	point.hostile = owner_agent
	point.hold_duration = HostileAgent.ARREST_HOLD_SECONDS
	point.max_distance = 2.6
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	point.add_child(shape)
	owner_agent.add_child(point)
	return point


func get_prompt_text() -> String:
	if hostile == null or not hostile.is_surrendered or hostile.is_arrested or hostile.is_dead:
		return ""
	return "Arrest %s" % hostile.archetype.display_name.to_lower()


func is_available_to(peer_id: int) -> bool:
	return hostile != null and hostile.is_surrendered and not hostile.is_arrested and not hostile.is_dead \
		and super.is_available_to(peer_id)


func _can_interact(peer_id: int) -> bool:
	var player: Player = Player.find_by_peer(get_tree(), peer_id)
	return player != null and player.get_health().is_alive() and hostile.is_surrendered and not hostile.is_arrested


func _on_interact(peer_id: int) -> void:
	hostile.arrest(peer_id)
