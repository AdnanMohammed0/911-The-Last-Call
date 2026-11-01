extends GutTest


class FakeSteam:
	extends RefCounted
	var unlocked: Dictionary[String, bool] = {}
	var stored: int = 0
	var presence: Dictionary[String, String] = {}
	var fail_get: bool = false

	func getAchievement(id: String) -> Dictionary:
		if fail_get:
			return {"ret": false}
		return {"ret": true, "achieved": unlocked.has(id)}

	func setAchievement(id: String) -> bool:
		unlocked[id] = true
		return true

	func storeStats() -> bool:
		stored += 1
		return true

	func setRichPresence(key: String, value: String) -> bool:
		presence[key] = value
		return true


var _original_steam: Object


func before_each() -> void:
	_original_steam = SteamworksService._steam
	SteamworksService._steam = FakeSteam.new()
	SteamworksService._unlocked_this_session.clear()
	SteamworksService._pending_unlocks.clear()
	SteamworksService._stats_ready = true


func after_each() -> void:
	SteamworksService._steam = _original_steam
	SteamworksService._unlocked_this_session.clear()
	SteamworksService._pending_unlocks.clear()
	SteamworksService._stats_ready = true


func test_mission_achievement_is_stored_only_once() -> void:
	var fake: FakeSteam = SteamworksService._steam as FakeSteam
	SteamworksService._on_event_recorded({"id": &"mission_success"})
	SteamworksService._on_event_recorded({"id": &"mission_success"})
	assert_true(fake.unlocked.has("FIRST_RESPONSE"))
	assert_eq(fake.stored, 1)


func test_arrest_achievement_requires_local_peer() -> void:
	var fake: FakeSteam = SteamworksService._steam as FakeSteam
	SteamworksService._on_event_recorded({"id": &"suspect_arrested", "payload": {"peer_id": 99999}})
	assert_false(fake.unlocked.has("FIRST_ARREST"))
	SteamworksService._on_event_recorded({"id": &"suspect_arrested", "payload": {"peer_id": multiplayer.get_unique_id()}})
	assert_true(fake.unlocked.has("FIRST_ARREST"))


func test_presence_exposes_lobby_join_command_only_in_steam_lobby() -> void:
	var fake: FakeSteam = SteamworksService._steam as FakeSteam
	var previous: int = NetManager.steam_lobby_id
	NetManager.steam_lobby_id = 7654321
	SteamworksService._update_presence()
	assert_eq(str(fake.presence.get("connect", "")), "+connect_lobby 7654321")
	NetManager.steam_lobby_id = 0
	SteamworksService._update_presence()
	assert_eq(str(fake.presence.get("connect", "x")), "")
	NetManager.steam_lobby_id = previous


func test_failed_stats_lookup_keeps_achievement_queued() -> void:
	var fake: FakeSteam = SteamworksService._steam as FakeSteam
	SteamworksService._stats_ready = false
	assert_false(SteamworksService._unlock(SteamworksService.ACH_FIRST_RESPONSE))
	assert_true(SteamworksService._pending_unlocks.has(SteamworksService.ACH_FIRST_RESPONSE))
	fake.fail_get = true
	SteamworksService._on_stats_ready(0, 1, 0)
	assert_true(SteamworksService._pending_unlocks.has(SteamworksService.ACH_FIRST_RESPONSE))
	assert_false(fake.unlocked.has(SteamworksService.ACH_FIRST_RESPONSE))
	fake.fail_get = false
	SteamworksService._process(SteamworksService.UNLOCK_RETRY_SEC + 0.1)
	assert_false(SteamworksService._pending_unlocks.has(SteamworksService.ACH_FIRST_RESPONSE))
	assert_true(fake.unlocked.has(SteamworksService.ACH_FIRST_RESPONSE))
