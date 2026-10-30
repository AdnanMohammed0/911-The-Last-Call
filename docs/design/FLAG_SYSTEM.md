# FlagSystem — P4-01 / P4-02

Runtime for ARCHITECTURE §7 (butterfly effect): `autoload/flag_system.gd`, registered as the `FlagSystem`
autoload. The host owns all mutation and rule evaluation. Flags and events replicate to every peer, and
late joiners receive a full snapshot.

## API

| Call | Where | Purpose |
| --- | --- | --- |
| `record_event(id, payload)` | host | The single entry point for narrative actions; triggers rules |
| `set_flag(key, value)` / `clear_flag(key)` | host | Story facts; emits `EventBus.flag_changed` on every peer |
| `add_meter(key, delta)` | host | `public_trust` → MissionDirector, `station_budget` / `cult_awareness` → GameState; any other key is a numeric flag |
| `get_flag`, `has_flag`, `has_event`, `count_events`, `events_of` | any peer | Queries |
| `flags_match(dict)`, `conditions_pass(conditions)` | any peer | Used by `CallData.requires_flags` and `DialogueChoice.conditions` |
| `tick(shift, minute)` | host | Runs due pending rules; already driven by `EventBus.shift_clock_updated` |
| `snapshot()` / `restore(data)` | host | JSON-safe campaign state for the save system (P4-05) |
| `event_recorded(event)` signal | any peer | For UI, telemetry or reports |

`has_event(id, match)`: `match` can be `null` (any), a Dictionary (every key must match), or a value
compared with the payload's `call` (or `value`).

## Events recorded automatically

| Event | Source | Payload |
| --- | --- | --- |
| any dialogue `on_enter_events` id (e.g. `dispatch_units`, `cult_activity_detected`) | `EventBus.call_event` | `call` |
| `call_classified` | `EventBus.call_classified` | `call`, `verdict`, `truth` |
| `call_ignored` | `EventBus.call_missed` | `call`, `truth` |
| `suspect_arrested`, `hostile_killed` | EventBus | `peer_id`, `mission`, `archetype` |
| `civilian_killed` | `EventBus.hostage_executed` | `mission`, `archetype` |
| `officer_downed` | `EventBus.player_downed` | `peer_id`, `mission` |
| `mission_success` | `MissionDirector.extract` | `call`, `kind`, `kills`, `arrests`, `unlawful`, `downed` |
| `mission_failed` | `MissionDirector.fail` | `call`, `kind`, `reason` |
| `shift_completed` | `MissionDirector.complete_shift` | `shift`, `trust` |
| `decoy_cruiser_destroyed` / `decoy_cruiser_saved` | highway RPG set piece | `call` |
| `remains_buried` (call event) | `RemainsInteraction` (also sets its flag through FlagSystem) | `call` |

`truth` is the call's hidden `CallData.Truth` in lower case (`genuine`, `prank`, `ambush`…), so rules can
react to any ignored genuine call. `archetype` is the hostile's `ArchetypeData.id` (e.g. `ambush_leader`).

Each event is stored as `{id, t (shift-clock minute), shift, payload}`.

## Rules

Put `ConsequenceRule` resources (`.tres`) under `data/consequences/rules/`; subfolders are fine. They load
at start. A rule fires when its `trigger_event` is recorded, the event's payload contains every pair of its
`trigger_payload` (e.g. `{"call": &"call_closet_monster", "verdict": &"ignore"}`; empty = any), and all of its
`FlagCondition`s pass.

| Timing | Behaviour |
| --- | --- |
| IMMEDIATE | Effects run at once |
| DELAYED_MINUTES | Run when the shift clock reaches now + `delay` |
| NEXT_SHIFT | Run at minute 0 of the shift `delay` (≥ 1) shifts later |
| ENDING | Rule id added to `ending_candidates` for the ending resolver |

`once` rules fire a single time per campaign, and are never queued twice while pending. Effects:
- SET_FLAG
- ADD_METER
- APPLY_TRAIT (targets `caller_peer`, `all_officers` or `random_officer`)
- QUEUE_CALL (the call must be registered)
- UNLOCK_MISSION (sets `mission_unlocked_<key>`)
- SPAWN_EVENT (chains other rules; capped at 8 levels)

Comparisons never raise on mismatched types (`FlagCondition.values_equal`): numbers compare with numbers,
String with StringName.

## Integrations

- `DialogueChoice.conditions`: a failing choice shows as locked ("Not available") and the host rejects
  it.
- `CallData.requires_flags`: the call stays queued until its flags hold, and the shift can still end
  while it waits.
- The shift report keeps turning true `*unlocked*` / `*intel*` flags into leads.

## Authored rules (P4-02)

`tools/consequences/build_slice_rules.gd` generates the rules from compact tables, validates each one and
saves it under `data/consequences/rules/<group>/`. Edit the tables and rerun instead of editing the `.tres`
files by hand:

```
godot --headless --path . -s res://tools/consequences/build_slice_rules.gd
```

| Group | Rules | Examples |
| --- | --- | --- |
| `slice/` | 19 | closet monster missed or dismissed → teen dead 45 min later (trust −15, guilt +20); rescue → `station_ambush_intel`; cut line dismissed → district blackout after 30 min; Ambush Leader arrested → `ambush_leader_arrested` next shift; decoy cruiser lost or saved; meat truck lead missed |
| `followup/` | 7 | interrogation deal → `cult_hideout_location_known` now and `mission_unlocked_cult_hideout` next shift; refusal → `cult_aware_station`; hideout raided → `cult_network_dismantled` |
| `matrix/` | 11 (repeatable) | genuine call ignored, dismissed or laughed off; prank met with force; civilian casualty; trap call counters; guilt ≥ 50 → `phantom_ringing` on every officer; 3 ambushes survived → `hardened` |
| `siege/` | 3 | Station Siege outcomes (P4-09), see [STATION_SIEGE.md](STATION_SIEGE.md) |

Meter deltas stack on top of MissionDirector's own (missed call −5 trust, wrong verdict −3, correct +2).
Guilt (GDD §3.3) is the hidden team-wide numeric flag `guilt`; every rule that raises it spawns
`guilt_raised`, so threshold rules only need that one trigger.

`ConsequenceValidator` (`data/consequences/consequence_validator.gd`) checks:
- missing id or trigger, no effects;
- calls, traits and targets that do not exist;
- numeric ADD_METER deltas;
- odd delays and self-looping repeatable rules;
- duplicate ids;
- triggers that nothing records (warning).

Tests:
- `tests/test_flag_system.gd` (17)
- `tests/test_flag_system_network.gd` (host and client over ENet, including the late-join snapshot)
- `tests/test_consequence_rules.gd` (every authored rule validates; trigger_payload filtering; the closet
  monster, Ambush Leader → interrogation → hideout, guilt → phantom ringing, and cut line chains end to end)
