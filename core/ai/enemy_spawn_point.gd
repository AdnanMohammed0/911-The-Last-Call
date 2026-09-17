## Where the host spawns a hostile when the mission's navigation is ready.
## Authority: HOST
class_name EnemySpawnPoint
extends Marker3D

@export var archetype: ArchetypeData
## Squad node (AISquad) this hostile joins; empty = no squad.
@export var squad: NodePath
## Optional patrol route (its Node3D children).
@export var patrol_route: NodePath
