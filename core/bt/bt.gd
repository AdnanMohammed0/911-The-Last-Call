## Terse builders for trees defined in code (archetypes). Example:
##   BT.sel([
##       BT.seq([BT.cond(&"cond_should_surrender"), BT.act(&"act_surrender")], "Surrender"),
##       BT.act(&"act_patrol"),
##   ])
## Authority: HOST
class_name BT
extends RefCounted


static func sel(children: Array[BTNode], name: String = "") -> BTSelector:
	var node: BTSelector = BTSelector.new()
	node.children = children
	node.label = name
	return node


static func seq(children: Array[BTNode], name: String = "", remember_running: bool = true) -> BTSequence:
	var node: BTSequence = BTSequence.new()
	node.children = children
	node.label = name
	node.remember_running = remember_running
	return node


static func parallel(children: Array[BTNode], success_threshold: int = 0, name: String = "") -> BTParallel:
	var node: BTParallel = BTParallel.new()
	node.children = children
	node.success_threshold = success_threshold
	node.label = name
	return node


## Condition on an agent method returning bool.
static func cond(method: StringName, args: Array = [], name: String = "") -> BTCall:
	return act(method, args, name)


## Action on an agent method returning BTNode.Status (or bool).
static func act(method: StringName, args: Array = [], name: String = "") -> BTCall:
	var node: BTCall = BTCall.new()
	node.method = method
	node.args = args
	node.label = name
	return node


static func check(key: StringName, op: BTCheck.Op = BTCheck.Op.EXISTS, value: Variant = null) -> BTCheck:
	var node: BTCheck = BTCheck.new()
	node.key = key
	node.op = op
	node.value = value
	return node


static func wait(seconds: float, random_extra: float = 0.0) -> BTWait:
	var node: BTWait = BTWait.new()
	node.seconds = seconds
	node.random_extra = random_extra
	return node


static func invert(child: BTNode) -> BTDecorator:
	return _decorate(BTDecorator.Mode.INVERT, child)


static func succeed(child: BTNode) -> BTDecorator:
	return _decorate(BTDecorator.Mode.SUCCEED, child)


static func repeat(child: BTNode, count: int = 0) -> BTDecorator:
	var node: BTDecorator = _decorate(BTDecorator.Mode.REPEAT, child)
	node.count = count
	return node


static func cooldown(child: BTNode, seconds: float) -> BTDecorator:
	var node: BTDecorator = _decorate(BTDecorator.Mode.COOLDOWN, child)
	node.seconds = seconds
	return node


static func time_limit(child: BTNode, seconds: float) -> BTDecorator:
	var node: BTDecorator = _decorate(BTDecorator.Mode.TIME_LIMIT, child)
	node.seconds = seconds
	return node


static func _decorate(mode: BTDecorator.Mode, child: BTNode) -> BTDecorator:
	var node: BTDecorator = BTDecorator.new()
	node.mode = mode
	node.child = child
	return node
