## Complete branching dialogue tree for an emergency call (GAMEPLAY_MECHANICS §5.6).
class_name DialogueGraph
extends Resource

## Starting node identifier when the call is answered.
@export var initial_node_id: StringName = &"start"
## All nodes comprising this graph.
@export var nodes: Array[DialogueNode] = []

var _nodes_by_id: Dictionary[StringName, DialogueNode] = {}
var _cache_valid: bool = false


func _rebuild_cache() -> void:
	_nodes_by_id.clear()
	for node in nodes:
		if node != null and node.id != &"":
			_nodes_by_id[node.id] = node
	_cache_valid = true


func get_node(node_id: StringName) -> DialogueNode:
	if not _cache_valid or _nodes_by_id.size() != nodes.size():
		_rebuild_cache()
	return _nodes_by_id.get(node_id, null)


func add_node(node: DialogueNode) -> void:
	if node == null:
		return
	nodes.append(node)
	if node.id != &"":
		_nodes_by_id[node.id] = node


func has_node(node_id: StringName) -> bool:
	if not _cache_valid or _nodes_by_id.size() != nodes.size():
		_rebuild_cache()
	return _nodes_by_id.has(node_id)
