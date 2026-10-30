# Station Siege — P4-09

Horde-survival mode from GAMEPLAY_MECHANICS §11 ("Station Under Siege"): the cult cuts power and phones and
storms Station 4 in waves while the team holds the operations room.

| Piece | Path |
| --- | --- |
| Director (host logic, blackout, HUD) | `scenes/dispatch/siege/station_siege.gd` |
| Scene, instanced in `operations_room.tscn` | `scenes/dispatch/siege/station_siege.tscn` |
| Wave data | `data/siege/station_siege_plan.tres` (`SiegePlan`, `SiegeWave`) |
| Outcome rules | `data/consequences/rules/siege/` (from `tools/consequences/build_slice_rules.gd`) |

## Starting a siege

It starts once per campaign, 6 seconds after all of these hold on the host:
- the phase is dispatch, MissionDirector is idle and the phone line is free;
- cult awareness reached 90 (`MissionDirector.is_station_siege_triggered()`) **or** the flag
  `station_siege_pending` is true;
- the flag `station_siege_outcome` is not set.

The ending resolver (P4-08) only needs `FlagSystem.set_flag(&"station_siege_pending", true)`. Set pieces can
call `StationSiege.find(get_tree()).start(reason)` directly.

## Flow

1. **Breach:** the shift clock pauses and calls stop, every station door is kicked open, and the station lights
   go out (red emergency lights blink on every peer). The navmesh is baked now, not on load, from `Geometry`,
   `PerimeterFence` and `StationInterior`. Doors are left out of the bake.
2. **Countdown:** the first one is 45 s, which is the team's time to reach the armory, because officers are
   unarmed in the station.
3. **Waves:** hostiles spawn from the four entry markers in turn (parking lot, north yard, east lot, south road;
   29–58 m of path from the operations room), capped by each wave's `max_alive`. Every 2.5 s, any hostile that
   cannot see an officer is told where the nearest standing one is. Ambush Leader reinforcements count toward the
   wave.
4. **End:** after the last wave the station holds. If every officer stays down for 8 s it falls. Either way the
   remaining hostiles are removed, officers are restored, power returns and the shift clock resumes.

## Waves

| Wave | Hostiles | Max alive | Difficulty |
| ---: | --- | ---: | ---: |
| 1 | 4 thugs | 4 | 1.0 |
| 2 | 4 thugs, 2 gunmen | 6 | 1.0 |
| 3 | 4 gunmen, 2 zealots | 7 | 1.1 |
| 4 | 4 gunmen, 3 zealots, 1 thug | 8 | 1.15 |
| 5 | Ambush Leader, 4 gunmen, 3 zealots | 8 | 1.25 |

Difficulty is multiplied by `1 + 0.1 × (shift − 1)`.

## Flags and events

| Event | Payload |
| --- | --- |
| `station_siege_started` | `reason`, `shift` |
| `siege_wave_cleared` | `wave`, `waves` |
| `station_siege_survived`, `station_siege_fallen` | `wave`, `waves`, `neutralized` |

Flags: `station_siege_pending`, `station_siege_active`, `station_siege_outcome` (`survived` / `fallen`).

| Rule | Effect |
| --- | --- |
| `station_siege_held` | `station_defended`, trust +10, cult awareness −20 |
| `station_siege_overrun` | `station_overrun`, trust −15, guilt +15, `ptsd` on a random officer |
| `siege_wave_repelled` | counter `siege_waves_repelled` |

XP: +400 held, −150 fallen, +15 per hostile to the officer who neutralized it (`SiegePlan`).

## Tests

- `tests/test_station_siege.gd`: wave data, station wiring, every entry reaches the operations room on the real
  navmesh, full flow, `max_alive`, team wipe, blackout, trigger conditions.
- `tests/test_station_siege_network.gd`: host and client over ENet (state, blackout, HUD, clients cannot start).

Not covered: spawned hostiles replicating to a client, and a playthrough with real players in the station.
