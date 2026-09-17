## Dialogue choice branch in a DialogueNode (GAMEPLAY_MECHANICS §5.6).
class_name DialogueChoice
extends Resource

## Display text for the response option shown on the handset / dispatch CRT.
@export var text: String = ""
## ID of the target DialogueNode to navigate to when selected.
@export var next: StringName = &""
## Class-exclusive requirement (e.g. &"profiler", &"tech", &"medic", &"breacher"). Empty if any class can select.
@export var required_class: StringName = &""
## Evidence keys required on Case Board (VSA tags, records, CCTV leads) to unlock this choice.
@export var required_evidence: Array[StringName] = []
## Flag conditions that must all evaluate to true.
@export var conditions: Array[FlagCondition] = []
## Modifier applied to caller patience seconds (+ to calm/gain time, - for hostile/wrong approach).
@export var patience_delta: float = 0.0
## Intel keys / clues added to Case Board upon selecting this choice.
@export var reveals: Array[StringName] = []


## True when a player of `class_id` who has collected `evidence` may pick this choice.
## Flag `conditions` are evaluated on the host by DialogueRunner / FlagSystem, not here.
func is_available_for(class_id: StringName, evidence: Array[StringName]) -> bool:
	if required_class != &"" and required_class != class_id:
		return false
	for key: StringName in required_evidence:
		if not key in evidence:
			return false
	return true
