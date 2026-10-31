extends GutTest


class FakeRelaySteam:
	extends RefCounted
	var status_code: int = 100

	func getRelayNetworkStatus() -> int:
		return status_code


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


func test_relay_readiness_labels_do_not_claim_a_connection_route() -> void:
	assert_eq(NetManager.relay_availability_label(100), "ready")
	assert_eq(NetManager.relay_availability_label(3), "connecting")
	assert_eq(NetManager.relay_availability_label(-101), "failed")
	assert_eq(NetManager.relay_availability_label(999), "unknown")
	var previous: Object = NetManager._steam
	var fake: FakeRelaySteam = FakeRelaySteam.new()
	NetManager._steam = fake
	assert_eq(NetManager.steam_relay_status(), "ready")
	fake.status_code = -100
	assert_eq(NetManager.steam_relay_status(), "connection lost")
	NetManager._steam = previous


func test_debug_report_identifies_steam_without_enet_statistics() -> void:
	var previous: NetManager.Transport = NetManager.transport
	NetManager.transport = NetManager.Transport.STEAM
	var report: String = NetDebug.build_report()
	assert_true(report.contains("relay network"))
	assert_true(report.contains("Direct/SDR route"))
	assert_false(report.contains("total (ENet)"))
	NetManager.transport = previous
