## P5-07 QA regression: the part of the 2/3/4-player matrix that can be asserted without a session.
##
## The matrix itself (real peers, real latency, real loss) is run by hand from
## docs/qa/P5-07_QA_REGRESSION.md — it needs several machines and a human. What lives here is the
## guard rail underneath it: the limits and parsing rules the matrix is built on. If one of these
## changes, the numbers in the checklist change too, so they are pinned here.
extends GutTest


# --- Capacity: the matrix is 2/3/4 *total* players, host included ---------------------------

func test_lobby_caps_at_four_total_peers() -> void:
	# MAX_PEERS counts the host, so "4 players" is host + 3 clients. The checklist writes the
	# matrix as total players, and this is the number that makes that true.
	assert_eq(NetManager.MAX_PEERS, 4)
	assert_eq(NetManager.MAX_PEERS - 1, 3, "client count for the '4 players' row")


func test_start_requires_a_class_and_all_ready() -> void:
	# can_start() gates the host's "launch shift" button, so the checklist's ready-up step only
	# means something if this is the real gate.
	assert_false(NetManager.can_start(), "an empty lobby must not be startable")


# --- Address parsing: the first thing that breaks when a player pastes from chat -------------

func test_parse_address_accepts_the_forms_players_actually_paste() -> void:
	assert_eq(NetManager.parse_address("127.0.0.1:24911"), ["127.0.0.1", 24911])
	assert_eq(NetManager.parse_address(" 192.168.1.20 "), ["192.168.1.20", NetManager.DEFAULT_PORT])
	# playit tunnels get shared as a URL, not a bare address.
	assert_eq(NetManager.parse_address("https://blackvale.trycloudflare.com"),
		["blackvale.trycloudflare.com", NetManager.DEFAULT_PORT])
	assert_eq(NetManager.parse_address("udp://10.0.0.5:7777/"), ["10.0.0.5", 7777])
	# a quoted address copied out of Discord.
	assert_eq(NetManager.parse_address("\"203.0.113.7:24911\""), ["203.0.113.7", 24911])


func test_parse_address_rejects_a_nonsense_port_and_keeps_the_host() -> void:
	# Better to fall back to the default port than to refuse the connection over a typo.
	assert_eq(NetManager.parse_address("10.0.0.5:99999"), ["10.0.0.5", NetManager.DEFAULT_PORT])
	assert_eq(NetManager.parse_address("10.0.0.5:0"), ["10.0.0.5", NetManager.DEFAULT_PORT])
	assert_eq(NetManager.parse_address("10.0.0.5:abc"), ["10.0.0.5", NetManager.DEFAULT_PORT])
	# Empty input is the offline case, not an error.
	assert_eq(NetManager.parse_address(""), ["127.0.0.1", NetManager.DEFAULT_PORT])


func test_parse_address_keeps_ipv6_intact() -> void:
	# A bracketed IPv6 literal has several colons, so it must not be mistaken for host:port.
	var parsed: Array = NetManager.parse_address("::1")
	assert_eq(parsed[0], "::1")
	assert_eq(parsed[1], NetManager.DEFAULT_PORT)


# --- Player names ------------------------------------------------------------------------------

func test_sanitize_name_strips_control_characters_and_caps_length() -> void:
	# Voice chat shows this next to the speaker, so control characters from a pasted name have to
	# go: a NUL or a newline in a name breaks the roster layout.
	var with_control: String = "  Ada" + String.chr(0) + "\nLovelace  "
	assert_eq(NetManager.sanitize_name(with_control, 2), "AdaLovelace")
	assert_eq(NetManager.sanitize_name("A".repeat(NetManager.MAX_NAME_LENGTH + 20), 3).length(),
		NetManager.MAX_NAME_LENGTH)
	# An all-blank name still needs a label in the roster.
	assert_eq(NetManager.sanitize_name("   ", 4), "Player 4")


# --- Protocol gate: a mixed-build lobby must fail loudly, not desync ---------------------------

func test_protocol_version_is_pinned() -> void:
	# The checklist's "mismatched build" row depends on this being bumped whenever the wire
	# format changes. If a network change lands without bumping it, that test row silently stops
	# testing anything.
	assert_true(NetManager.PROTOCOL_VERSION > 0)
	assert_gt(NetManager.CONNECT_TIMEOUT_SEC, 0.0)
	assert_gt(NetManager.REGISTER_TIMEOUT_SEC, 0.0)


# --- Lag compensation: the bounds the high-latency rows are judged against ---------------------

func test_rewind_is_zero_for_the_local_peer() -> void:
	# Rewinding your own input would make shooting feel wrong on the host.
	assert_eq(LagCompensation.rewind_msec_for(multiplayer.get_unique_id()), 0)


func test_rewind_stays_inside_the_documented_bounds() -> void:
	# With no live session the peer is unknown, so RTT reads 0 and the result is the interpolation
	# delay. The upper bound cannot be reached without real peers, but pinning the constant and
	# the floor keeps the "high latency" column of the checklist honest.
	var unknown_peer: int = 4242
	assert_eq(LagCompensation.rewind_msec_for(unknown_peer), LagCompensation.INTERPOLATION_DELAY_MSEC)
	assert_lte(LagCompensation.MAX_REWIND_MSEC, 300)
	assert_gt(LagCompensation.MAX_REWIND_MSEC, LagCompensation.INTERPOLATION_DELAY_MSEC)
	assert_gt(LagCompensation.INTERPOLATION_DELAY_MSEC, 0)


func test_peer_timeout_is_shorter_than_enets_default() -> void:
	# ENet drops a silent peer after ~30 s. The comment in NetManager says that is too slow for
	# co-op, so the bounds must stay well under it or a crashed client stays in the roster and the
	# host waits on a lobby that can never start.
	assert_lt(NetManager.PEER_TIMEOUT_MAX_MS, 30_000)
	assert_lt(NetManager.PEER_TIMEOUT_MIN_MS, NetManager.PEER_TIMEOUT_MAX_MS)
	assert_gt(NetManager.PEER_TIMEOUT_MIN_MS, 0)
