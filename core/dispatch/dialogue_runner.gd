## Host-side execution engine for branching call dialogue graphs (GAMEPLAY_MECHANICS §5.6).
## Authority: HOST (drives node transitions and patience timers; replicated by CallDirector).
class_name DialogueRunner
extends RefCounted

signal node_entered(node: DialogueNode)
signal choices_updated(choices: Array[Dictionary])
signal patience_changed(current_patience: float, max_patience: float)
signal evidence_revealed(evidence_key: StringName)
signal event_triggered(event_name: StringName)
signal dialogue_finished(reason: StringName)

var graph: DialogueGraph = null
var current_node: DialogueNode = null
var current_node_id: StringName = &""
var time_in_node: float = 0.0
var is_active: bool = false

var max_patience: float = 180.0
var patience_remaining: float = 180.0

var revealed_evidence: Array[StringName] = []
var active_flags: Dictionary = {}


func start(p_graph: DialogueGraph, p_max_patience: float = 180.0, p_flags: Dictionary = {}) -> void:
	graph = p_graph
	max_patience = maxf(1.0, p_max_patience)
	patience_remaining = max_patience
	active_flags = p_flags.duplicate()
	revealed_evidence.clear()
	is_active = true
	
	if graph == null:
		is_active = false
		dialogue_finished.emit(&"invalid_graph")
		return
	
	var start_id: StringName = graph.initial_node_id
	if start_id == &"" and not graph.nodes.is_empty():
		start_id = graph.nodes[0].id
	
	_enter_node(start_id)


func tick(delta: float) -> void:
	if not is_active:
		return
	
	time_in_node += delta
	patience_remaining -= delta
	patience_changed.emit(patience_remaining, max_patience)
	
	if patience_remaining <= 0.0:
		patience_remaining = 0.0
		is_active = false
		dialogue_finished.emit(&"patience_depleted")
		return
	
	if current_node != null and current_node.choices.is_empty() and current_node.auto_next != &"":
		if current_node.auto_delay > 0.0 and time_in_node >= current_node.auto_delay:
			_enter_node(current_node.auto_next)


func select_choice(choice_index: int, player_class: StringName = &"") -> Dictionary:
	if not is_active:
		return {"success": false, "reason": "Dialogue is not active"}
	if current_node == null:
		return {"success": false, "reason": "No active node"}
	if choice_index < 0 or choice_index >= current_node.choices.size():
		return {"success": false, "reason": "Invalid choice index"}
	
	var choice: DialogueChoice = current_node.choices[choice_index]
	if choice == null:
		return {"success": false, "reason": "Choice is null"}
	
	# Class check
	if choice.required_class != &"" and player_class != &"" and choice.required_class != player_class:
		return {"success": false, "reason": "Choice requires class: %s" % choice.required_class}
	
	# Evidence check
	for req_ev in choice.required_evidence:
		if not req_ev in revealed_evidence:
			return {"success": false, "reason": "Missing required evidence: %s" % req_ev}
	
	# Apply patience modifier
	if choice.patience_delta != 0.0:
		modify_patience(choice.patience_delta)
	
	# Apply reveals
	for reveal_key in choice.reveals:
		add_revealed_evidence(reveal_key)
	
	var next_id: StringName = choice.next
	if next_id == &"" or (graph != null and not graph.has_node(next_id)):
		# End of dialogue path
		is_active = false
		dialogue_finished.emit(&"completed")
		return {"success": true, "reason": "Dialogue finished at end branch"}
	
	_enter_node(next_id)
	return {"success": true, "next_node": next_id}


func _enter_node(node_id: StringName) -> void:
	if graph == null:
		return
	
	var node: DialogueNode = graph.get_node(node_id)
	if node == null:
		is_active = false
		dialogue_finished.emit(&"completed")
		return
	
	current_node = node
	current_node_id = node_id
	time_in_node = 0.0
	
	for ev in node.on_enter_events:
		event_triggered.emit(ev)
	
	node_entered.emit(current_node)
	choices_updated.emit(get_available_choices_data())
	
	# If node has no choices and no auto_next, it's a terminal node
	if node.choices.is_empty() and node.auto_next == &"":
		# Allow reading line, or mark finished if instant
		if node.auto_delay <= 0.0:
			is_active = false
			dialogue_finished.emit(&"completed")


func get_available_choices_data(for_class: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current_node == null:
		return result
	
	for i in range(current_node.choices.size()):
		var c: DialogueChoice = current_node.choices[i]
		if c == null:
			continue
		
		var is_unlocked: bool = true
		var lock_reason: String = ""
		
		if c.required_class != &"" and for_class != &"" and c.required_class != for_class:
			is_unlocked = false
			lock_reason = "Requires %s" % c.required_class
		
		if is_unlocked:
			for req in c.required_evidence:
				if not req in revealed_evidence:
					is_unlocked = false
					lock_reason = "Missing evidence"
					break
		
		result.append({
			"index": i,
			"text": c.text,
			"required_class": c.required_class,
			"unlocked": is_unlocked,
			"lock_reason": lock_reason,
			"patience_delta": c.patience_delta,
		})
	
	return result


func modify_patience(delta_seconds: float) -> void:
	patience_remaining = clampf(patience_remaining + delta_seconds, 0.0, max_patience + 60.0)
	patience_changed.emit(patience_remaining, max_patience)
	if patience_remaining <= 0.0:
		is_active = false
		dialogue_finished.emit(&"patience_depleted")


func add_revealed_evidence(evidence_key: StringName) -> void:
	if evidence_key == &"":
		return
	if not evidence_key in revealed_evidence:
		revealed_evidence.append(evidence_key)
		evidence_revealed.emit(evidence_key)


func stop(reason: StringName = &"hangup") -> void:
	is_active = false
	dialogue_finished.emit(reason)
