## Shift state machine and campaign-wide values (phase, clock, trust, budget).
## Authority: HOST (changes are made on the host and replicated via RPC).
extends Node

enum Phase { LOBBY, BRIEFING, DISPATCH, LOADOUT_VOTE, FIELD, AFTERMATH, FINALE, ENDING }

const SHIFT_START_MINUTES: int = 0     # 00:00
const SHIFT_END_MINUTES: int = 360     # 06:00
const FINALE_MINUTES: int = 300        # 05:00

const PHASE_SCENES: Dictionary[Phase, String] = {
	Phase.DISPATCH: "res://scenes/dispatch/operations_room.tscn",
	Phase.LOADOUT_VOTE: "res://scenes/loadout/armory.tscn",
	Phase.FIELD: "",  # resolved from MissionData
	Phase.AFTERMATH: "res://scenes/aftermath/shift_report.tscn",
}

var phase: Phase = Phase.LOBBY
var shift_clock_minutes: int = SHIFT_START_MINUTES
var public_trust: int = 75             # 0..100
var station_budget: int = 10000


func is_phase(p: StringName) -> bool:
	return phase_name(phase) == p


func is_lobby() -> bool:
	return phase == Phase.LOBBY


func phase_name(p: Phase) -> StringName:
	var keys: PackedStringArray = Phase.keys()
	return StringName(keys[p].to_lower())


## Host calls `change_phase.rpc(...)`; every peer applies it locally.
@rpc("authority", "call_local", "reliable")
func change_phase(new_phase: Phase, scene_path: String = "") -> void:
	phase = new_phase
	var path: String = scene_path if scene_path != "" else PHASE_SCENES.get(new_phase, "")
	if path != "" and ResourceLoader.exists(path):
		# TODO(P1-14): route through LevelLoader (threaded load + loading screen).
		get_tree().change_scene_to_file.call_deferred(path)
	EventBus.phase_changed.emit(phase_name(new_phase))


func reset() -> void:
	phase = Phase.LOBBY
	shift_clock_minutes = SHIFT_START_MINUTES
	public_trust = 75
	station_budget = 10000
