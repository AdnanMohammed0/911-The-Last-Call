## P3-07: behavior tree runtime (composites, decorators, blackboard, abort, trace).
extends GutTest


class Agent:
	extends Node
	var calls: Array[String] = []
	var alarm: bool = false
	var steps_to_finish: int = 2
	var progress: int = 0
	var exited: int = 0

	func cond_alarm(_bb: BTBlackboard) -> bool:
		calls.append("alarm?")
		return alarm

	func act_attack(_bb: BTBlackboard) -> BTNode.Status:
		calls.append("attack")
		return BTNode.Status.SUCCESS

	func act_patrol(_bb: BTBlackboard) -> BTNode.Status:
		calls.append("patrol")
		progress += 1
		return BTNode.Status.SUCCESS if progress >= steps_to_finish else BTNode.Status.RUNNING

	func act_patrol_exit(_bb: BTBlackboard) -> void:
		exited += 1

	func act_fail(_bb: BTBlackboard) -> bool:
		return false

	func act_count(bb: BTBlackboard, key: StringName) -> bool:
		var current: int = bb.get_value(key, 0)
		bb.set_value(key, current + 1)
		return true


var _agent: Agent
var _bb: BTBlackboard


func before_each() -> void:
	_agent = Agent.new()
	add_child_autofree(_agent)
	_bb = BTBlackboard.new()


func _run(tree: BTNode) -> BTNode.Status:
	_bb.begin_tick()
	var status: BTNode.Status = tree.tick(_agent, _bb)
	_bb.end_tick()
	return status


func _value(key: StringName) -> int:
	var v: int = _bb.get_value(key, 0)
	return v


func test_selector_picks_first_success() -> void:
	_agent.alarm = true
	var tree: BTNode = BT.sel([BT.seq([BT.cond(&"cond_alarm"), BT.act(&"act_attack")]), BT.act(&"act_patrol")])
	assert_eq(_run(tree), BTNode.Status.SUCCESS)
	assert_eq(_agent.calls, ["alarm?", "attack"] as Array[String])


func test_sequence_stops_on_failure() -> void:
	var tree: BTNode = BT.seq([BT.act(&"act_fail"), BT.act(&"act_attack")])
	assert_eq(_run(tree), BTNode.Status.FAILURE)
	assert_false("attack" in _agent.calls)


func test_running_sequence_resumes_at_running_child() -> void:
	var tree: BTNode = BT.seq([BT.act(&"act_count", [&"entered"]), BT.act(&"act_patrol")])
	assert_eq(_run(tree), BTNode.Status.RUNNING)
	assert_eq(_run(tree), BTNode.Status.SUCCESS)
	assert_eq(_value(&"entered"), 1, "first child not re-run while resuming")


func test_higher_priority_branch_aborts_running_one() -> void:
	_agent.steps_to_finish = 99
	var tree: BTNode = BT.sel([BT.seq([BT.cond(&"cond_alarm"), BT.act(&"act_attack")]), BT.act(&"act_patrol")])
	assert_eq(_run(tree), BTNode.Status.RUNNING)
	_agent.alarm = true
	assert_eq(_run(tree), BTNode.Status.SUCCESS)
	assert_eq(_agent.exited, 1, "patrol got its _exit cleanup when interrupted")


func test_inverter_and_succeeder() -> void:
	assert_eq(_run(BT.invert(BT.act(&"act_fail"))), BTNode.Status.SUCCESS)
	assert_eq(_run(BT.succeed(BT.act(&"act_fail"))), BTNode.Status.SUCCESS)


func test_repeat_count() -> void:
	var tree: BTNode = BT.repeat(BT.act(&"act_count", [&"n"]), 3)
	assert_eq(_run(tree), BTNode.Status.RUNNING)
	assert_eq(_run(tree), BTNode.Status.RUNNING)
	assert_eq(_run(tree), BTNode.Status.SUCCESS)
	assert_eq(_value(&"n"), 3)


func test_cooldown_blocks_until_time_passes() -> void:
	var tree: BTNode = BT.cooldown(BT.act(&"act_attack"), 2.0)
	assert_eq(_run(tree), BTNode.Status.SUCCESS)
	_bb.time += 1.0
	assert_eq(_run(tree), BTNode.Status.FAILURE)
	_bb.time += 1.5
	assert_eq(_run(tree), BTNode.Status.SUCCESS)


func test_time_limit_fails_long_running_child() -> void:
	_agent.steps_to_finish = 99
	var tree: BTNode = BT.time_limit(BT.act(&"act_patrol"), 1.0)
	assert_eq(_run(tree), BTNode.Status.RUNNING)
	_bb.time += 2.0
	assert_eq(_run(tree), BTNode.Status.FAILURE)


func test_wait_and_parallel() -> void:
	var tree: BTNode = BT.parallel([BT.wait(1.0), BT.act(&"act_attack")])
	assert_eq(_run(tree), BTNode.Status.RUNNING)
	_bb.time += 1.1
	assert_eq(_run(tree), BTNode.Status.SUCCESS)


func test_blackboard_check() -> void:
	_bb.set_value(&"awareness", 0.7)
	assert_eq(_run(BT.check(&"awareness", BTCheck.Op.GREATER_EQUAL, 0.6)), BTNode.Status.SUCCESS)
	assert_eq(_run(BT.check(&"awareness", BTCheck.Op.LESS, 0.3)), BTNode.Status.FAILURE)
	assert_eq(_run(BT.check(&"target")), BTNode.Status.FAILURE)


func test_trace_is_top_down_for_debugger() -> void:
	_agent.alarm = true
	var combat: BTNode = BT.seq([BT.cond(&"cond_alarm"), BT.act(&"act_attack")], "Combat")
	var tree: BTNode = BT.sel([combat, BT.act(&"act_patrol")], "Root")
	_run(tree)
	var text: String = _bb.format_trace()
	assert_true(text.begins_with("✔ Root"), text)
	assert_true(text.contains("\n  ✔ Combat\n    ✔ cond_alarm\n    ✔ act_attack"), text)


func test_one_tree_shared_by_two_agents_keeps_separate_state() -> void:
	_agent.steps_to_finish = 3
	var other: Agent = Agent.new()
	other.steps_to_finish = 3
	add_child_autofree(other)
	var other_bb: BTBlackboard = BTBlackboard.new()
	var tree: BTNode = BT.seq([BT.act(&"act_count", [&"entered"]), BT.act(&"act_patrol")])
	_run(tree)
	tree.tick(other, other_bb)
	_run(tree)
	assert_eq(_value(&"entered"), 1)
	var other_entered: int = other_bb.get_value(&"entered", 0)
	assert_eq(other_entered, 1)
