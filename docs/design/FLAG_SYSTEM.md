# FlagSystem — P4-01

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
| `call_classified` | `EventBus.call_classified` | `call`, `verdict` |
| `call_ignored` | `EventBus.call_missed` | `call` |
| `suspect_arrested`, `hostile_killed` | EventBus | `peer_id`, `mission` |
| `officer_downed` | `EventBus.player_downed` | `peer_id`, `mission` |
| `mission_success` | `MissionDirector.extract` | `call`, `kind`, `kills`, `arrests`, `unlawful`, `downed` |
| `mission_failed` | `MissionDirector.fail` | `call`, `kind`, `reason` |
| `shift_completed` | `MissionDirector.complete_shift` | `shift`, `trust` |

Each event is stored as `{id, t (shift-clock minute), shift, payload}`.

## Rules

Put `ConsequenceRule` resources (`.tres`) under `data/consequences/rules/`; subfolders are fine. They load
at start. A rule fires when its `trigger_event` is recorded and all of its `FlagCondition`s pass.

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

Authoring the slice rules (e.g. §7.5 `closet_monster_ignored`) is P4-02.

Tests:
- `tests/test_flag_system.gd` (16)
- `tests/test_flag_system_network.gd` (host and client over ENet, including the late-join snapshot)
