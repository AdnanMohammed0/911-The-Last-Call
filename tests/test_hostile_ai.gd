## P3-10 / P3-11: archetype data, per-archetype trees, squad flank tokens, callouts, morale and surrender.
extends GutTest

const IDS: Array[StringName] = [&"thug", &"cultist_gunman", &"zealot", &"ambush_leader", &"hostage_taker"]


func _archetype(id: StringName) -> ArchetypeData:
	return load("res://data/ai/archetypes/%s.tres" % id) as ArchetypeData


func _hostile(id: StringName) -> HostileAgent:
	var hostile: HostileAgent = (load("res://scenes/field/enemies/hostile.tscn") as PackedScene).instantiate() as HostileAgent
	hostile.archetype = _archetype(id)
	add_child_autofree(hostile)
	hostile.runner.enabled = false
	return hostile


func _labels(node: BTNode, into: PackedStringArray) -> PackedStringArray:
	into.append(node.get_display_name())
	for child: BTNode in node.get_children():
		_labels(child, into)
	return into


func test_archetype_stats_match_design_table() -> void:
	var expected: Dictionary = {&"thug": [100.0, 40.0], &"cultist_gunman": [120.0, 70.0], &"zealot": [90.0, 100.0],
		&"ambush_leader": [160.0, 85.0], &"hostage_taker": [110.0, 55.0]}
	for id: StringName in IDS:
		var data: ArchetypeData = _archetype(id)
		var row: Array = expected[id]
		var hp: float = row[0]
		var morale: float = row[1]
		assert_eq(data.max_hp, hp, "%s hp" % id)
		assert_eq(data.morale, morale, "%s morale" % id)
	assert_true(_archetype(&"zealot").fanatic)
	assert_gt(_archetype(&"thug").surrender_threshold, _archetype(&"cultist_gunman").surrender_threshold, "thug surrenders easily")


func test_trees_have_archetype_tactics() -> void:
	var gunman: String = " ".join(_labels(HostileBrains.build(_archetype(&"cultist_gunman")), PackedStringArray()))
	assert_string_contains(gunman, "Flank")
	assert_string_contains(gunman, "Move to best cover")
	var zealot: String = " ".join(_labels(HostileBrains.build(_archetype(&"zealot")), PackedStringArray()))
	assert_string_contains(zealot, "Rush")
	assert_string_contains(zealot, "Detonate IED")
	assert_false(zealot.contains("cover"), "zealot never takes cover")
	var leader: String = " ".join(_labels(HostileBrains.build(_archetype(&"ambush_leader")), PackedStringArray()))
	assert_string_contains(leader, "Call reinforcements")
	var taker: String = " ".join(_labels(HostileBrains.build(_archetype(&"hostage_taker")), PackedStringArray()))
	assert_string_contains(taker, "Hold hostage")


func test_fanatic_never_surrenders() -> void:
	var zealot: HostileAgent = _hostile(&"zealot")
	zealot.morale = 0.0
	zealot.negotiated = true
	assert_false(zealot.cond_should_surrender(zealot.runner.blackboard))
	assert_false(zealot.cond_should_flee(zealot.runner.blackboard))


func test_low_morale_surrenders_when_negotiated_or_outnumbered() -> void:
	var thug: HostileAgent = _hostile(&"thug")
	thug.morale = 30.0
	assert_false(thug.cond_should_surrender(thug.runner.blackboard), "nobody in sight")
	thug.negotiated = true
	assert_true(thug.cond_should_surrender(thug.runner.blackboard))
	thug.act_surrender(thug.runner.blackboard)
	assert_true(thug.is_surrendered)
	assert_eq(thug.anim_state, &"surrender")
	assert_false(thug.is_active())


func test_damage_uses_zone_multiplier_and_kills() -> void:
	var gunman: HostileAgent = _hostile(&"cultist_gunman")
	gunman.take_damage(30.0, HealthComponent.HitZone.HEAD)
	assert_eq(gunman.hp, 60.0)
	gunman.take_damage(100.0)
	assert_true(gunman.is_dead)
	assert_eq(gunman.anim_state, &"dead")


func test_squad_flank_tokens_limit_to_half() -> void:
	var squad: AISquad = AISquad.new()
	add_child_autofree(squad)
	var members: Array[HostileAgent] = []
	for i: int in 4:
		var member: HostileAgent = _hostile(&"cultist_gunman")
		squad.register(member)
		members.append(member)
	assert_true(squad.request_flank_token(members[0]))
	assert_true(squad.request_flank_token(members[1]))
	assert_false(squad.request_flank_token(members[2]), "only 2 of 4 flank at once")
	squad.release_flank_token(members[0])
	assert_true(squad.request_flank_token(members[2]))


func test_lone_member_cannot_flank() -> void:
	var squad: AISquad = AISquad.new()
	add_child_autofree(squad)
	var solo: HostileAgent = _hostile(&"cultist_gunman")
	squad.register(solo)
	assert_false(squad.request_flank_token(solo))


func test_callout_shares_target_with_squad() -> void:
	var squad: AISquad = AISquad.new()
	add_child_autofree(squad)
	var a: HostileAgent = _hostile(&"thug")
	var b: HostileAgent = _hostile(&"thug")
	squad.register(a)
	squad.register(b)
	a.perception.callout.emit(0, Vector3(5, 0, -5))
	assert_eq(b.perception.level, AIPerception.Level.COMBAT)
	assert_eq(b.perception.last_known_position, Vector3(5, 0, -5))


func test_ally_and_leader_deaths_lower_morale() -> void:
	var squad: AISquad = AISquad.new()
	add_child_autofree(squad)
	var leader: HostileAgent = _hostile(&"ambush_leader")
	var gunman: HostileAgent = _hostile(&"cultist_gunman")
	var thug: HostileAgent = _hostile(&"thug")
	for member: HostileAgent in [leader, gunman, thug]:
		squad.register(member)
	thug.take_damage(1000.0)
	assert_eq(gunman.morale, 70.0 + AISquad.ALLY_KILLED)
	leader.take_damage(1000.0)
	assert_eq(gunman.morale, 70.0 + AISquad.ALLY_KILLED + AISquad.LEADER_KILLED)


func test_squad_wide_morale_event() -> void:
	var squad: AISquad = AISquad.new()
	add_child_autofree(squad)
	var a: HostileAgent = _hostile(&"thug")
	squad.register(a)
	squad.apply_morale_event(AISquad.MEGAPHONE, &"megaphone")
	assert_eq(a.morale, 40.0 + AISquad.MEGAPHONE)
