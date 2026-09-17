## Environment query for cover (GAMEPLAY_MECHANICS §8.3 "MoveToBestCover: distance 8–20 m, LoS to target,
## not flanked"). Scores every free CoverPoint and returns the best one.
## Authority: HOST
class_name CoverQuery
extends RefCounted

const MIN_THREAT_DISTANCE: float = 8.0
const MAX_THREAT_DISTANCE: float = 20.0
const IDEAL_THREAT_DISTANCE: float = 12.0
const MAX_SEARCH_RADIUS: float = 35.0
## Other threats closer than this must also be blocked, or the cover counts as flanked.
const FLANK_CHECK_RADIUS: float = 25.0
const THREAT_EYE: float = 1.5


## Best cover for `agent` against `threat` (a world position, usually the target's position).
## `other_threats` are the rest of the visible players (flank check). Returns null when nothing qualifies.
static func find_best(agent: Node3D, threat: Vector3, other_threats: Array[Vector3] = [], exclude: Array[RID] = []) -> CoverPoint:
	var best: CoverPoint = null
	var best_score: float = INF
	for node: Node in agent.get_tree().get_nodes_in_group(CoverPoint.GROUP):
		var point: CoverPoint = node as CoverPoint
		if point == null or not point.is_free_for(agent):
			continue
		var score: float = score_point(agent, point, threat, other_threats, exclude)
		if score < best_score:
			best_score = score
			best = point
	return best


## Lower is better; INF when the point is unusable.
static func score_point(agent: Node3D, point: CoverPoint, threat: Vector3, other_threats: Array[Vector3], exclude: Array[RID]) -> float:
	var position: Vector3 = point.global_position
	var to_agent: float = agent.global_position.distance_to(position)
	if to_agent > MAX_SEARCH_RADIUS:
		return INF
	var threat_distance: float = Vector2(position.x - threat.x, position.z - threat.z).length()
	if threat_distance < MIN_THREAT_DISTANCE or threat_distance > MAX_THREAT_DISTANCE:
		return INF
	var world: World3D = agent.get_world_3d()
	var threat_eye: Vector3 = threat + Vector3(0, THREAT_EYE, 0)
	if not is_protected(world, point, threat_eye, exclude):
		return INF
	if not can_peek(world, point, threat_eye, exclude):
		return INF
	for other: Vector3 in other_threats:
		if other.distance_to(position) <= FLANK_CHECK_RADIUS and not is_protected(world, point, other + Vector3(0, THREAT_EYE, 0), exclude):
			return INF
	var path_length: float = navigation_distance(agent, position)
	if path_length == INF:
		return INF
	# Short run to reach it, and close to the ideal engagement distance.
	return path_length + absf(threat_distance - IDEAL_THREAT_DISTANCE) * 0.75


static func is_protected(world: World3D, point: CoverPoint, threat_eye: Vector3, exclude: Array[RID]) -> bool:
	return _blocked(world, threat_eye, point.get_hide_eye(), exclude)


static func can_peek(world: World3D, point: CoverPoint, threat_eye: Vector3, exclude: Array[RID]) -> bool:
	for eye: Vector3 in point.get_peek_eyes():
		if not _blocked(world, eye, threat_eye, exclude):
			return true
	return false


## Walking distance on the navmesh (straight line when the agent has no navigation map).
static func navigation_distance(agent: Node3D, target: Vector3) -> float:
	var map: RID = agent.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return agent.global_position.distance_to(target)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, agent.global_position, target, true)
	if path.is_empty():
		return INF
	if path[path.size() - 1].distance_to(target) > 1.0:
		return INF  # unreachable: the path stops short
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


static func claim(point: CoverPoint, agent: Node) -> void:
	release_all(agent)
	if point != null:
		point.claimed_by = agent


static func release_all(agent: Node) -> void:
	for node: Node in agent.get_tree().get_nodes_in_group(CoverPoint.GROUP):
		var point: CoverPoint = node as CoverPoint
		if point != null and point.claimed_by == agent:
			point.claimed_by = null


static func _blocked(world: World3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	return not world.direct_space_state.intersect_ray(query).is_empty()
