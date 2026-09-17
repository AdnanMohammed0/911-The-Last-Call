extends GutTest

## Automated unit tests for DialogueGraphEditor plugin and data layer (P2-03).

@warning_ignore_start("unsafe_call_argument")
@warning_ignore_start("unsafe_cast")
@warning_ignore_start("unsafe_method_access")
@warning_ignore_start("unsafe_property_access")
@warning_ignore_start("untyped_declaration")

const SAMPLE_DIALOGUE_PATH: String = "res://data/dialogue/sample_call_dialogue.tres"
const DialogueGraphViewScript := preload("res://addons/dialogue_editor/dialogue_graph_view.gd")
const DialogueGraphNodeScript := preload("res://addons/dialogue_editor/dialogue_graph_node.gd")


func test_dialogue_node_and_graph_data_layer() -> void:
	var node: DialogueNode = DialogueNode.new()
	node.id = &"test_node"
	node.speaker = &"caller"
	node.line = "Testing spoken line"
	node.editor_position = Vector2(120, 240)
	
	assert_eq(node.id, &"test_node", "Node ID should be set")
	assert_eq(node.editor_position, Vector2(120, 240), "Editor position should be set")
	
	var choice: DialogueChoice = DialogueChoice.new()
	choice.text = "Option A"
	choice.next = &"next_node"
	choice.required_class = &"profiler"
	choice.required_evidence = [&"evidence_loop_detected"]
	choice.patience_delta = 10.0
	choice.reveals = [&"clue_caller_feigning_panic"]
	node.choices.append(choice)
	
	assert_eq(node.choices.size(), 1, "Node should have 1 choice")
	assert_eq(choice.required_class, &"profiler", "Required class should be profiler")
	
	var graph: DialogueGraph = DialogueGraph.new()
	graph.initial_node_id = &"test_node"
	graph.add_node(node)
	
	assert_true(graph.has_node(&"test_node"), "Graph should have test_node")
	assert_eq(graph.get_node(&"test_node"), node, "get_node should return node")
	
	graph.remove_node(&"test_node")
	assert_false(graph.has_node(&"test_node"), "Node should be removed from graph")


func test_sample_call_dialogue_resource() -> void:
	var graph: DialogueGraph = ResourceLoader.load(SAMPLE_DIALOGUE_PATH) as DialogueGraph
	assert_not_null(graph, "Sample dialogue resource should load successfully")
	if graph == null:
		return
	
	assert_eq(graph.initial_node_id, &"start", "Initial node should be 'start'")
	assert_eq(graph.nodes.size(), 8, "Sample dialogue should have 8 nodes")
	
	var val_res: Dictionary = graph.validate_graph()
	assert_true(val_res.get("valid", false) == true, "Sample dialogue graph should be fully valid")
	
	# Verify start node and class requirements
	var start_node: DialogueNode = graph.get_node(&"start")
	assert_not_null(start_node, "Start node must exist")
	assert_eq(start_node.choices.size(), 3, "Start node should have 3 choices")
	
	var profiler_choice: DialogueChoice = start_node.choices[1]
	assert_eq(profiler_choice.required_class, &"profiler", "Second choice must require profiler class")
	assert_eq(profiler_choice.patience_delta, 10.0, "Profiler choice adds 10s patience")
	assert_true(profiler_choice.reveals.has(&"clue_caller_feigning_panic"), "Reveals feigning panic clue")
	
	# Verify evidence requirement on loop tag
	var prof_node: DialogueNode = graph.get_node(&"profiler_interrogate")
	assert_not_null(prof_node, "profiler_interrogate node must exist")
	assert_eq(prof_node.choices[0].required_evidence, [&"evidence_loop_detected"], "Loop choice requires loop evidence")


func test_dialogue_graph_view_load_and_rebuild() -> void:
	var view: Control = DialogueGraphViewScript.new()
	add_child_autofree(view)
	
	var graph: DialogueGraph = ResourceLoader.load(SAMPLE_DIALOGUE_PATH) as DialogueGraph
	view.call("load_graph", graph, SAMPLE_DIALOGUE_PATH)
	
	assert_eq(view.get("dialogue_graph"), graph, "View should hold loaded graph")
	assert_eq(view.get("current_file_path"), SAMPLE_DIALOGUE_PATH, "File path should be stored")
	assert_false(view.get("is_dirty"), "Newly loaded graph should not be dirty")
	
	# Verify visual nodes created in GraphEdit
	var visual_nodes_count: int = 0
	var ge: GraphEdit = view.get("_graph_edit") as GraphEdit
	for child: Node in ge.get_children():
		if child is GraphNode:
			visual_nodes_count += 1
	
	assert_eq(visual_nodes_count, 8, "GraphEdit should contain 8 visual GraphNode widgets")


func test_connection_and_disconnection_flow() -> void:
	var view: Control = DialogueGraphViewScript.new()
	add_child_autofree(view)
	
	# Start with new graph
	view.call("new_graph")
	var g: DialogueGraph = view.get("dialogue_graph") as DialogueGraph
	assert_eq(g.nodes.size(), 1, "New graph starts with 1 node")
	
	# Add second node
	var n2: DialogueNode = view.call("add_new_node", &"outcome_node", Vector2(400, 100)) as DialogueNode
	assert_not_null(n2, "Second node should be created")
	assert_eq(g.nodes.size(), 2, "Graph should now have 2 nodes")
	
	# Add choice to start node
	var start_node: DialogueNode = g.get_node(&"start")
	var choice: DialogueChoice = view.call("add_choice_to_node", start_node) as DialogueChoice
	assert_not_null(choice, "Choice should be added to start node")
	assert_eq(choice.next, &"", "Choice next starts empty")
	
	# Simulate connection request from choice 0 to n2
	var nmap: Dictionary = view.get("_nodes_map")
	var from_gn: GraphNode = nmap[&"start"] as GraphNode
	var to_gn: GraphNode = nmap[&"outcome_node"] as GraphNode
	view.call("_on_connection_request", StringName(from_gn.name), 0, StringName(to_gn.name), 0)
	
	assert_eq(choice.next, &"outcome_node", "Connecting port should update choice.next to target ID")
	assert_true(view.get("is_dirty"), "Graph should be marked dirty after connection")
	
	# Simulate disconnection
	view.call("_on_disconnection_request", StringName(from_gn.name), 0, StringName(to_gn.name), 0)
	assert_eq(choice.next, &"", "Disconnecting port should clear choice.next")


func test_node_deletion_and_auto_layout() -> void:
	var view: Control = DialogueGraphViewScript.new()
	add_child_autofree(view)
	
	var graph: DialogueGraph = ResourceLoader.load(SAMPLE_DIALOGUE_PATH) as DialogueGraph
	view.call("load_graph", graph, SAMPLE_DIALOGUE_PATH)
	
	# Run auto layout
	view.call("auto_layout_nodes")
	var start_pos: Vector2 = graph.get_node(&"start").editor_position
	assert_true(start_pos.x > 0 and start_pos.y > 0, "Auto-layout should position start node in grid")
	
	# Delete a node
	view.call("delete_node", &"hasty_dispatch")
	var g: DialogueGraph = view.get("dialogue_graph") as DialogueGraph
	assert_false(g.has_node(&"hasty_dispatch"), "hasty_dispatch should be deleted from graph")
	assert_eq(g.nodes.size(), 7, "Graph should have 7 nodes remaining")


func test_graph_validation_catches_broken_references() -> void:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.initial_node_id = &"missing_start"
	
	var node1: DialogueNode = DialogueNode.new()
	node1.id = &"node_a"
	var broken_choice: DialogueChoice = DialogueChoice.new()
	broken_choice.text = "Jump into nowhere"
	broken_choice.next = &"nonexistent_target"
	node1.choices.append(broken_choice)
	graph.add_node(node1)
	
	var report: Dictionary = graph.validate_graph()
	assert_false(report.get("valid", true) == true, "Graph with broken links should fail validation")
	var errors: Array = report.get("errors", [])
	assert_true(errors.size() >= 2, "Should report at least 2 errors (missing initial node & missing target ID)")
