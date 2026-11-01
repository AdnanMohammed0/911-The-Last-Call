## Optional Steam achievements and rich presence. NetManager owns Steam initialization/callbacks.
## Steam Auto-Cloud syncs the existing user:// profiles at app launch/exit (see STEAM_RELEASE.md).
extends Node

const ACH_FIRST_RESPONSE: String = "FIRST_RESPONSE"
const ACH_TEN_RESPONSES: String = "TEN_RESPONSES"
const ACH_FIRST_ARREST: String = "FIRST_ARREST"
const ACH_CAPTAIN: String = "CAPTAIN"
const UNLOCK_RETRY_SEC: float = 10.0

var _steam: Object = null
var _unlocked_this_session: Dictionary[String, bool] = {}
var _stats_ready: bool = true
var _pending_unlocks: Dictionary[String, bool] = {}
var _pending_store: bool = false
var _unlock_retry_elapsed: float = 0.0


func _ready() -> void:
	_steam = NetManager.get_steam_api()
	if _steam == null:
		return
	if _steam.has_signal(&"current_stats_received"):
		_stats_ready = false
		_steam.connect(&"current_stats_received", _on_stats_ready)
	if _steam.has_method(&"requestCurrentStats"):
		_steam.call(&"requestCurrentStats")
	Career.xp_changed.connect(_on_career_changed)
	FlagSystem.event_recorded.connect(_on_event_recorded)
	EventBus.phase_changed.connect(_on_phase_changed)
	NetManager.steam_lobby_changed.connect(_on_lobby_changed)
	NetManager.session_ended.connect(func(_reason: String) -> void: _update_presence())
	_on_career_changed(Career.xp, Career.rank())
	_update_presence()


func _exit_tree() -> void:
	_flush_stats()


func _process(delta: float) -> void:
	if _steam == null or not _stats_ready or _pending_unlocks.is_empty():
		_unlock_retry_elapsed = 0.0
		return
	_unlock_retry_elapsed += delta
	if _unlock_retry_elapsed >= UNLOCK_RETRY_SEC:
		_unlock_retry_elapsed = 0.0
		_retry_pending_unlocks()


func _on_career_changed(_xp: int, rank: int) -> void:
	if _steam == null:
		return
	if rank >= 6:
		_unlock(ACH_CAPTAIN)
	if Career.stats.get("missions", 0) >= 10:
		_unlock(ACH_TEN_RESPONSES)


func _on_event_recorded(event: Dictionary) -> void:
	if _steam == null:
		return
	match StringName(str(event.get("id", &""))):
		&"mission_success":
			_unlock(ACH_FIRST_RESPONSE)
		&"suspect_arrested":
			var payload: Dictionary = event.get("payload", {})
			if str(payload.get("peer_id", 0)).to_int() == multiplayer.get_unique_id():
				_unlock(ACH_FIRST_ARREST)


func _unlock(achievement_id: String) -> bool:
	_flush_stats()
	if _steam == null or _unlocked_this_session.has(achievement_id):
		return false
	if not _stats_ready:
		_pending_unlocks[achievement_id] = true
		return false
	var state: Dictionary = _steam.call(&"getAchievement", achievement_id)
	if not state.get("ret", false):
		return false
	if state.get("achieved", false):
		_flush_stats()
		_unlocked_this_session[achievement_id] = true
		_pending_unlocks.erase(achievement_id)
		return true
	if _steam.call(&"setAchievement", achievement_id) != true:
		return false
	_pending_store = true
	_flush_stats()
	_unlocked_this_session[achievement_id] = true
	_pending_unlocks.erase(achievement_id)
	return true


func _on_stats_ready(_game: int, result: int, _user: int) -> void:
	if result != 1:
		return
	_stats_ready = true
	_retry_pending_unlocks()


func _retry_pending_unlocks() -> void:
	for achievement_id: String in _pending_unlocks.keys():
		_unlock(achievement_id)


func _flush_stats() -> void:
	if _steam != null and _pending_store and _steam.call(&"storeStats") == true:
		_pending_store = false


func _on_phase_changed(_phase: StringName) -> void:
	_update_presence()


func _on_lobby_changed(_lobby_id: int) -> void:
	_update_presence()


func _update_presence() -> void:
	if _steam == null:
		return
	var phase: StringName = GameState.phase_name(GameState.phase)
	var label: String = "On a field response" if phase == &"field" else "At Station 4"
	if phase == &"ending":
		label = "Shift complete"
	_steam.call(&"setRichPresence", "status", label)
	_steam.call(&"setRichPresence", "steam_display", "#status_field" if phase == &"field" else "#status_station")
	var lobby_id: int = NetManager.steam_lobby_id
	_steam.call(&"setRichPresence", "connect", "+connect_lobby %d" % lobby_id if lobby_id > 0 else "")
