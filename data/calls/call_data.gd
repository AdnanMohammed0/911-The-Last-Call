## Authored 911 Call Resource (GAMEPLAY_MECHANICS §5.2).
class_name CallData
extends Resource

const VERDICTS: Array[StringName] = [&"prank", &"genuine", &"ambush", &"paranormal", &"ignore"]

enum Truth { PRANK, GENUINE, AMBUSH, PARANORMAL, DIVERSION }

## Unique call ID (e.g. &"call_closet_monster", &"call_meat_truck", &"call_cut_line").
@export var id: StringName = &""
## Internal / display title for case board and logs.
@export var title: String = ""
## Hidden ground truth evaluated against player verdict (GAMEPLAY_MECHANICS §5.7).
@export var truth: Truth = Truth.GENUINE
## Earliest shift minute when this call can ring (e.g. 80 = 01:20 in-game).
@export var earliest_minute: int = 0
## Required flag state for this call to trigger.
@export var requires_flags: Dictionary = {}
## Optional full call recording audio.
@export var caller_audio: AudioStream
## Branching dialogue graph for the call.
@export var dialogue: DialogueGraph
## Phone number displayed on caller ID.
@export var phone_number: String = "911-555-0100"
## Caller name or &"UNKNOWN".
@export var caller_name: String = "Unknown Caller"
## Location description reported by caller.
@export var caller_location_name: String = ""
## True map coordinates for cell tower tracing (Vector2).
@export var true_location: Vector2 = Vector2.ZERO
## Police archive records related to this number / address / name.
@export var records: Array[RecordEntry] = []
## Associated CCTV camera scenes.
@export var cctv_feeds: Array[PackedScene] = []
## Authored Voice Stress Analyzer profile (micro-tremor, pitch, loop segments, tags, BPM).
@export var stress_profile: StressProfile
## Associated field mission data (null = no field deployment possible).
@export var mission: Resource
## Maximum caller patience in seconds before hanging up (default 180s).
@export var patience_seconds: float = 180.0
## Ring timeout in seconds before call is marked MISSED (default 20s, GAMEPLAY §5.5).
@export var ring_timeout_seconds: float = 20.0


func is_valid_verdict(verdict: StringName) -> bool:
	return verdict in VERDICTS
