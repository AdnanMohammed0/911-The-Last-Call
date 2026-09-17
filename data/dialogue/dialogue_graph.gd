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


func remove_node(node_id: StringName) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if nodes[i] != null and nodes[i].id == node_id:
			nodes.remove_at(i)
	_rebuild_cache()


func has_node(node_id: StringName) -> bool:
	if not _cache_valid or _nodes_by_id.size() != nodes.size():
		_rebuild_cache()
	return _nodes_by_id.has(node_id)


## Checks the graph for authoring mistakes. Returns {"errors": PackedStringArray, "warnings": PackedStringArray}.
## Errors break the call at runtime (missing start node, links to nodes that do not exist, duplicate ids).
## Warnings are suspicious but playable (unreachable nodes, empty choice text).
func validate() -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()
	var ids: Dictionary[StringName, bool] = {}

	# 1) Every node needs a unique, non-empty id.
	for i: int in nodes.size():
		var node: DialogueNode = nodes[i]
		if node == null:
			errors.append("node #%d is empty (null)" % i)
			continue
		if node.id == &"":
			errors.append("node #%d has no id" % i)
		elif ids.has(node.id):
			errors.append("duplicate node id '%s'" % node.id)
		else:
			ids[node.id] = true

	# 2) The start node must exist.
	if nodes.is_empty():
		errors.append("graph has no nodes")
		return {"errors": errors, "warnings": warnings}
	if not ids.has(initial_node_id):
		errors.append("initial_node_id '%s' does not exist" % initial_node_id)

	# 3) Every link (choice.next / auto_next) must point to an existing node.
	for node: DialogueNode in nodes:
		if node == null or node.id == &"":
			continue
		if node.auto_next != &"" and not ids.has(node.auto_next):
			errors.append("node '%s': auto_next '%s' does not exist" % [node.id, node.auto_next])
		if not node.choices.is_empty() and node.auto_next != &"":
			warnings.append("node '%s' has choices and auto_next; auto_next is ignored while choices exist" % node.id)
		for c: int in node.choices.size():
			var choice: DialogueChoice = node.choices[c]
			if choice == null:
				errors.append("node '%s': choice #%d is empty (null)" % [node.id, c])
				continue
			if choice.text.strip_edges().is_empty():
				warnings.append("node '%s': choice #%d has no text" % [node.id, c])
			if choice.next == &"":
				errors.append("node '%s': choice '%s' has no next node" % [node.id, choice.text])
			elif not ids.has(choice.next):
				errors.append("node '%s': choice '%s' points to missing node '%s'" % [node.id, choice.text, choice.next])
			if choice.required_class != &"" and not ClassCatalog.has(choice.required_class):
				errors.append("node '%s': choice '%s' requires unknown class '%s'" % [node.id, choice.text, choice.required_class])

	# 4) Nodes nobody can reach from the start were probably forgotten.
	if ids.has(initial_node_id):
		var reachable: Dictionary[StringName, bool] = {}
		var stack: Array[StringName] = [initial_node_id]
		while not stack.is_empty():
			var current: StringName = stack.pop_back()
			if reachable.has(current) or not ids.has(current):
				continue
			reachable[current] = true
			var node: DialogueNode = get_node(current)
			if node.auto_next != &"":
				stack.append(node.auto_next)
			for choice: DialogueChoice in node.choices:
				if choice != null and choice.next != &"":
					stack.append(choice.next)
		for id: StringName in ids:
			if not reachable.has(id):
				warnings.append("node '%s' can never be reached from '%s'" % [id, initial_node_id])

	return {"errors": errors, "warnings": warnings}


## Compatibility helper for DialogueGraphEditor
func validate_graph() -> Dictionary:
	var res: Dictionary = validate()
	var errs: PackedStringArray = res.get("errors", PackedStringArray())
	return {
		"valid": errs.is_empty(),
		"errors": Array(errs),
		"warnings": Array(res.get("warnings", PackedStringArray()))
	}
