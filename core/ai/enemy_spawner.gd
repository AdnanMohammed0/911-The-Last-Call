## Spawns hostiles for every peer (MultiplayerSpawner with a custom spawn function) from EnemySpawnPoints
## once the mission navmesh is ready, and handles reinforcements called by an Ambush Leader.
## Spawn data: {"archetype": String path, "transform": Transform3D, "squad": NodePath, "patrol": NodePath, "name": String}
## Authority: HOST
class_name EnemySpawner
extends MultiplayerSpawner

const GROUP: StringName = &"enemy_spawners"
const HOSTILE_SCENE: PackedScene = preload("res://scenes/field/enemies/hostile.tscn")
const REINFORCEMENT_ARCHETYPE: String = "res://data/ai/archetypes/cultist_gunman.tres"

signal hostile_spawned(hostile: HostileAgent)

## Parent of the EnemySpawnPoint markers.
@export var spawn_points: Node3D
## Waits for this navigation before spawning (null = spawn immediately).
@export var navigation: MissionNavigation

var _count: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	spawn_function = _spawn_hostile
	spawned.connect(_on_spawned)
	if not multiplayer.is_server():
		return
	if navigation != null and not navigation.is_ready_for_ai:
		await navigation.navigation_ready
	spawn_from_points.call_deferred()


func spawn_from_points() -> void:
	if not multiplayer.is_server() or spawn_points == null:
		return
	for child: Node in spawn_points.get_children():
		var point: EnemySpawnPoint = child as EnemySpawnPoint
		if point == null or point.archetype == null:
			continue
		spawn_hostile(point.archetype.resource_path, point.global_transform, _level_path_to(point, point.squad), _level_path_to(point, point.patrol_route))


## Host: spawns one hostile for everyone. Paths are relative to the level root.
func spawn_hostile(archetype_path: String, at: Transform3D, squad_path: NodePath = NodePath(), patrol_path: NodePath = NodePath()) -> HostileAgent:
	_count += 1
	var hostile: HostileAgent = spawn({
		"archetype": archetype_path,
		"transform": at,
		"squad": squad_path,
		"patrol": patrol_path,
		"name": "Hostile_%d" % _count,
	}) as HostileAgent
	_refresh_level_visibility()
	return hostile


## Host: Ambush Leader reinforcements appear a few metres behind the leader, on the navmesh.
func spawn_reinforcements(leader: HostileAgent, count: int) -> void:
	var map: RID = leader.get_world_3d().navigation_map
	var squad_path: NodePath = NodePath()
	if leader.squad != null:
		squad_path = _level_root().get_path_to(leader.squad)
	for i: int in count:
		var offset: Vector3 = leader.global_basis.z * 4.0 + leader.global_basis.x * (float(i) - (count - 1) * 0.5) * 2.0
		var position: Vector3 = NavigationServer3D.map_get_closest_point(map, leader.global_position + offset)
		spawn_hostile(REINFORCEMENT_ARCHETYPE, Transform3D(leader.global_basis, position), squad_path)


func _spawn_hostile(data: Variant) -> Node:
	var info: Dictionary = data
	var hostile: HostileAgent = HOSTILE_SCENE.instantiate() as HostileAgent
	var archetype_path: String = info.get("archetype", "")
	var at: Transform3D = info.get("transform", Transform3D.IDENTITY)
	var node_name: String = info.get("name", "Hostile")
	hostile.name = node_name
	hostile.archetype = load(archetype_path) as ArchetypeData
	hostile.transform = at
	if multiplayer.is_server():
		var squad_path: NodePath = info.get("squad", NodePath())
		var patrol_path: NodePath = info.get("patrol", NodePath())
		var root: Node = _level_root()
		if not squad_path.is_empty():
			hostile.squad = root.get_node_or_null(squad_path) as AISquad
		if not patrol_path.is_empty():
			hostile.patrol_route = root.get_node_or_null(patrol_path) as Node3D
		hostile.ready.connect(func() -> void:
			if hostile.squad != null:
				hostile.squad.register(hostile), CONNECT_ONE_SHOT)
	return hostile


func _on_spawned(node: Node) -> void:
	var hostile: HostileAgent = node as HostileAgent
	if hostile != null:
		hostile_spawned.emit(hostile)


func _level_root() -> Node:
	return owner if owner != null else get_parent()


func _level_path_to(from: Node, path: NodePath) -> NodePath:
	if path.is_empty():
		return NodePath()
	var target: Node = from.get_node_or_null(path)
	return _level_root().get_path_to(target) if target != null else NodePath()


## New host-owned synchronizers must only replicate to peers that loaded the level (see PlayerSpawner).
func _refresh_level_visibility() -> void:
	for node: Node in _level_root().find_children("*", "PlayerSpawner", true, false):
		var player_spawner: PlayerSpawner = node as PlayerSpawner
		player_spawner.refresh_visibility()
		return
