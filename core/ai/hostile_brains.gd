## Builds the behavior tree for an archetype (GAMEPLAY_MECHANICS §8.3). Every archetype shares the same
## priority skeleton; archetype flags switch branches on or off.
##   Surrender > Flee > Combat[archetype tactics] > Search > Investigate > Patrol
## Leaves are HostileAgent methods (cond_* / act_*).
## Authority: HOST
class_name HostileBrains
extends RefCounted


static func build(archetype: ArchetypeData) -> BTNode:
	var combat: Array[BTNode] = []
	if archetype.ied_radius > 0.0:
		combat.append(BT.seq([BT.cond(&"cond_ied_in_range"), BT.act(&"act_detonate_ied")], "Detonate IED"))
	if archetype.hostage_execute_chance > 0.0:
		combat.append(BT.act(&"act_hold_hostage", [], "Hold hostage"))
	if archetype.reinforcements > 0:
		combat.append(BT.seq([BT.cond(&"cond_can_call_reinforcements"), BT.act(&"act_call_reinforcements")], "Call reinforcements"))
	if archetype.rushes:
		combat.append(BT.act(&"act_rush_and_strike", [], "Rush"))
	else:
		combat.append(BT.seq([BT.cond(&"cond_needs_reload"), BT.act(&"act_reload")], "Reload"))
		if archetype.uses_flanks:
			combat.append(BT.seq([BT.cond(&"cond_can_flank"), BT.time_limit(BT.act(&"act_flank"), 8.0)], "Flank"))
		if archetype.uses_cover:
			combat.append(BT.seq([BT.cond(&"cond_in_cover"), BT.act(&"act_peek_and_fire")], "Suppress from cover"))
			combat.append(BT.act(&"act_move_to_cover", [], "Move to best cover"))
		combat.append(BT.act(&"act_advance_and_fire", [], "Advance and fire"))

	return BT.sel([
		BT.seq([BT.cond(&"cond_should_surrender"), BT.act(&"act_surrender")], "Surrender"),
		BT.seq([BT.cond(&"cond_should_flee"), BT.act(&"act_flee")], "Flee"),
		BT.seq([BT.cond(&"cond_in_combat"), BT.sel(combat, "Tactics")], "Combat"),
		BT.seq([BT.cond(&"cond_searching"), BT.act(&"act_search")], "Search"),
		BT.seq([BT.cond(&"cond_suspicious"), BT.act(&"act_investigate")], "Investigate"),
		BT.act(&"act_patrol", [], "Patrol"),
	], archetype.display_name)
