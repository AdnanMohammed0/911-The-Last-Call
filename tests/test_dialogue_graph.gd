## P2-02: DialogueGraph lookup + validation and DialogueChoice availability.
extends GutTest


func _node(id: StringName, auto_next: StringName = &"") -> DialogueNode:
	var node: DialogueNode = DialogueNode.new()
	node.id = id
	node.auto_next = auto_next
	return node


func _choice(text: String, next: StringName, required_class: StringName = &"") -> DialogueChoice:
	var choice: DialogueChoice = DialogueChoice.new()
	choice.text = text
	choice.next = next
	choice.required_class = required_class
	return choice


func _errors(graph: DialogueGraph) -> String:
	var result: Dictionary = graph.validate()
	var errors: PackedStringArray = result["errors"]
	return " | ".join(errors)


func _warnings(graph: DialogueGraph) -> String:
	var result: Dictionary = graph.validate()
	var warnings: PackedStringArray = result["warnings"]
	return " | ".join(warnings)


func test_get_node_and_has_node() -> void:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [_node(&"start", &"end"), _node(&"end")]
	assert_true(graph.has_node(&"end"))
	assert_eq(graph.get_node(&"start").auto_next, &"end")
	assert_null(graph.get_node(&"missing"))


func test_add_node_is_found() -> void:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.add_node(_node(&"start"))
	assert_true(graph.has_node(&"start"))


func test_valid_graph_has_no_errors_or_warnings() -> void:
	var start: DialogueNode = _node(&"start")
	start.choices = [_choice("Where are you?", &"where"), _choice("[Profiler] Listen", &"listen", &"profiler")]
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [start, _node(&"where"), _node(&"listen")]
	assert_eq(_errors(graph), "")
	assert_eq(_warnings(graph), "")


func test_empty_graph_is_an_error() -> void:
	assert_string_contains(_errors(DialogueGraph.new()), "no nodes")


func test_missing_start_node_is_an_error() -> void:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.initial_node_id = &"intro"
	graph.nodes = [_node(&"start")]
	assert_string_contains(_errors(graph), "initial_node_id 'intro' does not exist")


func test_duplicate_ids_are_an_error() -> void:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [_node(&"start"), _node(&"start")]
	assert_string_contains(_errors(graph), "duplicate node id 'start'")


func test_dangling_choice_is_an_error() -> void:
	var start: DialogueNode = _node(&"start")
	start.choices = [_choice("Go", &"ghost")]
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [start]
	assert_string_contains(_errors(graph), "missing node 'ghost'")


func test_unknown_class_is_an_error() -> void:
	var start: DialogueNode = _node(&"start")
	start.choices = [_choice("Hack", &"end", &"wizard")]
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [start, _node(&"end")]
	assert_string_contains(_errors(graph), "unknown class 'wizard'")


func test_unreachable_node_is_a_warning() -> void:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.nodes = [_node(&"start"), _node(&"orphan")]
	assert_eq(_errors(graph), "")
	assert_string_contains(_warnings(graph), "'orphan' can never be reached")


func test_choice_available_by_class_and_evidence() -> void:
	var choice: DialogueChoice = _choice("Challenge", &"end", &"profiler")
	choice.required_evidence = [&"vsa_loop_laughter"]
	var none: Array[StringName] = []
	var found: Array[StringName] = [&"vsa_loop_laughter"]
	assert_false(choice.is_available_for(&"tech", found), "wrong class")
	assert_false(choice.is_available_for(&"profiler", none), "missing evidence")
	assert_true(choice.is_available_for(&"profiler", found))


func test_open_choice_available_to_everyone() -> void:
	var choice: DialogueChoice = _choice("Stay calm", &"end")
	var none: Array[StringName] = []
	assert_true(choice.is_available_for(&"medic", none))
