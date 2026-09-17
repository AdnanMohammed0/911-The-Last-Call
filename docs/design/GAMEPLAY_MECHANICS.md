# GAMEPLAY MECHANICS — 911: The Last Call

> Setting: **Blackvale County, Station 4** — night shift 00:00 → 06:00. A cult called **Sons of the Dusk** and an unnamed entity abuse the county's old analog phone network (**The Dead Frequency**) to fake calls, lure officers into ambushes, and distract Station 4 from real crimes.

---

## Table of Contents

1. [Core Loop](#1-core-loop)
2. [Player Classes & Stat Balance](#2-player-classes--stat-balance)
3. [Health, Sanity & Traits](#3-health-sanity--traits)
4. [Global Meters](#4-global-meters)
5. [Dispatch Mechanics](#5-dispatch-mechanics)
6. [Loadout & Voting](#6-loadout--voting)
7. [Field Combat](#7-field-combat)
8. [AI: Hostile Behavior Trees](#8-ai-hostile-behavior-trees)
9. [AI: Ghost / Anomaly State Machines](#9-ai-ghost--anomaly-state-machines)
10. [Mission Catalog (Vertical Slice)](#10-mission-catalog-vertical-slice)
11. [Endings](#11-endings)
12. [Balancing Levers](#12-balancing-levers)

---

## 1. Core Loop

```text
[1. OPERATIONS ROOM] ──► [2. ASSESSMENT] ──► [3. LOADOUT & VOTE]
        ▲                                            │
        │                                            ▼
[5. AFTERMATH & CONSEQUENCES] ◄── [4. FIELD RESPONSE (FPS)]
```

| Phase | Duration (real time) | Player goal |
| :--- | :--- | :--- |
| Dispatch | 2–5 min per call | Keep caller talking, gather intel, trace, analyze stress |
| Assessment | ≤ 60 s | Classify: **Prank / Genuine / Suspected Ambush / Paranormal** — or **Ignore** |
| Loadout & Vote | ≤ 90 s | Pick gear within budget, vote on approach (lights & sirens / silent / on foot / decoy) |
| Field | 8–20 min | Breach, negotiate, arrest, fight, survive |
| Aftermath | 1–2 min | Shift report, trust/budget deltas, new traits, unlocked leads |

A shift contains **5–8 calls**; only **2–4** become field missions (time is the scarcest resource — while the team is in the field, the phone keeps ringing and missed calls generate consequences).

---

## 2. Player Classes & Stat Balance

### 2.1 Base Stats (100 = baseline)

| Stat | Tech Operator | Profiler / Negotiator | Breacher | Investigator / Medic |
| :--- | :---: | :---: | :---: | :---: |
| Max Health | 80 | 90 | **140** | 100 |
| Damage Resistance | 0 % | 5 % | **25 %** (+ shield) | 5 % |
| Max Sanity | 100 | **80** | 100 | **130** |
| Sanity Drain Mult. | 1.0× | **1.3×** | 0.9× | **0.7×** |
| Move Speed | **0.90×** | 1.00× | 0.95× (0.70× shield up) | 1.00× |
| Sprint Duration | 5 s | 7 s | 6 s | 7 s |
| Noise Footprint | 0.8× | 1.0× | **1.6×** | 0.9× |
| Aim Stability | 1.0× | 0.85× (hesitation) | 1.0× | 1.0× → **0.5× when panicked** |
| Carry Slots | 3 | 3 | 4 (heavy) | 4 (consumables) |
| Weapon Access | Pistol, SMG | Pistol, less-lethal | Shotgun, rifle, shield | Pistol |

### 2.2 Dispatch Abilities

| Class | Primary Tool | Ability | Cooldown / Cost |
| :--- | :--- | :--- | :--- |
| **Tech Operator** | Trace Console | *Triangulate*: 3-tower mini-game narrows location radius 2 km → 50 m | Needs caller on line ≥ 25 s |
| | CCTV Grid | *Tap Cam*: hijack up to 3 cameras near trace | 1 per call |
| | Records DB | *Deep Lookup*: phone owner, criminal record, property history | 30 s search |
| **Profiler** | Voice Stress Analyzer | *Stress Read*: reveals micro-tremor band (8–12 Hz) & loop detection | Passive while listening |
| | Lie Detector | *Challenge*: special dialog option — high reward, can end call | 2 per call |
| | Script Book | *Rapport*: unlocks calmer caller branches (+info, −panic) | — |
| **Breacher** | Tactical Map | *Entry Plan*: marks breach points, reveals floor plan quality | 1 per mission |
| | Armory | *Requisition*: −15 % cost on heavy gear | Passive |
| **Investigator / Medic** | Case Board | *Pattern Link*: connects current call to prior events/flags (paranormal tells) | 1 per call |
| | EMF Log | *Anomaly Check*: flags number as "Dead Frequency" origin (70 % reliable, 100 % with 2 checks) | 2 per shift |

### 2.3 Field Abilities

| Class | Ability | Effect | Cooldown |
| :--- | :--- | :--- | :--- |
| **Tech Operator** | Recon Drone | 45 s flight, marks enemies for 10 s, can open e-locks | 120 s |
| | Hack Terminal | Doors, alarms, lights, cameras | Per device |
| **Profiler** | Megaphone Negotiation | Morale check on hostiles in 15 m; success → surrender | 60 s |
| | Tear Gas | 6 m cloud, hostiles −60 % accuracy for 8 s | 2 charges |
| **Breacher** | Kick Door | Instant open, stuns enemies behind door 1.5 s | 4 s |
| | Ballistic Shield | Blocks 100 % frontal bullets (shield HP 600), slows | Toggle |
| | Battering Ram | Opens reinforced doors / walls marked breakable | 3 uses |
| **Investigator / Medic** | Revive | Downed → 40 % HP in 4 s (channel) | — |
| | Sedative | +35 sanity, −10 % aim for 20 s | 3 charges |
| | Salt Line / Reverse Tone | Anomaly barrier (30 s) / banish channel (8 s) | 2 each |

### 2.4 Balance Rules

* **No class is optional** — each owns at least one hard gate: Tech (e-locks & traces), Profiler (surrender & loop detection), Breacher (reinforced doors), Medic (revive & banish).
* **2-player scaling:** missing roles are covered by *Station Assist* (AI dispatcher) at 50 % effectiveness, and hard gates get alternate slower paths.
* **Time-to-kill targets:** civilian hostile → player: 4–6 hits (Breacher 7–9). Player → hostile: 2–3 torso hits.

---

## 3. Health, Sanity & Traits

### 3.1 Health

* HP regenerates to the nearest **25 %** step only.
* At 0 HP → **Downed** (45 s bleed-out, crawl allowed). Revive by Medic (4 s) or any player with a Trauma Kit (8 s).
* Bleed-out → **Critical** (removed for mission, lingering trait roll at 100 %).
* Location damage: head ×2.0, torso ×1.0, legs ×0.75 (leg hit rolls *Limping*), arms ×0.75 (arm hit rolls *Fractured Hand*).

### 3.2 Sanity (0–Max)

| Band | Range | Effects |
| :--- | :--- | :--- |
| **Steady** | 70–100 % | None |
| **Uneasy** | 40–69 % | Faint whispers, occasional false footstep, Panic bus lowpass starts |
| **Panicked** | 15–39 % | Hallucinated enemies (no collision), phantom phone rings, aim sway ×1.5, flashlight flicker |
| **Broken** | 0–14 % | Radio receives Dead Frequency voices mimicking teammates, random input-flinch, can be *possessed* by Class-B anomalies |

**Drain sources:** darkness (−0.5/s), witnessing a death (−15), anomaly manifestation in view (−8/s), hearing victim die on phone (−20 + *Guilt*), teammate downed (−10).
**Restore:** light zones (+0.3/s), Sedative (+35), completing objective (+10), Medic aura (+0.5/s within 5 m), aftermath rest (+40).

### 3.3 Guilt (hidden meter, 0–100)

Raised by ignored genuine calls, civilian deaths, excessive force on pranks. Guilt ≥ 50 unlocks **Phantom Ringing**; ≥ 80 enables **The Caller** anomaly to target that officer specifically.

### 3.4 Traits (Persistent, Detroit-style)

| Trait | Type | Trigger | Effect | Duration | Cure |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Limping** | Physical | Leg hit ≥ 30 dmg | Speed −30 %, loud drag footstep (+40 % noise) | 2 shifts | Medical leave (sit out 1 mission) |
| **Fractured Hand** | Physical | Arm hit or melee block fail | Scope sway +60 %, reload +50 % | 2 shifts | Splint (Medic, $400) |
| **Concussion** | Physical | Explosion within 5 m | Periodic blur, UI flicker | 1 shift | Rest |
| **Scarred** | Physical | Revived 3× in one shift | Max HP −10 | Permanent | — |
| **PTSD** | Psychological | Sanity hit 0 | Gunfire drains sanity 2×, flashbacks on trigger audio | 3 shifts | Counseling ($800) |
| **Phantom Ringing** | Psychological | Guilt ≥ 50 | Hears nonexistent phones in field | Until guilt < 30 | Resolve a related case |
| **Nyctophobia** | Psychological | ≥ 60 s in total darkness while Panicked | Darkness drain 2× | 2 shifts | Counseling |
| **Hardened** | Positive | Survive 3 ambushes | Sanity drain −15 % | Permanent | — |
| **Community Hero** | Positive | Save 5 civilians | Callers give +1 free intel line | While trust ≥ 60 | — |
| **Marked by Dusk** | Story | Seen by cult leader, escaped | Cult ambushes prioritize this officer | Until cult dismantled | Story |

```gdscript
# data/traits/trait_data.gd
class_name TraitData
extends Resource

enum Category { PHYSICAL, PSYCHOLOGICAL, POSITIVE, STORY }

@export var id: StringName
@export var display_name: String
@export var category: Category
@export var icon: Texture2D
@export var duration_shifts: int = -1          # -1 = permanent / conditional
@export var stat_modifiers: Dictionary = {}    # { &"move_speed": 0.7, &"noise": 1.4 }
@export var cure_cost: int = 0
@export var hooks: Array[StringName] = []      # scripted behaviours, e.g. &"phantom_ringing"
```

---

## 4. Global Meters

| Meter | Range | Up | Down | Consequence Thresholds |
| :--- | :--- | :--- | :--- | :--- |
| **Public Trust** | 0–100 (start 75) | Rescues (+5–15), quick genuine response (+3) | Ignored genuine (−10–20), excessive force on prank (−10), civilian casualty (−15) | < 40: callers withhold exact address, hostile tone. < 20: fewer calls, Siege ending weight ↑. ≥ 80: proactive tips about cult movement |
| **Station Budget** | $ (start 10,000) | Mission success (+1,500), evidence (+500) | Destroyed cruiser (−3,000), wasted ammo (−$2/round), cures | < 3,000: half armory locked. < 1,000: no heavy gear, 1 magazine |
| **Cult Awareness** | 0–100 | Disrupting ambushes (+15), arrests (+10) | Staying quiet / decoys (−5) | ≥ 60: counter-ambush calls. ≥ 90: Station Siege triggered |

---

## 5. Dispatch Mechanics

### 5.1 Call Lifecycle

```text
RINGING (≤ 20 s, missed = "call_missed" event)
   │ answer
   ▼
CONNECTED ──► dialog graph runs ──► tools usable (trace, CCTV, VSA, records)
   │ hang-up / caller drops / timer
   ▼
ASSESSMENT (verdict + response type) ──► QUEUED / DISPATCHED / IGNORED
```

**Call types (hidden truth):** `PRANK`, `GENUINE`, `AMBUSH`, `PARANORMAL`, `DIVERSION` (genuine-sounding, pulls team away while a real crime happens elsewhere).

### 5.2 CallData Resource

```gdscript
# data/calls/call_data.gd
class_name CallData
extends Resource

const VERDICTS := [&"prank", &"genuine", &"ambush", &"paranormal", &"ignore"]

enum Truth { PRANK, GENUINE, AMBUSH, PARANORMAL, DIVERSION }

@export var id: StringName
@export var truth: Truth
@export var earliest_minute: int = 0         # 80 = 01:20
@export var requires_flags: Dictionary = {}
@export var caller_audio: AudioStream
@export var dialogue: DialogueGraph
@export var phone_number: String
@export var true_location: Vector2           # map coords
@export var records: Array[RecordEntry] = []
@export var cctv_feeds: Array[PackedScene] = []
@export var stress_profile: StressProfile
@export var mission: MissionData              # null = no field response possible
@export var patience_seconds: float = 180.0   # caller hangs up after this
```

### 5.3 Voice Stress Analyzer (VSA)

The caller audio plays through the `Phone` bus. An `AudioEffectSpectrumAnalyzer` feeds the VSA UI; **gameplay truth comes from authored `StressProfile` curves** (so results are deterministic and designable), while the live spectrum provides visual authenticity.

```gdscript
# data/calls/stress_profile.gd
class_name StressProfile
extends Resource

@export var tremor_curve: Curve        # 0..1 micro-tremor over call time (normalized)
@export var pitch_variance: Curve      # 0..1
@export var loop_segments: Array[Vector2] = []   # [start_s, end_s] repeated/pre-recorded audio
@export var background_tags: Array[StringName] = [] # &"adult_breathing", &"emf_hum", &"highway_silence"
@export var baseline_heart_rate: int = 80         # AMBUSH callers: abnormally stable despite screaming
```

| VSA Readout | What it reveals | Example (GDD) |
| :--- | :--- | :--- |
| **Tremor band 8–12 Hz** | Real fear = high & erratic; acting = flat | Meat Truck: caller screams but tremor flat → **Ambush** |
| **Loop detector** | Identical waveform segments → pre-recorded | Closet Monster: laughter repeats every 3.2 s |
| **Background isolate** | Profiler filters caller voice to hear room | Closet Monster: muffled adult breathing |
| **EMF interference** | 50–60 Hz hum + sub-bass → Dead Frequency | Cut Line: flooded house caller |
| **Pulse estimate** | BPM from breath rhythm | Meat Truck: 72 BPM while "under fire" |

**Mini-game:** the Profiler drags a **scrub window** over the waveform; placing it on a tell and pressing *Tag* adds evidence to the Case Board. Wrong tags cost caller patience.

### 5.4 Trace Mini-game (Tech Operator)

1. Caller must remain connected. Each cell tower lock takes 6–10 s.
2. Three rotating signal dials must be aligned (frequency, phase, gain) while noise drifts.
3. Result radius: 1 tower = 2 km, 2 towers = 400 m, 3 towers = 50 m.
4. **Dead Frequency calls** return an impossible location (a demolished building, a lake) — itself a clue.

### 5.5 Timer Pressure

| Timer | Default | Modifiers |
| :--- | :--- | :--- |
| Ring timeout | 20 s | — |
| Caller patience | 120–240 s | Rapport +30 s, wrong Challenge −60 s, Trust < 40 → −25 % |
| Assessment window | 60 s | Unanimous verdict ends early |
| Response window | Mission-specific (e.g. 20 in-game min) | Late arrival → victim state worsens |
| Shift clock | 1 real minute = 6 in-game minutes in Dispatch; paused in Field; each field mission advances a fixed block (30–60 min) | |

### 5.6 Branching Dialogue Graph

```gdscript
# data/dialogue/dialogue_node.gd
class_name DialogueNode
extends Resource

@export var id: StringName
@export var speaker: StringName = &"caller"
@export_multiline var line: String
@export var audio: AudioStream
@export var choices: Array[DialogueChoice] = []
@export var on_enter_events: Array[StringName] = []    # FlagSystem.record_event ids
@export var auto_next: StringName = &""                # when no choices
@export var auto_delay: float = 0.0
```

```gdscript
# data/dialogue/dialogue_choice.gd
class_name DialogueChoice
extends Resource

@export var text: String
@export var next: StringName
@export var required_class: StringName = &""            # &"profiler" -> class-exclusive option
@export var required_evidence: Array[StringName] = []   # VSA tags or records unlocked
@export var conditions: Array[FlagCondition] = []
@export var patience_delta: float = 0.0
@export var reveals: Array[StringName] = []             # intel keys added to Case Board
```

**Choice resolution in co-op:** whoever holds the headset (the "Handset" token, passed with `E`) selects dialogue. Others use tools and can *ping* a suggested choice (visible to handset holder).

### 5.7 Assessment Outcomes Matrix

| Truth ↓ / Verdict → | Prank | Genuine | Ambush | Paranormal | Ignore |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PRANK** | ✅ +trust small, time saved | Wasted trip, −budget | Heavy force → −trust | Wasted gear | ✅ neutral |
| **GENUINE** | ❌ victim harmed, −trust, +guilt | ✅ | Slow approach, victim risk ↑ | Wrong gear | ❌ severe |
| **AMBUSH** | ❌ delayed cult payoff | ⚠ enter trap (enemies alerted, +1 wave) | ✅ flank bonus, surprise | ⚠ trap | Cult awareness −, missed lead |
| **PARANORMAL** | ❌ haunting spreads (radio bleed) | ⚠ no EMF gear | ⚠ | ✅ | ❌ blackout district |
| **DIVERSION** | ❌ | ⚠ real crime elsewhere succeeds | ⚠ | ⚠ | ✅ if other call answered |

---

## 6. Loadout & Voting

* **Budget-limited armory:** each item has a requisition cost; station budget is shared.
* **Class-locked items** (Shield: Breacher; Drone: Tech; Megaphone: Profiler; EMF/Salt: Medic).
* **Approach vote** (majority, ties broken by Breacher):
  * *Code 3* (lights & sirens) — fastest arrival, enemies alerted.
  * *Silent approach* — +3 in-game min, surprise.
  * *On foot via back route* — +8 min, flank spawn.
  * *Decoy cruiser* — requires ≥ 3 players *or* Tech drone; cruiser may be destroyed (−$3,000).

| Item | Cost | Slot | Notes |
| :--- | ---: | :--- | :--- |
| Service Pistol | 0 | Sidearm | Always free |
| Pump Shotgun | 400 | Primary | Breacher −15 % |
| Patrol Rifle | 700 | Primary | |
| Ballistic Shield | 900 | Heavy | Breacher only |
| Battering Ram | 300 | Heavy | Breacher only |
| Recon Drone | 600 | Gadget | Tech only |
| Tear Gas ×2 | 250 | Throwable | |
| Trauma Kit | 200 | Consumable | Any class can revive (slow) |
| Sedatives ×3 | 300 | Consumable | Medic |
| EMF Reader | 150 | Gadget | Medic; others at 50 % accuracy |
| Salt Canister | 120 | Consumable | |
| Spectral Tone Emitter | 500 | Gadget | Banish ritual |

---

## 7. Field Combat

* **Hitscan** for firearms with authored recoil patterns; **projectiles** for thrown gear.
* **ROE (Rules of Engagement):** shooting a surrendered/unarmed suspect → −15 trust, +20 guilt, "Excessive Force" event.
* **Arrest:** hostile at *Surrender* state → hold `F` 2 s to cuff. Arrested leaders unlock interrogation calls next shift.
* **Doors:** open (quiet), peek (crack 15°), kick (Breacher, loud, stun), ram (reinforced), hack (e-lock), trap check (Tech drone/Medic EMF flags tripwires).
* **Light as resource:** flashlight battery 180 s; anomalies feed on light (see §9).
* **Noise system:** every action emits `NoiseEvent(pos, radius)`: walk 4 m, sprint 10 m, Breacher walk 7 m, kick 25 m, gunshot 60 m, voice RMS-scaled 2–20 m.

---

## 8. AI: Hostile Behavior Trees

### 8.1 Archetypes

| Archetype | HP | Weapons | Morale | Traits |
| :--- | ---: | :--- | ---: | :--- |
| **Thug** (armed robber) | 100 | Pistol | 40 | Surrenders easily |
| **Cultist Gunman** (Sons of the Dusk) | 120 | Rifle / shotgun | 70 | Uses flanks, cover |
| **Cult Zealot** | 90 | Machete / IED vest | 100 (fanatic) | Rushes, never surrenders |
| **Ambush Leader** | 160 | Rifle, RPG (scripted) | 85 | Calls reinforcements, arrestable → intel |
| **Hostage Taker** | 110 | Pistol held to hostage | 55 | Negotiable; executes hostage on loud breach (50 %) |

### 8.2 Perception

* **Vision cone:** 100°, 30 m (lit), 8 m (dark); flashlight beam on the AI = instant detection within 25 m.
* **Hearing:** `NoiseEvent` within radius → investigate.
* **Awareness meter** 0 → 1: `Unaware → Suspicious (0.3) → Searching (0.6) → Combat (1.0)`; shared to squad via "callout" after 1.5 s.

### 8.3 Behavior Tree (Cultist Gunman)

```text
Root (Selector)
├── [Sequence] Surrender
│   ├── Cond: morale < 20 AND not fanatic
│   ├── Cond: players_visible >= 2 OR negotiated
│   └── Act: DropWeapon → HandsUp → WaitForArrest
├── [Sequence] Flee
│   ├── Cond: hp < 25% AND morale < 40
│   └── Act: FindEscapeRoute → Sprint
├── [Sequence] Combat
│   ├── Cond: awareness >= 1.0
│   └── [Selector]
│       ├── [Sequence] Reload         (Cond: ammo == 0 → Act: MoveToCover → Reload)
│       ├── [Sequence] ThrowGrenade   (Cond: target_in_cover > 4 s AND has_grenade)
│       ├── [Sequence] Flank          (Cond: squad_size >= 2 AND flank_token_free → Act: TakeFlankToken → MoveFlankPath)
│       ├── [Sequence] SuppressFromCover (Cond: in_cover → Act: PeekAndFire(burst 3))
│       └── Act: MoveToBestCover (EQS: distance 8–20 m, LoS to target, not flanked)
├── [Sequence] Search
│   ├── Cond: awareness >= 0.6
│   └── Act: MoveTo(last_known_pos) → SweepArea(15 s) → Decay awareness
├── [Sequence] Investigate
│   ├── Cond: awareness >= 0.3
│   └── Act: LookAt(noise) → WalkTo(noise_pos) → Wait(4 s)
└── Act: Patrol / IdleAnim
```

**Morale** modifiers: ally killed −15, leader killed −30, shield-wall of Breacher visible −10, megaphone success −25, tear gas −20, outnumbering players +10.

```gdscript
# core/bt/bt_node.gd
class_name BTNode
extends Resource

enum Status { SUCCESS, FAILURE, RUNNING }

func tick(_agent: Node, _bb: Dictionary) -> Status:
	return Status.FAILURE
```

```gdscript
# core/bt/bt_selector.gd
class_name BTSelector
extends BTNode

@export var children: Array[BTNode] = []

func tick(agent: Node, bb: Dictionary) -> Status:
	for child in children:
		var s := child.tick(agent, bb)
		if s != Status.FAILURE:
			return s
	return Status.FAILURE
```

AI runs **only on host**, ticks at **10 Hz** (staggered across agents), movement via `NavigationAgent3D` with avoidance; animation state replicated through a `MultiplayerSynchronizer` (`anim_state`, `aim_target`).

---

## 9. AI: Ghost / Anomaly State Machines

### 9.1 Anomaly Classes

| Anomaly | Class | Mission | Gimmick | Weakness |
| :--- | :--- | :--- | :--- | :--- |
| **The Drowned Woman** | B (hunter) | Cut Line (flooded house) | Floods rooms (water rising = slow), kills flashlights | Salt line, reverse tone, burying bones |
| **The Caller** | A (stalker) | Any (guilt ≥ 80) | Rings phones in the field, mimics teammate on radio | Answering and staying silent 10 s |
| **Static Shade** | C (swarm) | Tunnel / asylum | Many weak shadows, only visible in camera / drone feed | Bright light bursts |
| **The Listener** | B | Late shifts | Blind, hunts by voice chat loudness | Silence, whispering |

### 9.2 State Machine (Drowned Woman)

```text
             ┌──────────────── banished (ritual complete) ───────────────┐
             ▼                                                           │
 DORMANT ──(EMF ≥ 3 or player enters basement)──► MANIFEST ──► STALK ──► HUNT ──► ATTACK
    ▲           ▲                                     │           │        │          │
    │           └────────── (light off 20 s) ─────────┘           │        │          │
    │                                                             │        ▼          │
    └──── (salt line / all players leave zone) ◄── RETREAT ◄──────┴── (reverse tone) ◄┘
```

| State | Behaviour | Exit |
| :--- | :--- | :--- |
| **Dormant** | Ambient EMF 1–2, cold breath VFX, drips | EMF ≥ 3 interaction, basement entry, shift minute trigger |
| **Manifest** | Lights flicker, doors slam & lock, sanity drain 4/s in LoS | 6 s → Stalk |
| **Stalk** | Teleports between dark nodes out of LoS, targets lowest-sanity player, whispers their name on their radio | Target sanity < 40 or 45 s → Hunt |
| **Hunt** | Physical chase (speed 1.1× player walk, 0.8× sprint), kills lights within 6 m, water rises | Within 2 m → Attack; reverse tone → Retreat |
| **Attack** | Grab (3 s QTE for teammates to break with light/salt), 60 dmg + 40 sanity | Released → Retreat |
| **Retreat** | Vanishes, cooldown 30–60 s | → Stalk / Dormant |

```gdscript
# scenes/field/anomalies/drowned_woman.gd  (excerpt)
## Authority: HOST
extends CharacterBody3D

enum State { DORMANT, MANIFEST, STALK, HUNT, ATTACK, RETREAT, BANISHED }

@export var hunt_speed := 3.8
@export var stalk_duration := 45.0

var state: State = State.DORMANT
var target_peer: int = -1
var _state_time := 0.0

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_state_time += delta
	match state:
		State.DORMANT:  _tick_dormant()
		State.MANIFEST: if _state_time > 6.0: _enter(State.STALK)
		State.STALK:    _tick_stalk()
		State.HUNT:     _tick_hunt(delta)
		State.ATTACK:   pass  # resolved by grab QTE
		State.RETREAT:  if _state_time > randf_range(30.0, 60.0): _enter(State.STALK)

func _tick_stalk() -> void:
	target_peer = SanitySystem.lowest_sanity_peer_in_zone(zone_id)
	if SanitySystem.get_sanity(target_peer) < 40.0 or _state_time > stalk_duration:
		_enter(State.HUNT)

func on_reverse_tone_complete() -> void:
	_enter(State.RETREAT)

func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_play_state_fx.rpc(new_state)

@rpc("authority", "call_local", "reliable")
func _play_state_fx(s: State) -> void:
	$StateFX.play(State.keys()[s].to_lower())
```

### 9.3 Director (Horror Pacing)

A host-side **Tension Director** tracks `tension` (0–1) from recent damage, sanity, and time since last scare:

* `tension < 0.3` for 90 s → schedule a scare (hallucination, door slam, radio mimic).
* `tension > 0.8` → suppress new manifestations, allow recovery beat.
* Hallucinations are **per-peer** (sent via `rpc_id`), so players see *different* things — fuels voice-chat paranoia.

---

## 10. Mission Catalog (Vertical Slice)

### 10.1 "Scratching Behind the Wall" — prank turned trap (01:20)

* **Call:** hysterical teen: *a black monster is coming out of my closet and eating my cat.*
* **Tells:** laugh loop every 3.2 s (VSA loop detector), muffled adult breathing (background isolate), phone registered to a house whose owner reported a break-in.
* **Ignore:** +45 min neighbour reports blood under the door → teen dead (escaped convict in black mask), trust −20, guilt +.
* **Correct (Staged Hostage):** silent approach; Breacher takes back door, Tech hijacks cams → rescue teen, find **notebook detailing the next ambush on the station** (`flag: station_ambush_intel`).

### 10.2 "Call From a Cut Line" — paranormal

* **Call:** distorted woman: *the water is so cold… I can't get out of the basement… it's locked from the outside.*
* **Tells:** EMF hum on VSA; Tech lookup → house abandoned, basement flooded 2011, owner drowned.
* **Close as tech fault:** +30 min district blackout, her voice bleeds into team radios for the rest of the shift.
* **Respond with anomaly kit:** EMF spikes at basement; doors lock; Drowned Woman encounter; Medic uses salt + reverse tone while team finds and buries remains → curse broken (`flag: lake_house_cleared`).

### 10.3 "The Meat Truck" — armed ambush dilemma

* **Call:** trucker broke down on abandoned highway, gunmen surrounding him.
* **Tells:** no cameras; caller pulse steady (72 BPM) despite screaming.
* **Tactic:** approach on foot via dirt road, send empty cruiser with sirens as decoy.
* **Field:** cult fires RPG at empty cruiser (−$3,000 unless Tech remote-drives it off the road), team flanks → CQB → **arrest Ambush Leader** → interrogation call next shift reveals cult hideout (`mission_unlocked_cult_hideout`).

---

## 11. Endings

| Ending | Conditions | Outcome |
| :--- | :--- | :--- |
| **The Whistleblowers** (Gold) | All trap calls detected, > 80 % victims saved, key evidence (CCTV + computers) collected | Raid on cult HQ, leaders arrested, federal backup at sunrise |
| **Station Under Siege** | Cult lieutenant arrested without dismantling network, *or* ambushes foiled without fortifying station | Power & comms cut; final minutes = horde-survival defense in the operations room |
| **Lost in the Static** | Failed voice analyses, rushed into trapped call, most of team dead/injured | Team trapped in abandoned tunnel / haunted asylum; station screens turn to white noise; a new shift begins with another team searching for you |

---

## 12. Balancing Levers

All numbers live in `data/balance/balance.tres` (exposed as `@export` fields) and can be hot-reloaded in debug builds via `F9`.

| Lever | Default | Affects |
| :--- | ---: | :--- |
| `sanity_dark_drain` | 0.5 /s | Horror intensity |
| `caller_patience_base` | 180 s | Dispatch difficulty |
| `ambush_call_ratio` | 0.25 | Paranoia vs. trust |
| `trust_start` | 75 | Early-game forgiveness |
| `budget_start` | 10,000 | Gear freedom |
| `ai_accuracy_mult` | 1.0 | Combat difficulty |
| `anomaly_hunt_speed` | 3.8 m/s | Chase lethality |
| `trait_roll_chance_leg_hit` | 0.35 | Consequence frequency |
