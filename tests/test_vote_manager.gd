## P2-14: vote resolution (majority, tie-breaker class, default, option order) and offline open/cast/close.
extends GutTest

var _saved_roster: Dictionary[int, Dictionary] = {}


func before_each() -> void:
	_saved_roster = NetManager.roster.duplicate(true)
	NetManager.roster.clear()


func after_each() -> void:
	NetManager.roster.clear()
	for peer_id: int in _saved_roster:
		NetManager.roster[peer_id] = _saved_roster[peer_id]
	for vote_id: int in VoteManager.votes.keys():
		VoteManager.cancel_vote(vote_id)


func _vote(options: Array[StringName], ballots: Dictionary, breaker: StringName = &"", default_option: StringName = &"") -> Dictionary:
	return {
		"options": options,
		"ballots": ballots,
		"tie_breaker_class": breaker,
		"default_option": default_option,
	}


func _set_class(peer_id: int, class_id: StringName) -> void:
	NetManager.roster[peer_id] = {"name": "P%d" % peer_id, "class_id": class_id, "ready": true}


func test_majority_wins() -> void:
	var options: Array[StringName] = [&"prank", &"genuine", &"ambush"]
	var outcome: Array = VoteManager.resolve(_vote(options, {1: &"ambush", 2: &"ambush", 3: &"genuine"}, &"profiler"))
	assert_eq(outcome, [&"ambush", &"majority"])


func test_tie_broken_by_class() -> void:
	_set_class(1, &"tech")
	_set_class(2, &"profiler")
	var options: Array[StringName] = [&"prank", &"genuine"]
	var outcome: Array = VoteManager.resolve(_vote(options, {1: &"prank", 2: &"genuine"}, &"profiler"))
	assert_eq(outcome, [&"genuine", &"tie_breaker"])


func test_tie_without_breaker_uses_default() -> void:
	_set_class(1, &"tech")
	_set_class(2, &"medic")
	var options: Array[StringName] = [&"code_3", &"silent", &"on_foot"]
	var outcome: Array = VoteManager.resolve(_vote(options, {1: &"code_3", 2: &"silent"}, &"breacher", &"silent"))
	assert_eq(outcome, [&"silent", &"default"])


func test_tie_falls_back_to_option_order() -> void:
	var options: Array[StringName] = [&"a", &"b", &"c"]
	var outcome: Array = VoteManager.resolve(_vote(options, {1: &"c", 2: &"b"}))
	assert_eq(outcome, [&"b", &"option_order"])


func test_no_votes_uses_default() -> void:
	var options: Array[StringName] = [&"prank", &"ignore"]
	var outcome: Array = VoteManager.resolve(_vote(options, {}, &"", &"ignore"))
	assert_eq(outcome, [&"ignore", &"no_votes"])


func test_offline_vote_closes_when_everyone_voted() -> void:
	var closed: Array[StringName] = []
	var on_closed: Callable = func(_vote: Dictionary, result: StringName) -> void: closed.append(result)
	VoteManager.vote_closed.connect(on_closed)
	var options: Array[StringName] = [&"yes", &"no"]
	var vote_id: int = VoteManager.open_vote(&"test_topic", options, 30.0)
	assert_gt(vote_id, 0)
	assert_eq(VoteManager.get_active_vote_id(&"test_topic"), vote_id)
	VoteManager.cast_vote(vote_id, &"no")
	assert_eq(closed, [&"no"] as Array[StringName])
	assert_eq(VoteManager.get_active_vote_id(&"test_topic"), 0)
	VoteManager.vote_closed.disconnect(on_closed)


func test_invalid_option_is_ignored() -> void:
	var options: Array[StringName] = [&"yes", &"no"]
	var vote_id: int = VoteManager.open_vote(&"test_invalid", options, 30.0)
	VoteManager.cast_vote(vote_id, &"maybe")
	var tally: Dictionary = VoteManager.get_tally(vote_id)
	assert_eq(tally, {&"yes": 0, &"no": 0})
	assert_eq(VoteManager.get_active_vote_id(&"test_invalid"), vote_id)


func test_unanimous_vote_ends_early() -> void:
	var results: Array[Dictionary] = []
	var on_closed: Callable = func(vote: Dictionary, _result: StringName) -> void: results.append(vote)
	VoteManager.vote_closed.connect(on_closed)
	var vote_id: int = VoteManager.open_verdict_vote(&"call_test")
	VoteManager.cast_vote(vote_id, &"prank")
	assert_eq(results.size(), 1)
	var decided_by: StringName = results[0]["decided_by"]
	var result: StringName = results[0]["result"]
	assert_eq(decided_by, &"unanimous")
	assert_eq(result, &"prank")
	VoteManager.vote_closed.disconnect(on_closed)


func test_timeout_closes_vote() -> void:
	var options: Array[StringName] = [&"yes", &"no"]
	var vote_id: int = VoteManager.open_vote(&"test_timeout", options, 0.2, &"", &"no")
	await wait_seconds(0.4)
	assert_eq(VoteManager.get_active_vote_id(&"test_timeout"), 0, "closed by timeout (vote %d)" % vote_id)


func test_decoy_requires_three_players_or_tech() -> void:
	_set_class(1, &"medic")
	_set_class(2, &"breacher")
	assert_false(VoteManager.decoy_allowed())
	_set_class(2, &"tech")
	assert_true(VoteManager.decoy_allowed())
	_set_class(2, &"breacher")
	_set_class(3, &"profiler")
	assert_true(VoteManager.decoy_allowed())
