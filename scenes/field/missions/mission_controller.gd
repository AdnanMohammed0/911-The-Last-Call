## Mission map logic: counts active hostiles for the objective, and extracts the team once the area is
## secured and every standing player is inside the extraction radius.
## Authority: HOST
class_name MissionController
extends Node3D

## Extraction point (e.g. the van); players within `extraction_radius` of it count as extracted.
@export var extraction_point: Node3D
@export var extraction_radius: float = 4.0
## Offline playtests of the map without a response still get a working objective.
@export var start_response_if_idle: bool = true
## Seconds the team must stay at the extraction point.
@export var extraction_hold: float = 2.0

var _poll: float = 0.0
var _seen_hostiles: bool = false
var _at_extraction: float = 0.0


func _ready() -> void:
	if multiplayer.is_server() and start_response_if_idle and MissionDirector.state == MissionDirector.State.IDLE:
		var level: Node = owner if owner != null else self
		MissionDirector._sync_state.rpc(MissionDirector.State.DEPLOYED, level.scene_file_path, &"", 1.0, "Clear the area of armed suspects")


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0.0
	var total: int = 0
	var left: int = 0
	for node: Node in get_tree().get_nodes_in_group(HostileAgent.GROUP):
		var hostile: HostileAgent = node as HostileAgent
		if hostile == null:
			continue
		total += 1
		if hostile.is_active():
			left += 1
	if total > 0:
		_seen_hostiles = true
	if _seen_hostiles:
		MissionDirector.report_hostiles(left, total)
	if MissionDirector.state == MissionDirector.State.SECURED and _team_at_extraction():
		_at_extraction += 0.5
		if _at_extraction >= extraction_hold:
			MissionDirector.extract()
	else:
		_at_extraction = 0.0


func _team_at_extraction() -> bool:
	if extraction_point == null:
		return false
	var standing: int = 0
	for node: Node in get_tree().get_nodes_in_group(Player.GROUP):
		var player: Player = node as Player
		if player == null or player.connection_lost or not player.get_health().is_alive():
			continue
		standing += 1
		var flat: Vector3 = player.global_position - extraction_point.global_position
		flat.y = 0.0
		if flat.length() > extraction_radius:
			return false
	return standing > 0
