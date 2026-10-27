extends GutTest

const DirectorScript := preload("res://autoload/call_director.gd")

var _saved_roster: Dictionary[int, Dictionary]
var _saved_state: int
var _saved_owner: int


func before_each() -> void:
	_saved_roster = NetManager.roster.duplicate(true)
	_saved_state = CallDirector.current_state
	_saved_owner = CallDirector.handset_owner_peer_id
	NetManager.roster[1] = {"name": "Ali", "class_id": &"tech"}
	NetManager.roster[2] = {"name": "Adnan", "class_id": &"profiler"}


func after_each() -> void:
	NetManager.roster = _saved_roster
	CallDirector.current_state = _saved_state
	CallDirector.handset_owner_peer_id = _saved_owner


func test_handset_can_only_be_taken_from_desk_and_passed_to_teammate() -> void:
	var director: DirectorScript = DirectorScript.new()
	add_child_autofree(director)
	director.current_state = director.CallState.CONNECTED
	director.request_take_handset()
	assert_eq(director.handset_owner_peer_id, 1)
	director.request_pass_handset(999)
	assert_eq(director.handset_owner_peer_id, 1)
	director.request_pass_handset(2)
	assert_eq(director.handset_owner_peer_id, 2)
	director.request_take_handset()
	assert_eq(director.handset_owner_peer_id, 2)


func test_ping_requires_valid_choice_and_updates_only_once_per_choice() -> void:
	var director: DirectorScript = DirectorScript.new()
	add_child_autofree(director)
	var graph: DialogueGraph = DialogueGraph.new()
	var root: DialogueNode = DialogueNode.new()
	root.id = &"root"
	var choice: DialogueChoice = DialogueChoice.new()
	choice.text = "Ask for the address"
	root.choices = [choice]
	graph.initial_node_id = &"root"
	graph.nodes = [root]
	director.current_state = director.CallState.CONNECTED
	director.handset_owner_peer_id = 2
	director.dialogue_runner.start(graph)
	var pings: Array[Vector2i] = []
	EventBus.dialogue_choice_pinged.connect(func(peer_id: int, index: int) -> void: pings.append(Vector2i(peer_id, index)))
	director.request_ping_choice(7)
	director.request_ping_choice(0)
	director.request_ping_choice(0)
	assert_eq(pings, [Vector2i(1, 0)])


func test_terminal_shows_suggestions_and_owner_pass_controls() -> void:
	CallDirector.current_state = CallDirector.CallState.CONNECTED
	CallDirector.handset_owner_peer_id = 1
	var terminal: DispatchTerminal = DispatchTerminal.new()
	add_child_autofree(terminal)
	terminal._on_dialogue_node(&"root", &"caller", "Help me", [{"index": 0, "text": "Where are you?", "unlocked": true, "required_class": &""}])
	terminal._on_choice_pinged(2, 0)
	var choice_text: String = ""
	for child: Node in terminal._choices.get_children():
		if child is Label:
			choice_text += (child as Label).text
	assert_true(choice_text.contains("TEAM SUGGESTS: ADNAN"))
	assert_eq(terminal._pass_choices.get_child_count(), 1)
	assert_true((terminal._pass_choices.get_child(0) as Button).text.contains("Adnan"))
	CallDirector.handset_owner_peer_id = 2
	terminal._refresh()
	var suggest_count: int = 0
	for child: Node in terminal._choices.get_children():
		if child is Button and (child as Button).text.contains("SUGGEST"):
			suggest_count += 1
	assert_eq(suggest_count, 1)
	await get_tree().process_frame
