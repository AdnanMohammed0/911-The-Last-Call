## Spawns one Player per peer under `spawn_path`, carrying peer id + class id atomically (ARCHITECTURE §4.5).
## A peer only receives spawns after it reports the level as loaded, so nobody gets packets for
## nodes that do not exist yet. Works offline too (spawns the local player as peer 1).
## Every peer also limits the synchronizers it owns (its player's ClientSync, the host's HostSync and
## level props) to peers that loaded this level.
## Authority: HOST (spawning) / every peer (visibility of its own synchronizers)
class_name PlayerSpawner
extends MultiplayerSpawner

const PLAYER_SCENE: PackedScene = preload("res://scenes/shared/player/player.tscn")
## Used offline or when a peer has no class (dev sandbox).
const FALLBACK_CLASS: StringName = &"profiler"

signal player_spawned(player: Player)

## Children (Marker3D / Node3D) are used as spawn positions, assigned by join order.
@export var spawn_points: Node3D

var _level_path: String = ""


func _ready() -> void:
	spawn_function = _spawn_player
	spawned.connect(_on_spawned)
	var level: Node = owner if owner != null else get_parent()
	_level_path = level.scene_file_path
	NetManager.level_loaded.connect(_on_level_loaded)
	_refresh_visibility()
	if multiplayer.is_server():
		NetManager.peer_left.connect(_on_peer_left)
		# Clients can finish loading before the host's own level is ready.
		for peer_id: int in NetManager.roster:
			if peer_id != 1 and NetManager.is_level_loaded(peer_id, _level_path):
				_on_level_loaded.call_deferred(peer_id, _level_path)
	NetManager.report_level_loaded.call_deferred(_level_path)


func get_player(peer_id: int) -> Player:
	var parent: Node = get_node_or_null(spawn_path)
	return parent.get_node_or_null(NodePath(_player_name(peer_id))) as Player if parent != null else null


# --- Host -------------------------------------------------------------------

func _on_level_loaded(peer_id: int, scene_path: String) -> void:
	if scene_path != _level_path:
		return
	if multiplayer.is_server() and get_player(peer_id) == null:
		var class_id: StringName = NetManager.get_class_id(peer_id)
		if not ClassCatalog.has(class_id):
			class_id = FALLBACK_CLASS
		var player: Player = spawn({
			"peer_id": peer_id,
			"class_id": class_id,
			"spawn_index": _spawn_index_for(peer_id),
		}) as Player
		player_spawned.emit(player)
	_refresh_visibility()


func _on_peer_left(peer_id: int) -> void:
	var player: Player = get_player(peer_id)
	if player != null:
		player.queue_free()  # despawn replicates to everyone


## Synchronizers we own in this level (HostSync, ClientSync, doors, props…) only replicate to peers that
## have loaded it; a peer still in the menu or loading would otherwise get packets for missing nodes.
## On the host, spawn visibility follows the same rule, so players spawn on a peer right after it loads.
func _refresh_visibility() -> void:
	var level: Node = owner if owner != null else get_parent()
	for node: Node in level.find_children("*", "MultiplayerSynchronizer", true, false):
		var sync: MultiplayerSynchronizer = node as MultiplayerSynchronizer
		if not sync.is_multiplayer_authority():
			continue
		sync.public_visibility = false
		for peer_id: int in multiplayer.get_peers():
			var should_see: bool = NetManager.is_level_loaded(peer_id, _level_path)
			if sync.get_visibility_for(peer_id) != should_see:
				sync.set_visibility_for(peer_id, should_see)


func _spawn_index_for(peer_id: int) -> int:
	var ids: Array[int] = NetManager.roster.keys()
	ids.sort()
	var index: int = ids.find(peer_id)
	return index if index >= 0 else 0


# --- All peers ----------------------------------------------------------------

func _spawn_player(data: Variant) -> Node:
	var info: Dictionary = data
	var peer_id: int = info.get("peer_id", 1)
	var class_id: StringName = info.get("class_id", FALLBACK_CLASS)
	var spawn_index: int = info.get("spawn_index", 0)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = _player_name(peer_id)
	player.peer_id = peer_id
	player.apply_class(ClassCatalog.get_data(class_id))
	player.position = _spawn_position(spawn_index)
	return player


func _on_spawned(node: Node) -> void:
	_refresh_visibility()
	var player: Player = node as Player
	if player != null:
		player_spawned.emit(player)


func _spawn_position(index: int) -> Vector3:
	if spawn_points == null or spawn_points.get_child_count() == 0:
		return Vector3(index * 1.5, 0.05, 0.0)
	var point: Node3D = spawn_points.get_child(index % spawn_points.get_child_count()) as Node3D
	return point.position if point != null else Vector3.ZERO


static func _player_name(peer_id: int) -> String:
	return "Player_%d" % peer_id
