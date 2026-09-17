# ARCHITECTURE — 911: The Last Call

> Technical architecture for a 2–4 player co-op dispatch simulator / tactical CQB / psychological horror game built on **Godot 4.x (GDScript)**.
> Source of truth for design intent: [`game_design_document_911_The_Last_call.md`](../game_design_document_911_The_Last_call.md) (working title in GDD: *911: Dead Line*).

---

## Table of Contents

1. [Guiding Principles](#1-guiding-principles)
2. [Project Layout](#2-project-layout)
3. [Autoload Singletons](#3-autoload-singletons)
4. [Multiplayer Architecture](#4-multiplayer-architecture)
5. [Scene & Phase State Machine](#5-scene--phase-state-machine)
6. [Voice Chat: Proximity & Radio](#6-voice-chat-proximity--radio)
7. [Global Event / Flag System (Butterfly Effect)](#7-global-event--flag-system-butterfly-effect)
8. [Save System](#8-save-system)
9. [Performance Budgets](#9-performance-budgets)
10. [Coding Standards](#10-coding-standards)

---

## 1. Guiding Principles

| Principle | Meaning in practice |
| :--- | :--- |
| **Host-authoritative** | The host (peer id `1`) owns *all* game truth: call generation, flag state, damage, AI, loot, votes. Clients send **intent**, never results. |
| **Data-driven content** | Calls, dialogue, missions, traits and consequences are `Resource` (`.tres`) or JSON files. Designers add a scenario without touching code. |
| **Transport-agnostic** | Gameplay code only talks to `MultiplayerAPI`. ENet (LAN / direct IP) and Steam P2P are swappable `MultiplayerPeer` implementations. |
| **Deterministic consequences** | Every choice resolves to an event → flag mutations → persisted. Same inputs = same world. Seeded RNG per shift. |
| **Signals up, calls down** | Children emit signals; parents call methods. The `EventBus` handles cross-tree communication. |

---

## 2. Project Layout

```text
res://
├── addons/                     # GodotSteam, voice plugins, dialogue tooling
├── autoload/                   # Singletons (see §3)
│   ├── event_bus.gd
│   ├── net_manager.gd
│   ├── game_state.gd
│   ├── flag_system.gd
│   ├── voice_manager.gd
│   └── save_manager.gd
├── core/
│   ├── net/                    # peer factories (enet_peer.gd, steam_peer.gd), rpc helpers
│   ├── fsm/                    # generic StateMachine + State base
│   └── bt/                     # lightweight behavior tree runtime
├── data/
│   ├── calls/                  # CallData .tres (one per 911 call)
│   ├── dialogue/               # DialogueGraph .tres
│   ├── missions/               # MissionData .tres
│   ├── traits/                 # TraitData .tres (limping, PTSD…)
│   ├── consequences/           # ConsequenceRule .tres
│   └── classes/                # ClassData .tres (stats per role)
├── scenes/
│   ├── boot/                   # splash, main menu, lobby
│   ├── dispatch/               # Station 4 operations room
│   ├── loadout/                # armory + vote screen
│   ├── field/                  # mission maps (farmhouse, flooded house, highway)
│   ├── aftermath/              # shift report
│   └── shared/                 # player, weapons, doors, interactables
├── ui/                         # HUD, terminals, waveform analyzer, radial menus
├── audio/                      # buses, SFX, call recordings, VO
└── tests/                      # GUT unit tests
```

---

## 3. Autoload Singletons

| Autoload | Responsibility | Authority |
| :--- | :--- | :--- |
| `EventBus` | Global typed signals (`call_received`, `flag_changed`, `player_downed`…) | Local only |
| `NetManager` | Host/join, peer lifecycle, lobby roster, transport selection | Host |
| `GameState` | Current shift, phase, players, class assignments, public trust, budget | Host → replicated |
| `FlagSystem` | Story flags, event log, consequence evaluation | Host → replicated |
| `VoiceManager` | Mic capture, Opus encode/decode, proximity + radio routing | Per peer |
| `SaveManager` | Campaign persistence (host machine), versioned migrations | Host |

```gdscript
# autoload/event_bus.gd
extends Node

signal phase_changed(new_phase: StringName)
signal call_received(call_id: StringName)
signal call_classified(call_id: StringName, verdict: StringName)
signal vote_finished(topic: StringName, result: Variant)
signal flag_changed(key: StringName, old_value: Variant, new_value: Variant)
signal trait_applied(peer_id: int, trait_id: StringName)
signal player_downed(peer_id: int)
signal player_revived(peer_id: int, by_peer: int)
signal sanity_changed(peer_id: int, value: float)
```

---

## 4. Multiplayer Architecture

### 4.1 Topology

```text
                   ┌────────────────────────── HOST (peer 1) ──────────────────────────┐
                   │ GameState · FlagSystem · CallDirector · AI · Damage · Save        │
                   │ MultiplayerSpawner(s) ─ spawns players, AI, props, projectiles    │
                   └────────▲──────────────────────▲──────────────────────▲────────────┘
        input / intent RPC  │  state sync + RPC     │                      │
                   ┌────────┴───────┐     ┌────────┴───────┐     ┌────────┴───────┐
                   │ Client (p 2)   │     │ Client (p 3)   │     │ Client (p 4)   │
                   │ prediction,    │     │ prediction,    │     │ prediction,    │
                   │ UI, audio, VFX │     │ UI, audio, VFX │     │ UI, audio, VFX │
                   └────────────────┘     └────────────────┘     └────────────────┘
```

* **Listen-server** (one player hosts). No dedicated server in scope for v1.0.
* Max **4 players**; lobby hard-caps at `MAX_PEERS = 4`.
* Tick: physics `60 Hz`, `MultiplayerSynchronizer` replication interval `1/30 s` for transforms, `on change` for discrete state.

### 4.2 Transport Layer

```gdscript
# autoload/net_manager.gd
extends Node

enum Transport { ENET, STEAM }

const DEFAULT_PORT := 24911
const MAX_PEERS := 4

signal lobby_updated(roster: Dictionary)
signal connection_failed(reason: String)

var transport: Transport = Transport.ENET
var roster: Dictionary = {}   # peer_id -> { "name": String, "class_id": StringName, "ready": bool }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit("Connection failed"))
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(player_name: String) -> Error:
	var peer := _create_peer()
	var err: Error
	if transport == Transport.ENET:
		err = (peer as ENetMultiplayerPeer).create_server(DEFAULT_PORT, MAX_PEERS - 1)
	else:
		err = peer.create_host(0)   # GodotSteam SteamMultiplayerPeer
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	roster[1] = {"name": player_name, "class_id": &"", "ready": false}
	lobby_updated.emit(roster)
	return OK

func join_game(address: String, player_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, DEFAULT_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(
		func(): _register_player.rpc_id(1, player_name), CONNECT_ONE_SHOT)
	return OK

func _create_peer() -> MultiplayerPeer:
	return ENetMultiplayerPeer.new() if transport == Transport.ENET else SteamMultiplayerPeer.new()

@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	roster[id] = {"name": player_name.left(24), "class_id": &"", "ready": false}
	_sync_roster.rpc(roster)

@rpc("authority", "call_local", "reliable")
func _sync_roster(new_roster: Dictionary) -> void:
	roster = new_roster
	lobby_updated.emit(roster)

func _on_peer_connected(_id: int) -> void:
	pass  # wait for _register_player

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		roster.erase(id)
		_sync_roster.rpc(roster)

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	roster.clear()
	get_tree().change_scene_to_file("res://scenes/boot/main_menu.tscn")
```

### 4.3 RPC Conventions

| Pattern | Annotation | Used for |
| :--- | :--- | :--- |
| **Client → Host intent** | `@rpc("any_peer", "call_remote", "reliable")` | Interact, fire request, vote, dialogue choice, classify call |
| **Host → All event** | `@rpc("authority", "call_local", "reliable")` | Phase change, flag update, call start, damage result |
| **Host → All cosmetic** | `@rpc("authority", "call_local", "unreliable")` | Muzzle flash, impact VFX, footstep ping |
| **Continuous state** | `MultiplayerSynchronizer` | Transforms, health, sanity, door open %, flashlight |

**Validation rule:** every `any_peer` RPC starts with a guard:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func request_classify_call(call_id: StringName, verdict: StringName) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not GameState.is_phase(&"dispatch") or not CallDirector.is_active(call_id):
		return
	if verdict not in CallData.VERDICTS:
		return
	CallDirector.submit_verdict(sender, call_id, verdict)
```

### 4.4 Player Replication

```text
Player (CharacterBody3D)          authority = owning peer (movement only)
├── PlayerInput (Node)            authority = owning peer → synchronizer replicates input
├── MultiplayerSynchronizer       replicates: position, rotation, velocity, stance, flashlight
├── Health (Node)                 authority = HOST → own synchronizer (hp, sanity, downed)
├── Head/Camera3D                 enabled only when is_multiplayer_authority()
├── VoiceEmitter (AudioStreamPlayer3D)
└── Equipment (Node3D)
```

* **Movement:** client-authoritative with host-side sanity checks (max speed × 1.2, teleport clamps) — acceptable for co-op; eliminates input latency.
* **Combat:** client sends `request_fire(origin, direction, weapon_seq)`; host re-casts the ray using the peer's last synced transform (± 150 ms lag compensation buffer), applies damage, broadcasts `on_hit`.
* **AI & damage:** always host.

```gdscript
# scenes/shared/player/player.gd
extends CharacterBody3D

@export var peer_id: int = 1:
	set(value):
		peer_id = value
		$PlayerInput.set_multiplayer_authority(value)
		set_multiplayer_authority(value)

func _ready() -> void:
	$Head/Camera3D.current = is_multiplayer_authority()
	set_physics_process(is_multiplayer_authority())
```

### 4.5 Spawning

* One `MultiplayerSpawner` per dynamic container (`Players`, `AI`, `Props`, `Projectiles`).
* Host calls `spawner.spawn(data)` with a custom `spawn_function` so class id + peer id arrive atomically.
* Scene transitions between phases are done by the host via `GameState.change_phase.rpc()`; all peers load the same scene under `World/Level`, a `MultiplayerSpawner` watching that node replicates it.

### 4.6 Late-Join & Disconnect Policy

| Situation | Policy |
| :--- | :--- |
| Join during lobby / dispatch | Allowed. Host sends full `GameState.snapshot()` + `FlagSystem.snapshot()`. |
| Join during field phase | Spectator until next aftermath. |
| Client drops mid-mission | Character becomes AI-controlled "unconscious" body for 60 s, then removed. Slot reserved by Steam ID. |
| Host drops | Session ends; campaign auto-saved at last phase boundary on host machine. (Host migration: out of scope v1.0.) |

---

## 5. Scene & Phase State Machine

The shift (00:00 → 06:00) is a host-driven FSM. Each state owns one root scene.

```text
LOBBY ─► BRIEFING ─► DISPATCH ─► LOADOUT_VOTE ─► FIELD ─► AFTERMATH ─┐
                        ▲                                            │
                        └────────────── (next call / next hour) ◄────┘
                                                        │
                                          05:00 ─► FINALE ─► ENDING ─► CAMPAIGN_SAVE
```

```gdscript
# autoload/game_state.gd  (excerpt)
extends Node

enum Phase { LOBBY, BRIEFING, DISPATCH, LOADOUT_VOTE, FIELD, AFTERMATH, FINALE, ENDING }

const PHASE_SCENES := {
	Phase.DISPATCH: "res://scenes/dispatch/operations_room.tscn",
	Phase.LOADOUT_VOTE: "res://scenes/loadout/armory.tscn",
	Phase.FIELD: "",  # resolved from MissionData
	Phase.AFTERMATH: "res://scenes/aftermath/shift_report.tscn",
}

var phase: Phase = Phase.LOBBY
var shift_clock_minutes: int = 0        # 0 = 00:00, 360 = 06:00
var public_trust: int = 75              # 0..100
var station_budget: int = 10000

func is_phase(p: StringName) -> bool:
	return Phase.keys()[phase].to_lower() == String(p)

@rpc("authority", "call_local", "reliable")
func change_phase(new_phase: Phase, scene_path: String = "") -> void:
	phase = new_phase
	var path := scene_path if scene_path != "" else PHASE_SCENES.get(new_phase, "")
	if path != "":
		LevelLoader.load_level(path)   # threaded load + loading screen
	EventBus.phase_changed.emit(Phase.keys()[new_phase])
```

**Vote system** (loadout, route choice, "respond / ignore"): host opens a vote with timeout; each peer's `request_vote` is validated; ties are broken by the class with authority on that topic (e.g. Profiler on call verdicts, Breacher on entry plan).

---

## 6. Voice Chat: Proximity & Radio

### 6.1 Requirements

| Channel | Behaviour |
| :--- | :--- |
| **Proximity (open mic / PTT)** | 3D positional, attenuated by distance and occlusion. Audible to AI (noise events). |
| **Radio (PTT key `V`)** | Non-positional, bandpass + distortion, squelch click in/out, range-limited by map zone, jammable by anomalies. |
| **Phone line (dispatch)** | Players at the dispatch desk hear the caller and can speak to scripted callers (Profiler stress analysis runs on caller audio, not on players). |
| **Dead Frequency (horror)** | Host can inject hallucinated voices / reversed player voices into a victim's radio only. |

### 6.2 Implementation Plan

**Phase A — Native Godot (ENet builds):**

1. `AudioStreamMicrophone` on a muted `Record` bus with `AudioEffectCapture`.
2. Every 20 ms: pull frames → downmix mono → resample 48 kHz → **Opus encode** (GDExtension, e.g. `godot-opus` / `twovoip`) → ~24 kbps.
3. Send via `rpc_id` on a dedicated **unreliable_ordered channel `2`** (`transfer_channel = 2`) so voice never blocks gameplay.
4. Receiver: jitter buffer (60 ms) → decode → push into `AudioStreamGenerator` playback on the speaker's `VoiceEmitter` (`AudioStreamPlayer3D`).
5. Voice activity detection (RMS gate) + push-to-talk.

**Phase B — Steam builds:** swap encoder/transport for `Steam.startVoiceRecording()` / `getVoice()` / `decompressVoice()` via GodotSteam; routing layer stays identical.

```gdscript
# autoload/voice_manager.gd  (routing layer — transport independent)
extends Node

const RADIO_BUS := &"VoiceRadio"
const PROX_BUS := &"VoiceProximity"
const VOICE_CHANNEL := 2

var radio_ptt_held := false

func route_packet(speaker_id: int, pcm: PackedVector2Array, is_radio: bool) -> void:
	var speaker: Node3D = PlayerRegistry.get_player(speaker_id)
	if speaker == null:
		return
	if is_radio and RadioNetwork.can_receive(speaker_id, multiplayer.get_unique_id()):
		_push(RadioReceiver.get_generator(speaker_id), pcm)       # 2D, RADIO_BUS
	else:
		_push(speaker.get_node("VoiceEmitter").generator, pcm)    # 3D, PROX_BUS

func _push(playback: AudioStreamGeneratorPlayback, pcm: PackedVector2Array) -> void:
	if playback and playback.can_push_buffer(pcm.size()):
		playback.push_buffer(pcm)
```

### 6.3 Audio Bus Layout

```text
Master
├── Music
├── SFX
│   └── Footsteps
├── Phone             (Caller audio → VoiceStressAnalyzer tap via AudioEffectSpectrumAnalyzer)
├── VoiceProximity    (Reverb send by room, LowPass when occluded)
├── VoiceRadio        (BandPass 300–3400 Hz, Distortion "lofi", Compressor, noise bed)
├── Panic             (dynamic: LowPass cutoff ← sanity, Reverb wet ← sanity)
└── Record            (muted, AudioEffectCapture)
```

Sanity drives the `Panic` bus in real time: `cutoff_hz = lerp(800.0, 20000.0, sanity / 100.0)`.

### 6.4 AI Hearing Integration

Every voice frame above the VAD gate emits `NoiseEvent(position, loudness)` to the host's `PerceptionSystem`. Whispering (low RMS) is safe; shouting attracts hostiles and anomalies.

---

## 7. Global Event / Flag System (Butterfly Effect)

### 7.1 Concepts

```text
 Player action ─► GameEvent ─► FlagSystem.apply() ─► flags / meters / traits mutate
                                        │
                                        ├─► ConsequenceRules evaluated (conditions → effects)
                                        ├─► EventLog appended (for shift report & ending)
                                        └─► replicated to clients (delta) + autosaved
```

| Term | Definition | Example |
| :--- | :--- | :--- |
| **Flag** | Named world fact (`bool` / `int` / `StringName`) | `cult_leader_interrogated = true` |
| **Meter** | Clamped numeric global | `public_trust` (0–100), `station_budget` |
| **Event** | Immutable record of something that happened | `call_ignored{call:"closet_monster"}` |
| **Consequence Rule** | Condition over flags/events → effects, optionally delayed | Ignored closet call → +45 min neighbours report blood, trust −20 |
| **Trait** | Persistent per-officer modifier with duration | `limping` for 2 days |

### 7.2 Resource Definitions

```gdscript
# data/consequences/consequence_rule.gd
class_name ConsequenceRule
extends Resource

enum Timing { IMMEDIATE, DELAYED_MINUTES, NEXT_SHIFT, ENDING }

@export var id: StringName
@export_multiline var description: String
@export var trigger_event: StringName                  # e.g. &"call_ignored"
@export var conditions: Array[FlagCondition] = []      # ALL must pass
@export var timing: Timing = Timing.IMMEDIATE
@export var delay: int = 0                             # minutes (shift clock) or shifts
@export var effects: Array[FlagEffect] = []
@export var once: bool = true
```

```gdscript
# data/consequences/flag_condition.gd
class_name FlagCondition
extends Resource

enum Op { EQ, NEQ, GT, GTE, LT, LTE, HAS_EVENT }

@export var key: StringName
@export var op: Op = Op.EQ
@export var value: Variant

func evaluate(fs: FlagSystem) -> bool:
	if op == Op.HAS_EVENT:
		return fs.has_event(key, value)
	var v = fs.get_flag(key)
	match op:
		Op.EQ:  return v == value
		Op.NEQ: return v != value
		Op.GT:  return v > value
		Op.GTE: return v >= value
		Op.LT:  return v < value
		Op.LTE: return v <= value
	return false
```

```gdscript
# data/consequences/flag_effect.gd
class_name FlagEffect
extends Resource

enum Kind { SET_FLAG, ADD_METER, APPLY_TRAIT, QUEUE_CALL, UNLOCK_MISSION, SPAWN_EVENT }

@export var kind: Kind
@export var key: StringName          # flag / meter / trait / call / mission id
@export var value: Variant           # new value, delta, duration...
@export var target: StringName = &"" # "" = global, "caller_peer", "all_officers", "random_officer"
```

### 7.3 FlagSystem Runtime

```gdscript
# autoload/flag_system.gd
extends Node

const RULES_DIR := "res://data/consequences/rules/"

var flags: Dictionary = {}          # StringName -> Variant
var events: Array[Dictionary] = []  # {id, t, shift, payload}
var pending: Array[Dictionary] = [] # {rule_id, due_shift, due_minute}
var fired_once: Dictionary = {}
var _rules_by_trigger: Dictionary = {}

func _ready() -> void:
	_load_rules()

func get_flag(key: StringName, default: Variant = null) -> Variant:
	return flags.get(key, default)

func has_event(event_id: StringName, match_payload: Variant = null) -> bool:
	for e in events:
		if e.id == event_id and (match_payload == null or e.payload.get("call") == match_payload):
			return true
	return false

## Host only. The single entry point for every narrative-relevant action.
func record_event(event_id: StringName, payload: Dictionary = {}) -> void:
	assert(multiplayer.is_server())
	var e := {"id": event_id, "t": GameState.shift_clock_minutes,
			  "shift": GameState.day_number, "payload": payload}
	events.append(e)
	for rule: ConsequenceRule in _rules_by_trigger.get(event_id, []):
		if rule.once and fired_once.has(rule.id):
			continue
		if rule.conditions.all(func(c): return c.evaluate(self)):
			_schedule(rule, payload)

func _schedule(rule: ConsequenceRule, payload: Dictionary) -> void:
	match rule.timing:
		ConsequenceRule.Timing.IMMEDIATE:
			_apply(rule, payload)
		ConsequenceRule.Timing.DELAYED_MINUTES:
			pending.append({"rule_id": rule.id, "due_shift": GameState.day_number,
							"due_minute": GameState.shift_clock_minutes + rule.delay, "payload": payload})
		ConsequenceRule.Timing.NEXT_SHIFT:
			pending.append({"rule_id": rule.id, "due_shift": GameState.day_number + rule.delay,
							"due_minute": 0, "payload": payload})
		ConsequenceRule.Timing.ENDING:
			pass  # evaluated by EndingResolver

## Called by the shift clock every in-game minute.
func tick(shift: int, minute: int) -> void:
	for p in pending.duplicate():
		if p.due_shift < shift or (p.due_shift == shift and p.due_minute <= minute):
			pending.erase(p)
			_apply(_find_rule(p.rule_id), p.payload)

func _apply(rule: ConsequenceRule, payload: Dictionary) -> void:
	fired_once[rule.id] = true
	for fx in rule.effects:
		match fx.kind:
			FlagEffect.Kind.SET_FLAG:      set_flag(fx.key, fx.value)
			FlagEffect.Kind.ADD_METER:     GameState.add_meter(fx.key, fx.value)
			FlagEffect.Kind.APPLY_TRAIT:   TraitSystem.apply(_resolve_target(fx.target, payload), fx.key, fx.value)
			FlagEffect.Kind.QUEUE_CALL:    CallDirector.enqueue(fx.key, fx.value)
			FlagEffect.Kind.UNLOCK_MISSION: set_flag(StringName("mission_unlocked_%s" % fx.key), true)
			FlagEffect.Kind.SPAWN_EVENT:   record_event(fx.key, payload)

func set_flag(key: StringName, value: Variant) -> void:
	var old = flags.get(key)
	if old == value:
		return
	flags[key] = value
	_replicate_flag.rpc(key, value)

@rpc("authority", "call_local", "reliable")
func _replicate_flag(key: StringName, value: Variant) -> void:
	var old = flags.get(key)
	flags[key] = value
	EventBus.flag_changed.emit(key, old, value)

func snapshot() -> Dictionary:
	return {"flags": flags, "events": events, "pending": pending, "fired_once": fired_once}

func _load_rules() -> void:
	for file in DirAccess.get_files_at(RULES_DIR):
		var rule := load(RULES_DIR + file.trim_suffix(".remap")) as ConsequenceRule
		if rule:
			_rules_by_trigger.get_or_add(rule.trigger_event, []).append(rule)

func _find_rule(id: StringName) -> ConsequenceRule:
	for list in _rules_by_trigger.values():
		for r in list:
			if r.id == id:
				return r
	return null

func _resolve_target(target: StringName, payload: Dictionary) -> Array[int]:
	match target:
		&"caller_peer":    return [payload.get("peer_id", 1)]
		&"all_officers":   return NetManager.roster.keys()
		&"random_officer": return [NetManager.roster.keys().pick_random()]
	return []
```

### 7.4 Campaign Save JSON Schema

```json
{
  "schema_version": 3,
  "campaign_id": "c7f1e1a2-5b0e-4b7c-9a41-2f9a1d0c1e77",
  "seed": 918273645,
  "day_number": 2,
  "shift_clock_minutes": 0,
  "meters": {
    "public_trust": 55,
    "station_budget": 7400,
    "cult_awareness": 30
  },
  "officers": {
    "76561198000000001": {
      "display_name": "Adnan",
      "class_id": "breacher",
      "health_max_mod": 0,
      "sanity": 100,
      "guilt": 10,
      "traits": [
        { "id": "limping", "remaining_days": 2, "source_event": "shot_in_leg@farmhouse" }
      ]
    },
    "76561198000000002": {
      "display_name": "Player 2",
      "class_id": "profiler",
      "sanity": 60,
      "guilt": 45,
      "traits": [
        { "id": "phantom_ringing", "remaining_days": -1, "source_event": "call_ignored@closet_monster" }
      ]
    }
  },
  "flags": {
    "closet_monster_resolved": "hostage_rescued",
    "lake_house_cleared": false,
    "cult_leader_interrogated": false,
    "ambush_radio_decrypted": true,
    "mission_unlocked_cult_hideout": true
  },
  "events": [
    { "id": "call_classified", "shift": 1, "t": 80, "payload": { "call": "closet_monster", "verdict": "staged_hostage" } },
    { "id": "mission_success", "shift": 1, "t": 140, "payload": { "mission": "closet_monster", "civilians_saved": 1 } }
  ],
  "pending": [
    { "rule_id": "meat_truck_leader_interrogation", "due_shift": 2, "due_minute": 30 }
  ],
  "ending_tracking": {
    "trap_calls_detected": 3,
    "trap_calls_total": 4,
    "victims_saved": 9,
    "victims_total": 11,
    "evidence_collected": ["cctv_tape_04", "cult_ledger"]
  }
}
```

### 7.5 Example Rule (from GDD Scenario 1)

```text
id:            closet_monster_ignored
trigger_event: call_ignored
conditions:    [ HAS_EVENT call_ignored == "closet_monster" ]
timing:        DELAYED_MINUTES, delay = 45
effects:
  - QUEUE_CALL     key=neighbour_blood_report
  - ADD_METER      key=public_trust  value=-20
  - SET_FLAG       key=closet_teen_dead value=true
  - APPLY_TRAIT    key=guilt_ringing value=-1  target=all_officers
```

### 7.6 Ending Resolver

Evaluated at 05:00, first match wins:

| Priority | Ending | Condition |
| :--- | :--- | :--- |
| 1 | **The Whistleblowers** | `trap_calls_detected == trap_calls_total` AND `victims_saved / victims_total > 0.8` AND `evidence_collected.size() >= 3` |
| 2 | **Station Under Siege** | `cult_lieutenant_arrested` AND NOT `cult_network_dismantled` — OR — `ambushes_disrupted >= 2` AND NOT `station_fortified` |
| 3 | **Lost in the Static** | fallback (failed analyses, rushed into trapped call, majority of team downed) |

---

## 8. Save System

* Saved **only on the host** at `user://campaigns/<campaign_id>.json` at every phase boundary (atomic write: `.tmp` → rename).
* `schema_version` + `SaveMigrations.gd` chain (`migrate_1_to_2`, `migrate_2_to_3`…).
* Steam builds mirror to Steam Cloud.
* Officers keyed by Steam ID (or a generated local UUID for ENet) so traits follow the *person* between sessions.

---

## 9. Performance Budgets

| Metric | Target (GTX 1060 / RX 580, 1080p) |
| :--- | :--- |
| Frame time | ≤ 16.6 ms (60 FPS), 1% low ≥ 45 FPS |
| Bandwidth per client | ≤ 64 kbps gameplay + 24 kbps per active speaker |
| Host CPU (AI) | ≤ 3 ms / frame for 12 active agents |
| RTT tolerance | Playable up to 150 ms |
| Level load | ≤ 8 s on SATA SSD |
| Memory | ≤ 3 GB RAM, ≤ 2.5 GB VRAM |

---

## 10. Coding Standards

* GDScript **static typing everywhere** (`untyped_declaration` warning = error).
* `snake_case` files/functions, `PascalCase` classes/nodes, `SCREAMING_CASE` constants.
* No `get_node("../../..")` — use `@export` node refs or unique names (`%Name`).
* Every networked script documents authority in its header: `## Authority: HOST`.
* Unit tests with **GUT** for `FlagSystem`, `ConsequenceRule`, `VoiceStressAnalyzer`, `TraitSystem`.
* Commits: Conventional Commits (`feat(net): …`, `fix(ai): …`).
