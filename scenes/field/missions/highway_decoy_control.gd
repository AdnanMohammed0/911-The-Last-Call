## Roadside uplink for the empty cruiser. Only the Tech may divert it online.
class_name HighwayDecoyControl
extends Interactable

@export var set_piece: HighwayRpgSetPiece


func _ready() -> void:
	super()
	prompt_text = "Tech: divert empty cruiser"
	hold_duration = 1.5
	max_distance = 3.0


func is_available_to(peer_id: int) -> bool:
	return super(peer_id) and MissionDirector.mission_kind != &"assist" and set_piece != null and set_piece.is_armed()


func _can_interact(peer_id: int) -> bool:
	return set_piece != null and set_piece.is_armed() and not set_piece.is_resolved() \
		and (not NetManager.is_online() or NetManager.get_class_id(peer_id) == &"tech")


func _on_interact(_peer_id: int) -> void:
	set_piece.divert_cruiser()
