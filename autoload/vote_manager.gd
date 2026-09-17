## Team votes with timeouts and class tie-breakers (ARCHITECTURE §5, GAMEPLAY_MECHANICS §5.5 / §6).
## The host opens a vote, peers send `cast_vote` intents, the host validates every ballot, replicates the
## tally, and closes the vote when it times out, everyone has voted, or (optionally) the vote is unanimous.
## Resolution: most votes wins. Ties go to the option chosen by the tie-breaker class (e.g. Profiler for
## call verdicts, Breacher for the approach); otherwise to `default_option` if tied; otherwise to the tied
## option listed first. No ballots at all -> `default_option` (or the first option).
## Authority: HOST (clients only send intents)
extends Node

const VERDICT_TOPIC: StringName = &"verdict"
const APPROACH_TOPIC: StringName = &"approach"
const APPROACH_OPTIONS: Array[StringName] = [&"code_3", &"silent", &"on_foot", &"decoy"]
const ASSESSMENT_WINDOW_SEC: float = 60.0
const APPROACH_WINDOW_SEC: float = 45.0

## Emitted on every peer.
signal vote_opened(vote: Dictionary)
signal vote_updated(vote: Dictionary)
## `result` is the winning option; `vote` holds the final ballots and how it was decided.
signal vote_closed(vote: Dictionary, result: StringName)

## vote_id -> state Dictionary (see _new_vote). Replicated copy on clients.
var votes: Dictionary[int, Dictionary] = {}

var _next_id: int = 1
var _limiter: RpcRateLimiter = RpcRateLimiter.new(6.0, 6.0)


func _ready() -> void:
	NetManager.peer_left.connect(_on_peer_gone)
	NetManager.peer_dropped.connect(_on_peer_gone)
	NetManager.peer_reconnected.connect(_on_peer_reconnected)
	NetManager.session_ended.connect(func(_reason: String) -> void: votes.clear())


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now: int = Time.get_ticks_msec()
	for vote_id: int in votes.keys():
		var vote: Dictionary = votes[vote_id]
		var closes_at: int = vote["closes_at_msec"]
		if not vote["closed"] and now >= closes_at:
			_close(vote_id, &"timeout")


# --- Host API -----------------------------------------------------------------

## Host: opens a vote and returns its id (0 when refused).
## `eligible` defaults to everyone in the roster (or just us offline).
## `unanimous_ends_early`: close as soon as every eligible voter picked the same option.
func open_vote(topic: StringName, options: Array[StringName], timeout_sec: float, tie_breaker_class: StringName = &"",
		default_option: StringName = &"", unanimous_ends_early: bool = false, context: Dictionary = {},
		eligible: Array[int] = []) -> int:
	if not multiplayer.is_server() or options.is_empty() or timeout_sec <= 0.0:
		return 0
	var existing: int = get_active_vote_id(topic)
	if existing != 0:
		_close(existing, &"replaced")
	var voters: Array[int] = eligible.duplicate()
	if voters.is_empty():
		for peer_id: int in NetManager.roster:
			voters.append(peer_id)
		if voters.is_empty():
			voters.append(multiplayer.get_unique_id())
	var vote_id: int = _next_id
	_next_id += 1
	var vote: Dictionary = {
		"id": vote_id,
		"topic": topic,
		"options": options.duplicate(),
		"eligible": voters,
		"ballots": {},          # peer_id -> option
		"tie_breaker_class": tie_breaker_class,
		"default_option": default_option,
		"unanimous_ends_early": unanimous_ends_early,
		"context": context,
		"timeout_sec": timeout_sec,
		"closes_at_msec": Time.get_ticks_msec() + int(timeout_sec * 1000.0),
		"closed": false,
		"result": &"",
		"decided_by": &"",
	}
	votes[vote_id] = vote
	_broadcast_open(vote)
	return vote_id


## Host: approach vote for a mission (GAMEPLAY §6). Decoy needs >= 3 players or a Tech Operator.
func open_approach_vote(context: Dictionary = {}) -> int:
	var options: Array[StringName] = APPROACH_OPTIONS.duplicate()
	if not decoy_allowed():
		options.erase(&"decoy")
	return open_vote(APPROACH_TOPIC, options, APPROACH_WINDOW_SEC, &"breacher", &"silent", false, context)


## Host: call verdict vote during assessment (GAMEPLAY §5.5): 60 s, unanimous ends early, Profiler breaks ties.
func open_verdict_vote(call_id: StringName) -> int:
	var options: Array[StringName] = CallData.VERDICTS.duplicate()
	return open_vote(VERDICT_TOPIC, options, ASSESSMENT_WINDOW_SEC, &"profiler", &"ignore", true, {"call_id": call_id})


func decoy_allowed() -> bool:
	if NetManager.roster.size() >= 3:
		return true
	for peer_id: int in NetManager.roster:
		if NetManager.get_class_id(peer_id) == &"tech":
			return true
	return false


## Host: force-close (e.g. the call was abandoned).
func cancel_vote(vote_id: int) -> void:
	if multiplayer.is_server() and votes.has(vote_id):
		_close(vote_id, &"cancelled")


# --- Any peer -------------------------------------------------------------------

func get_active_vote_id(topic: StringName) -> int:
	for vote_id: int in votes:
		var vote: Dictionary = votes[vote_id]
		if vote["topic"] == topic and not vote["closed"]:
			return vote_id
	return 0


func get_vote(vote_id: int) -> Dictionary:
	return votes.get(vote_id, {})


## Seconds left on a vote (0 when closed or unknown).
func get_time_left(vote_id: int) -> float:
	var vote: Dictionary = get_vote(vote_id)
	if vote.is_empty() or vote["closed"]:
		return 0.0
	var closes_at: int = vote["closes_at_msec"]
	return maxf(float(closes_at - Time.get_ticks_msec()) / 1000.0, 0.0)


## Option -> number of ballots.
func get_tally(vote_id: int) -> Dictionary:
	var tally: Dictionary = {}
	var vote: Dictionary = get_vote(vote_id)
	if vote.is_empty():
		return tally
	var options: Array = vote["options"]
	for option: Variant in options:
		tally[option] = 0
	var ballots: Dictionary = vote["ballots"]
	for peer_id: Variant in ballots:
		var option: StringName = ballots[peer_id]
		var count: int = tally.get(option, 0)
		tally[option] = count + 1
	return tally


## Cast or change our ballot. The host validates it.
func cast_vote(vote_id: int, option: StringName) -> void:
	if multiplayer.is_server():
		_request_vote(vote_id, option)
	else:
		_request_vote.rpc_id(1, vote_id, option)


# --- RPCs ---------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_vote(vote_id: int, option: StringName) -> void:
	if not RpcGuard.is_host(self):
		return
	var sender: int = RpcGuard.sender_id(self)
	if not _limiter.allow(sender, &"vote"):
		return
	var vote: Dictionary = votes.get(vote_id, {})
	if vote.is_empty() or vote["closed"]:
		return
	var eligible: Array = vote["eligible"]
	var options: Array = vote["options"]
	if not sender in eligible or not option in options:
		RpcGuard.reject("vote", sender, "not eligible or invalid option '%s'" % option)
		return
	var ballots: Dictionary = vote["ballots"]
	ballots[sender] = option
	_sync_ballots.rpc(vote_id, ballots)
	_sync_ballots_local(vote_id, ballots)
	_check_early_close(vote_id)


@rpc("authority", "call_remote", "reliable")
func _sync_vote_opened(vote: Dictionary) -> void:
	var vote_id: int = vote["id"]
	var timeout_sec: float = vote["timeout_sec"]
	var remaining_sec: float = vote.get("remaining_sec", timeout_sec)
	# Clocks differ between machines: rebuild the local deadline from the remaining time.
	vote["closes_at_msec"] = Time.get_ticks_msec() + int(remaining_sec * 1000.0)
	votes[vote_id] = vote
	vote_opened.emit(vote)


@rpc("authority", "call_remote", "reliable")
func _sync_ballots(vote_id: int, ballots: Dictionary) -> void:
	_sync_ballots_local(vote_id, ballots)


@rpc("authority", "call_remote", "reliable")
func _sync_vote_closed(vote_id: int, result: StringName, decided_by: StringName, ballots: Dictionary) -> void:
	var vote: Dictionary = votes.get(vote_id, {})
	if vote.is_empty():
		return
	vote["ballots"] = ballots
	_finish_local(vote_id, result, decided_by)


# --- Internals ------------------------------------------------------------------

func _broadcast_open(vote: Dictionary) -> void:
	var packet: Dictionary = vote.duplicate(true)
	var vote_id: int = vote["id"]
	packet["remaining_sec"] = get_time_left(vote_id)
	if NetManager.is_online():
		_sync_vote_opened.rpc(packet)
	vote_opened.emit(vote)


func _sync_ballots_local(vote_id: int, ballots: Dictionary) -> void:
	var vote: Dictionary = votes.get(vote_id, {})
	if vote.is_empty():
		return
	vote["ballots"] = ballots
	vote_updated.emit(vote)


func _check_early_close(vote_id: int) -> void:
	var vote: Dictionary = votes[vote_id]
	var eligible: Array = vote["eligible"]
	var ballots: Dictionary = vote["ballots"]
	var everyone_voted: bool = true
	for peer_id: Variant in eligible:
		if not ballots.has(peer_id):
			everyone_voted = false
			break
	if not everyone_voted:
		return
	var unanimous: bool = _distinct_options(ballots).size() == 1
	if unanimous and vote["unanimous_ends_early"]:
		_close(vote_id, &"unanimous")
	elif not vote["unanimous_ends_early"]:
		_close(vote_id, &"all_voted")


func _close(vote_id: int, reason: StringName) -> void:
	var vote: Dictionary = votes[vote_id]
	if vote["closed"]:
		return
	var outcome: Array = resolve(vote)
	var result: StringName = outcome[0]
	var decided_by: StringName = outcome[1]
	if reason == &"unanimous" or reason == &"cancelled" or reason == &"replaced":
		decided_by = reason
	if NetManager.is_online():
		_sync_vote_closed.rpc(vote_id, result, decided_by, vote["ballots"])
	_finish_local(vote_id, result, decided_by)


func _finish_local(vote_id: int, result: StringName, decided_by: StringName) -> void:
	var vote: Dictionary = votes[vote_id]
	vote["closed"] = true
	vote["result"] = result
	vote["decided_by"] = decided_by
	vote_closed.emit(vote, result)
	EventBus.vote_finished.emit(vote["topic"], result)
	votes.erase(vote_id)


## Pure resolution so it can be unit-tested. Returns [winner: StringName, decided_by: StringName]
## where decided_by is &"majority", &"tie_breaker", &"default", &"option_order" or &"no_votes".
func resolve(vote: Dictionary) -> Array:
	var options: Array = vote["options"]
	var ballots: Dictionary = vote["ballots"]
	var default_option: StringName = vote["default_option"]
	if ballots.is_empty():
		var first: StringName = options[0]
		return [default_option if default_option in options else first, &"no_votes"]

	var counts: Dictionary = {}
	var best: int = 0
	for peer_id: Variant in ballots:
		var option: StringName = ballots[peer_id]
		var count: int = counts.get(option, 0) + 1
		counts[option] = count
		best = maxi(best, count)
	var tied: Array[StringName] = []
	for option: Variant in options:
		var count: int = counts.get(option, 0)
		if count == best:
			tied.append(option)
	if tied.size() == 1:
		return [tied[0], &"majority"]

	var breaker_class: StringName = vote["tie_breaker_class"]
	if breaker_class != &"":
		for peer_id: Variant in ballots:
			var voter: int = peer_id
			var option: StringName = ballots[peer_id]
			if NetManager.get_class_id(voter) == breaker_class and option in tied:
				return [option, &"tie_breaker"]
	if default_option in tied:
		return [default_option, &"default"]
	return [tied[0], &"option_order"]


static func _distinct_options(ballots: Dictionary) -> Dictionary:
	var distinct: Dictionary = {}
	for peer_id: Variant in ballots:
		distinct[ballots[peer_id]] = true
	return distinct


## A voter who left stops counting; the vote may now be complete.
func _on_peer_gone(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for vote_id: int in votes.keys():
		var vote: Dictionary = votes[vote_id]
		var eligible: Array = vote["eligible"]
		var ballots: Dictionary = vote["ballots"]
		if not peer_id in eligible:
			continue
		eligible.erase(peer_id)
		ballots.erase(peer_id)
		if eligible.is_empty():
			_close(vote_id, &"timeout")
		else:
			_sync_ballots.rpc(vote_id, ballots)
			_check_early_close(vote_id)


## A reconnecting player gets the open votes and may vote again.
func _on_peer_reconnected(_old_peer_id: int, new_peer_id: int) -> void:
	for vote_id: int in votes:
		var vote: Dictionary = votes[vote_id]
		if vote["closed"]:
			continue
		var eligible: Array = vote["eligible"]
		if not new_peer_id in eligible:
			eligible.append(new_peer_id)
		var packet: Dictionary = vote.duplicate(true)
		packet["remaining_sec"] = get_time_left(vote_id)
		_sync_vote_opened.rpc_id(new_peer_id, packet)
