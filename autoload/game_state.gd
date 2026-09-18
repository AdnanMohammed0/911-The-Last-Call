## Shift state machine and campaign-wide values (phase, clock, trust, budget, cult awareness).
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

# --- Global Meters (GAMEPLAY_MECHANICS §4) ---
const PUBLIC_TRUST_MIN: int = 0
const PUBLIC_TRUST_MAX: int = 100
const PUBLIC_TRUST_START: int = 75

const STATION_BUDGET_START: int = 10000

const CULT_AWARENESS_MIN: int = 0
const CULT_AWARENESS_MAX: int = 100
const CULT_AWARENESS_START: int = 0

# Public Trust thresholds
const TRUST_THRESHOLD_WITHHOLD: int = 40     # callers withhold address, hostile tone
const TRUST_THRESHOLD_SIEGE: int = 20        # fewer calls, siege ending weight up
const TRUST_THRESHOLD_TIPS: int = 80         # proactive cult tips

# Station Budget thresholds
const BUDGET_THRESHOLD_HALF_ARMORY: int = 3000    # half armory locked
const BUDGET_THRESHOLD_NO_HEAVY: int = 1000       # no heavy gear, 1 mag

# Cult Awareness thresholds
const CULT_THRESHOLD_COUNTER_AMBUSH: int = 60     # counter-ambush calls
const CULT_THRESHOLD_SIEGE: int = 90              # Station Siege triggered

var phase: Phase = Phase.LOBBY
## Scene every peer should be in for the current phase (used to bring reconnecting players back).
var current_scene_path: String = ""
var shift_clock_minutes: int = SHIFT_START_MINUTES
var public_trust: int = PUBLIC_TRUST_START             # 0..100
var station_budget: int = STATION_BUDGET_START
var cult_awareness: int = CULT_AWARENESS_START         # 0..100

# Track which thresholds have been crossed (to avoid re-triggering)
var _trust_crossed_withhold: bool = false
var _trust_crossed_siege: bool = false
var _trust_crossed_tips: bool = false
var _budget_crossed_half: bool = false
var _budget_crossed_no_heavy: bool = false
var _cult_crossed_counter: bool = false
var _cult_crossed_siege: bool = false


func _ready() -> void:
	if NetManager != null:
		NetManager.peer_joined.connect(_on_peer_joined)


func _on_peer_joined(peer_id: int, player_name: String) -> void:
	# Sync global meters to newly joined peer
	if multiplayer.is_server():
		_sync_global_meters.rpc_id(peer_id, public_trust, station_budget, cult_awareness)


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
	current_scene_path = path
	if path != "" and ResourceLoader.exists(path):
		# TODO(P1-14): route through LevelLoader (threaded load + loading screen).
		get_tree().change_scene_to_file.call_deferred(path)
	EventBus.phase_changed.emit(phase_name(new_phase))


func reset() -> void:
	phase = Phase.LOBBY
	current_scene_path = ""
	shift_clock_minutes = SHIFT_START_MINUTES
	public_trust = PUBLIC_TRUST_START
	station_budget = STATION_BUDGET_START
	cult_awareness = CULT_AWARENESS_START
	_reset_threshold_flags()

# ==============================================================================
# Global Meters - Modification Methods (HOST only)
# ==============================================================================

## Modify Public Trust (clamped 0-100). Emits threshold signals on cross.
func modify_public_trust(delta: int) -> void:
	if not _is_server():
		return
	var old_trust: int = public_trust
	public_trust = clampi(public_trust + delta, PUBLIC_TRUST_MIN, PUBLIC_TRUST_MAX)
	if old_trust != public_trust:
		EventBus.global_meter_changed.emit(&"public_trust", old_trust, public_trust)
		_check_trust_thresholds(old_trust, public_trust)

## Modify Station Budget (clamped at 0). Emits threshold signals on cross.
func modify_station_budget(delta: int) -> void:
	if not _is_server():
		return
	var old_budget: int = station_budget
	station_budget = maxi(station_budget + delta, 0)
	if old_budget != station_budget:
		EventBus.global_meter_changed.emit(&"station_budget", old_budget, station_budget)
		_check_budget_thresholds(old_budget, station_budget)

## Modify Cult Awareness (clamped 0-100). Emits threshold signals on cross.
func modify_cult_awareness(delta: int) -> void:
	if not _is_server():
		return
	var old_awareness: int = cult_awareness
	cult_awareness = clampi(cult_awareness + delta, CULT_AWARENESS_MIN, CULT_AWARENESS_MAX)
	if old_awareness != cult_awareness:
		EventBus.global_meter_changed.emit(&"cult_awareness", old_awareness, cult_awareness)
		_check_cult_thresholds(old_awareness, cult_awareness)

# ==============================================================================
# Threshold Checking (internal)
# ==============================================================================

func _check_trust_thresholds(old: int, new: int) -> void:
	# Crossed below 40: callers withhold address, hostile tone
	if old >= TRUST_THRESHOLD_WITHHOLD and new < TRUST_THRESHOLD_WITHHOLD and not _trust_crossed_withhold:
		_trust_crossed_withhold = true
		EventBus.trust_threshold_crossed.emit(&"withhold_address", new)
	elif old < TRUST_THRESHOLD_WITHHOLD and new >= TRUST_THRESHOLD_WITHHOLD:
		_trust_crossed_withhold = false
		EventBus.trust_threshold_crossed.emit(&"restored_address", new)
	
	# Crossed below 20: fewer calls, siege ending weight up
	if old >= TRUST_THRESHOLD_SIEGE and new < TRUST_THRESHOLD_SIEGE and not _trust_crossed_siege:
		_trust_crossed_siege = true
		EventBus.trust_threshold_crossed.emit(&"siege_weight_up", new)
	elif old < TRUST_THRESHOLD_SIEGE and new >= TRUST_THRESHOLD_SIEGE:
		_trust_crossed_siege = false
		EventBus.trust_threshold_crossed.emit(&"siege_weight_down", new)
	
	# Crossed above 80: proactive cult tips
	if old < TRUST_THRESHOLD_TIPS and new >= TRUST_THRESHOLD_TIPS and not _trust_crossed_tips:
		_trust_crossed_tips = true
		EventBus.trust_threshold_crossed.emit(&"cult_tips_unlocked", new)
	elif old >= TRUST_THRESHOLD_TIPS and new < TRUST_THRESHOLD_TIPS:
		_trust_crossed_tips = false
		EventBus.trust_threshold_crossed.emit(&"cult_tips_locked", new)

func _check_budget_thresholds(old: int, new: int) -> void:
	# Crossed below 3000: half armory locked
	if old >= BUDGET_THRESHOLD_HALF_ARMORY and new < BUDGET_THRESHOLD_HALF_ARMORY and not _budget_crossed_half:
		_budget_crossed_half = true
		EventBus.budget_threshold_crossed.emit(&"half_armory_locked", new)
	elif old < BUDGET_THRESHOLD_HALF_ARMORY and new >= BUDGET_THRESHOLD_HALF_ARMORY:
		_budget_crossed_half = false
		EventBus.budget_threshold_crossed.emit(&"half_armory_unlocked", new)
	
	# Crossed below 1000: no heavy gear, 1 magazine
	if old >= BUDGET_THRESHOLD_NO_HEAVY and new < BUDGET_THRESHOLD_NO_HEAVY and not _budget_crossed_no_heavy:
		_budget_crossed_no_heavy = true
		EventBus.budget_threshold_crossed.emit(&"no_heavy_gear", new)
	elif old < BUDGET_THRESHOLD_NO_HEAVY and new >= BUDGET_THRESHOLD_NO_HEAVY:
		_budget_crossed_no_heavy = false
		EventBus.budget_threshold_crossed.emit(&"heavy_gear_unlocked", new)

func _check_cult_thresholds(old: int, new: int) -> void:
	# Crossed above 60: counter-ambush calls
	if old < CULT_THRESHOLD_COUNTER_AMBUSH and new >= CULT_THRESHOLD_COUNTER_AMBUSH and not _cult_crossed_counter:
		_cult_crossed_counter = true
		EventBus.cult_threshold_crossed.emit(&"counter_ambush_active", new)
	elif old >= CULT_THRESHOLD_COUNTER_AMBUSH and new < CULT_THRESHOLD_COUNTER_AMBUSH:
		_cult_crossed_counter = false
		EventBus.cult_threshold_crossed.emit(&"counter_ambush_inactive", new)
	
	# Crossed above 90: Station Siege triggered
	if old < CULT_THRESHOLD_SIEGE and new >= CULT_THRESHOLD_SIEGE and not _cult_crossed_siege:
		_cult_crossed_siege = true
		EventBus.cult_threshold_crossed.emit(&"station_siege_triggered", new)
	# Note: siege trigger is one-way (doesn't revert)

func _reset_threshold_flags() -> void:
	_trust_crossed_withhold = false
	_trust_crossed_siege = false
	_trust_crossed_tips = false
	_budget_crossed_half = false
	_budget_crossed_no_heavy = false
	_cult_crossed_counter = false
	_cult_crossed_siege = false

func _is_server() -> bool:
	if multiplayer.multiplayer_peer == null:
		return true
	return multiplayer.is_server()

# ==============================================================================
# RPC Sync (HOST -> ALL)
# ==============================================================================

## Sync all global meters to a specific peer (or all peers if peer_id = 0).
@rpc("authority", "call_remote", "reliable")
func _sync_global_meters(peer_id: int, trust: int, budget: int, awareness: int) -> void:
	public_trust = trust
	station_budget = budget
	cult_awareness = awareness
	# Emit local signals so UI updates
	EventBus.global_meter_changed.emit(&"public_trust", public_trust, public_trust)
	EventBus.global_meter_changed.emit(&"station_budget", station_budget, station_budget)
	EventBus.global_meter_changed.emit(&"cult_awareness", cult_awareness, cult_awareness)

## Host: broadcast current meters to all peers (call when peer joins or on demand).
func broadcast_global_meters() -> void:
	if not _is_server():
		return
	_sync_global_meters.rpc(0, public_trust, station_budget, cult_awareness)
