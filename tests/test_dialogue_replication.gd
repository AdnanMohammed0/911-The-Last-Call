extends GutTest

@warning_ignore_start("unsafe_call_argument")
@warning_ignore_start("unsafe_cast")

const CallDirectorScript := preload("res://autoload/call_director.gd")

var _director: CallDirectorScript


func before_each() -> void:
	_director = CallDirectorScript.new()
	add_child_autofree(_director)
	_director.reset()


func _create_branching_dialogue() -> DialogueGraph:
	var graph: DialogueGraph = DialogueGraph.new()
	graph.initial_node_id = &"root"
	
	# Root node with 2 choices
	var node_root: DialogueNode = DialogueNode.new()
	node_root.id = &"root"
	node_root.speaker = &"caller"
	node_root.line = "Help me! Someone is trying to break in!"
	
	var c1: DialogueChoice = DialogueChoice.new()
	c1.text = "Stay calm, where are you located?"
	c1.next = &"node_calm"
	c1.patience_delta = 15.0
	c1.reveals = [&"evidence_address_given"]
	
	var c2_profiler: DialogueChoice = DialogueChoice.new()
	c2_profiler.text = "[Profiler] I hear laughter in your background, who is with you?"
	c2_profiler.next = &"node_confront"
	c2_profiler.required_class = &"profiler"
	c2_profiler.patience_delta = -10.0
	
	node_root.choices = [c1, c2_profiler]
	
	# Node calm
	var node_calm: DialogueNode = DialogueNode.new()
	node_calm.id = &"node_calm"
	node_calm.speaker = &"caller"
	node_calm.line = "I am at 404 Elm Street, hurry please!"
	
	# Node confront (requires evidence from choice 1 to unlock follow up)
	var node_confront: DialogueNode = DialogueNode.new()
	node_confront.id = &"node_confront"
	node_confront.speaker = &"caller"
	node_confront.line = "...You figured it out. It's just a prank."
	
	graph.nodes = [node_root, node_calm, node_confront]
	return graph


func test_dialogue_runner_linear_progression() -> void:
	var runner: DialogueRunner = DialogueRunner.new()
	var graph: DialogueGraph = _create_branching_dialogue()
	
	runner.start(graph, 100.0)
	assert_true(runner.is_active)
	assert_eq(runner.current_node_id, &"root")
	assert_eq(runner.patience_remaining, 100.0)
	
	# Select choice 0 ("Stay calm")
	var res: Dictionary = runner.select_choice(0)
	assert_true(res["success"])
	assert_eq(runner.current_node_id, &"node_calm")
	assert_eq(runner.patience_remaining, 115.0) # +15 patience
	assert_true(runner.revealed_evidence.has(&"evidence_address_given"))


func test_dialogue_runner_class_locked_choices() -> void:
	var runner: DialogueRunner = DialogueRunner.new()
	var graph: DialogueGraph = _create_branching_dialogue()
	
	runner.start(graph, 100.0)
	
	# Tech trying to select profiler-exclusive choice (choice 1)
	var res_invalid: Dictionary = runner.select_choice(1, &"tech")
	assert_false(res_invalid["success"])
	assert_eq(runner.current_node_id, &"root") # Remains at root
	
	# Profiler selecting choice 1
	var res_valid: Dictionary = runner.select_choice(1, &"profiler")
	assert_true(res_valid["success"])
	assert_eq(runner.current_node_id, &"node_confront")
	assert_eq(runner.patience_remaining, 90.0) # -10 patience


func test_dialogue_runner_patience_depletion() -> void:
	var runner: DialogueRunner = DialogueRunner.new()
	var graph: DialogueGraph = _create_branching_dialogue()
	
	var finished_reason: StringName = &""
	runner.dialogue_finished.connect(func(reason: StringName) -> void: finished_reason = reason)
	
	runner.start(graph, 10.0)
	runner.tick(12.0)
	
	assert_false(runner.is_active)
	assert_eq(runner.patience_remaining, 0.0)
	assert_eq(finished_reason, &"patience_depleted")


func test_handset_token_ownership_lifecycle() -> void:
	assert_eq(_director.handset_owner_peer_id, 0)
	assert_true(_director.has_handset(1))
	assert_true(_director.has_handset(2)) # Open when 0
	
	# Peer 2 takes handset
	_director.handset_owner_peer_id = 2
	assert_eq(_director.handset_owner_peer_id, 2)
	assert_false(_director.has_handset(1))
	assert_true(_director.has_handset(2))
	
	# Peer 2 passes to peer 3
	_director.handset_owner_peer_id = 3
	assert_eq(_director.handset_owner_peer_id, 3)
	assert_false(_director.has_handset(2))
	assert_true(_director.has_handset(3))
	
	# Release handset back to desk (0)
	_director.handset_owner_peer_id = 0
	assert_eq(_director.handset_owner_peer_id, 0)
	assert_true(_director.has_handset(1))


func test_handset_release_on_peer_disconnect() -> void:
	_director.handset_owner_peer_id = 4
	assert_eq(_director.handset_owner_peer_id, 4)
	
	# Simulating player_left event for peer 4
	_director._on_player_left(4)
	assert_eq(_director.handset_owner_peer_id, 0)
