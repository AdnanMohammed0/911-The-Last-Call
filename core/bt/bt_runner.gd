## Runs a behavior tree for its parent agent on the host at `tick_rate` Hz, staggered so agents spread
## their work across frames (GAMEPLAY_MECHANICS §8: AI ticks at 10 Hz on the host only).
## Authority: HOST
class_name BTRunner
extends Node

const GROUP: StringName = &"bt_runners"

signal ticked(status: BTNode.Status)

@export var tree: BTNode
@export var tick_rate: float = 10.0
@export var enabled: bool = true

var blackboard: BTBlackboard = BTBlackboard.new()
var last_status: BTNode.Status = BTNode.Status.FAILURE

static var _stagger_counter: int = 0

var _accumulator: float = 0.0

@onready var agent: Node = get_parent()


func _ready() -> void:
	add_to_group(GROUP)
	# Spread agents over the tick interval.
	_stagger_counter += 1
	_accumulator = fposmod(float(_stagger_counter) * 0.37, 1.0) / maxf(tick_rate, 0.001)


func _physics_process(delta: float) -> void:
	if not enabled or tree == null or not multiplayer.is_server():
		return
	blackboard.time += delta
	_accumulator += delta
	var interval: float = 1.0 / maxf(tick_rate, 0.001)
	if _accumulator < interval:
		return
	_accumulator = fmod(_accumulator, interval)
	tick_now()


## One evaluation of the tree (also used by tests).
func tick_now() -> BTNode.Status:
	blackboard.begin_tick()
	last_status = tree.tick(agent, blackboard)
	blackboard.end_tick()
	ticked.emit(last_status)
	return last_status


## Stop whatever is running (death, surrender, level change).
func reset() -> void:
	if tree != null:
		tree.abort(agent, blackboard)
	blackboard = BTBlackboard.new()
