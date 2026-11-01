## Hold-to-revive area on a downed player's body (GAMEPLAY_MECHANICS §3.1).
## Medic: 4 s. Anyone else needs a Trauma Kit: 8 s (consumes one). Bleed-out pauses while someone holds.
## Authority: HOST (Interactable validation; HealthComponent.revive)
class_name ReviveInteractable
extends Interactable

const MEDIC_REVIVE_SEC: float = 4.0
const TRAUMA_KIT_REVIVE_SEC: float = 8.0

@onready var _player: Player = get_parent() as Player
@onready var _health: HealthComponent = $"../Health"


func _ready() -> void:
	super()
	prompt_text = "Revive"
	max_distance = 2.2
	cooldown = 0.5
	holder_changed.connect(_on_holder_changed)
	NetManager.peer_left.connect(_on_reviver_gone)
	NetManager.peer_dropped.connect(_on_reviver_gone)


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or holder_peer == 0:
		return
	var reviver: Player = Player.find_by_peer(get_tree(), holder_peer)
	if _is_hold_stale() or reviver == null or not reviver.get_health().is_alive() \
			or reviver.global_position.distance_to(global_position) > max_distance + 0.5:
		_set_holder.rpc(0)


func get_prompt_text() -> String:
	return "Revive %s" % NetManager.get_player_name(_player.peer_id)


func get_hold_duration_for(peer_id: int) -> float:
	return MEDIC_REVIVE_SEC if NetManager.get_class_id(peer_id) == &"medic" else TRAUMA_KIT_REVIVE_SEC


func is_available_to(peer_id: int) -> bool:
	if not _health.is_downed() or peer_id == _player.peer_id:
		return false
	var reviver: Player = Player.find_by_peer(get_tree(), peer_id)
	if reviver == null or not reviver.get_health().is_alive():
		return false
	if NetManager.get_class_id(peer_id) != &"medic" and reviver.trauma_kits <= 0:
		return false
	return super(peer_id)


func _on_interact(peer_id: int) -> void:
	var reviver: Player = Player.find_by_peer(get_tree(), peer_id)
	if reviver != null and NetManager.get_class_id(peer_id) != &"medic":
		reviver.trauma_kits = maxi(reviver.trauma_kits - 1, 0)
	_health.revive(peer_id)


func _on_holder_changed(peer_id: int) -> void:
	if multiplayer.is_server():
		_health.reviver_peer = peer_id


func _on_reviver_gone(peer_id: int) -> void:
	if multiplayer.is_server() and holder_peer == peer_id:
		_set_holder.rpc(0)
