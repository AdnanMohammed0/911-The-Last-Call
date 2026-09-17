## Station 4 garage door: while a response is open, holding interact deploys the whole team to the mission
## map (MissionDirector.deploy). Locked otherwise.
## Authority: HOST
class_name DeployDoor
extends Interactable


func _ready() -> void:
	super._ready()
	hold_duration = 1.5
	max_distance = 3.0
	MissionDirector.state_changed.connect(func(_state: int) -> void: _refresh_light())
	_refresh_light()


func get_prompt_text() -> String:
	if MissionDirector.state == MissionDirector.State.RESPONSE:
		return "Deploy to %s" % MissionDirector.mission_name()
	return "Garage locked — no active response"


func _can_interact(_peer_id: int) -> bool:
	return MissionDirector.state == MissionDirector.State.RESPONSE


func _on_interact(_peer_id: int) -> void:
	MissionDirector.deploy()


func _refresh_light() -> void:
	var lamp: OmniLight3D = get_node_or_null(^"StatusLight") as OmniLight3D
	if lamp != null:
		var open: bool = MissionDirector.state == MissionDirector.State.RESPONSE
		lamp.light_color = Color(0.3, 1.0, 0.45) if open else Color(1.0, 0.25, 0.2)
