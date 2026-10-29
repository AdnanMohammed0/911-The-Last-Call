## Consequence rule (ARCHITECTURE §7.2): when `trigger_event` is recorded and every condition passes, its
## effects run immediately, after `delay` shift-clock minutes, at the start of a later shift, or are held for
## the ending resolver. Rules live under data/consequences/rules/ and are loaded by FlagSystem.
class_name ConsequenceRule
extends Resource

enum Timing { IMMEDIATE, DELAYED_MINUTES, NEXT_SHIFT, ENDING }

@export var id: StringName = &""
@export_multiline var description: String = ""
## Event id that triggers this rule (e.g. &"call_ignored").
@export var trigger_event: StringName = &""
## ALL must pass (evaluated against FlagSystem when the trigger is recorded).
@export var conditions: Array[FlagCondition] = []
@export var timing: Timing = Timing.IMMEDIATE
## Shift-clock minutes for DELAYED_MINUTES, shifts for NEXT_SHIFT.
@export var delay: int = 0
@export var effects: Array[FlagEffect] = []
## Fire at most once per campaign.
@export var once: bool = true


func conditions_pass(flag_system: Object) -> bool:
	for condition: FlagCondition in conditions:
		if condition != null and not condition.evaluate(flag_system):
			return false
	return true
