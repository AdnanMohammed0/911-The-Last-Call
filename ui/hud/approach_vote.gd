## Shared approach ballot shown during a response at Station 4.
extends CanvasLayer

const LABELS: Dictionary[StringName, String] = {
	&"code_3": "Code 3 — lights and sirens",
	&"silent": "Silent approach",
	&"on_foot": "On foot via back route",
	&"decoy": "Decoy cruiser",
}

var _vote_id: int = 0
var _panel: PanelContainer
var _status: Label
var _buttons: VBoxContainer
var _mouse_was_captured: bool = false


func _ready() -> void:
	layer = 90
	_build()
	VoteManager.vote_opened.connect(_on_vote_opened)
	VoteManager.vote_updated.connect(_on_vote_updated)
	VoteManager.vote_closed.connect(_on_vote_closed)
	for id: int in VoteManager.votes:
		var vote: Dictionary = VoteManager.votes[id]
		if vote.get("topic", &"") == VoteManager.APPROACH_TOPIC:
			_on_vote_opened(vote)
			break


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ApproachBallot"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(25, 95)
	_panel.custom_minimum_size = Vector2(365, 0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 7)
	_panel.add_child(column)
	var title: Label = Label.new()
	title.text = "CHOOSE THE TEAM APPROACH"
	column.add_child(title)
	_status = Label.new()
	column.add_child(_status)
	_buttons = VBoxContainer.new()
	column.add_child(_buttons)
	add_child(_panel)
	_panel.hide()


func _process(_delta: float) -> void:
	if _vote_id != 0 and _panel.visible:
		_status.text = "Vote closes in %d s" % ceili(VoteManager.get_time_left(_vote_id))


func _on_vote_opened(vote: Dictionary) -> void:
	if vote.get("topic", &"") != VoteManager.APPROACH_TOPIC:
		return
	_vote_id = str(vote["id"]).to_int()
	for child: Node in _buttons.get_children():
		child.queue_free()
	var options: Array = vote["options"]
	for raw_option: Variant in options:
		var option: StringName = StringName(str(raw_option))
		var button: Button = Button.new()
		button.text = LABELS.get(option, str(option))
		button.pressed.connect(_cast.bind(option))
		_buttons.add_child(button)
	_panel.show()
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _mouse_was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_on_vote_updated(vote)


func _on_vote_updated(vote: Dictionary) -> void:
	if str(vote.get("id", 0)).to_int() != _vote_id:
		return
	var ballots: Dictionary = vote.get("ballots", {})
	var mine: StringName = ballots.get(multiplayer.get_unique_id(), &"")
	for child: Node in _buttons.get_children():
		var button: Button = child as Button
		if button != null:
			button.disabled = mine != &""
			if mine != &"" and button.text == LABELS.get(mine, ""):
				button.text += "  ✓"


func _cast(option: StringName) -> void:
	if _vote_id != 0:
		VoteManager.cast_vote(_vote_id, option)


func _on_vote_closed(vote: Dictionary, _result: StringName) -> void:
	if str(vote.get("id", 0)).to_int() != _vote_id:
		return
	_vote_id = 0
	_panel.hide()
	if _mouse_was_captured and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_was_captured = false
