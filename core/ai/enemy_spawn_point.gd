## Where the host spawns a hostile when the mission's navigation is ready.
## Authority: HOST
class_name EnemySpawnPoint
extends Marker3D

@export var archetype: ArchetypeData
## Squad node (AISquad) this hostile joins; empty = no squad.
@export var squad: NodePath
## Optional patrol route (its Node3D children).
@export var patrol_route: NodePath
## Mission kinds that use this point (&"raid", &"ambush", &"arrest"). Empty = raid and ambush.
@export var mission_kinds: Array[StringName] = []


func is_used_by(kind: StringName) -> bool:
	if mission_kinds.is_empty():
		return kind == &"raid" or kind == &"ambush"
	return kind in mission_kinds
