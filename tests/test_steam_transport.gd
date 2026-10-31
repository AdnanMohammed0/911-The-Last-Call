extends GutTest


func test_missing_steam_extension_does_not_change_offline_session() -> void:
	if NetManager.steam_available():
		pending("This machine has GodotSteam; use the two-account integration checklist")
		return
	assert_eq(NetManager.state, NetManager.State.OFFLINE)
	assert_eq(NetManager.host_steam_game("Tester"), ERR_UNAVAILABLE)
	assert_eq(NetManager.join_steam_lobby(123456789, "Tester"), ERR_UNAVAILABLE)
	assert_eq(NetManager.state, NetManager.State.OFFLINE)
	assert_eq(NetManager.steam_lobby_id, 0)
	assert_eq(NetManager.transport, NetManager.Transport.ENET)


func test_steam_invite_requires_active_lobby() -> void:
	assert_eq(NetManager.invite_steam_friends(), ERR_UNAVAILABLE)
