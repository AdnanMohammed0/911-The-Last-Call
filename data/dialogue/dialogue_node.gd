## Single node in a branching call dialogue graph (GAMEPLAY_MECHANICS §5.6).
class_name DialogueNode
extends Resource

## Unique node identifier within the DialogueGraph.
@export var id: StringName = &""
## Speaker label (e.g. &"caller", &"dispatcher", &"officer_dispatch", &"unknown").
@export var speaker: StringName = &"caller"
## Text spoken or displayed on CRT transcript.
@export_multiline var line: String = ""
## Caller audio line played over the Phone bus.
@export var audio: AudioStream
## Selectable player responses.
@export var choices: Array[DialogueChoice] = []
## Event IDs triggered when entering this node (sent to EventBus / FlagSystem).
@export var on_enter_events: Array[StringName] = []
## Next node ID when there are no choices (or when timer runs out).
@export var auto_next: StringName = &""
## Auto-advance delay in seconds (0.0 = advance when audio finishes or default pacing).
@export var auto_delay: float = 0.0
## Visual coordinates for GraphEdit in DialogueGraphEditor.
@export var editor_position: Vector2 = Vector2.ZERO
