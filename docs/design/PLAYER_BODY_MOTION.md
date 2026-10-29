# Player body motion ("cartoon body")

Players move with the unchanged first-person controller (`Player._update_movement` and
`Player.steer_horizontal`): acceleration, braking, turning and collisions are exactly as responsive as
before. All personality is visual and lives on top of it:

| Layer | File | Who sees it |
| --- | --- | --- |
| Walk cycle, IK, poses | `scenes/shared/characters/humanoid_rig.gd` | Everyone (hostiles too) |
| Cartoon body springs | `scenes/shared/characters/body_dynamics.gd` | Player bodies only (other players, own shadow) |
| First-person hands | `scenes/shared/player/player_motion_view.gd` | The owner, when unarmed |

The camera, aim ray and collision capsule are never moved by any of these layers.

## What BodyDynamics adds

- **Inertia:** hips trail acceleration and overshoot when it stops; the legs bend through IK, so the
  feet stay planted.
- **Spring lean:** forward when speeding up, back when braking (a short skid), into turns. Each lean
  overshoots before settling.
- **Turn lag:** the whole body keeps part of a sudden turn behind it, then swings round past the facing.
- **Steps:** a waddle over the stance foot, a springy dip and squash on each footfall, each step
  slightly different.
- **Reactions:**
  - Setting off: a small dip and wind-up.
  - Sudden stop: a randomised settle wobble with the arms flung forward.
  - Left/right flip: a sideways jolt.
  - Forward/back reversal: a pitch jolt.
- **Spinning:** fast spins build up dizziness, so the head circles and the body sways for a few seconds.
- **Air:** stretch while rising. Arms flail after about 0.3 s of falling. Landing compresses and
  rebounds, detected from motion so remote players see it too.
- **Idle:** breathing, slow weight shifts and a fidget every 5–11 s (glance, shrug, stretch, shift).
- **Bobble head and floppy hands:** both trail everything above.

Aiming (0.35×), crouching (0.6×), reloading (0.8×) and scripted poses (surrender, arrested, dead) tone
the layer down. All springs are substepped at 120 Hz, so the result matches at 30 or 144 fps. The
randomness only varies cosmetic reactions and is never replicated.

## Tuning

`PlayerBody` (inspector group **Cartoon Body**):

| Export | Default | Effect |
| --- | --- | --- |
| `cartoon_amount` | 1.0 | Master strength; 0 restores the previous grounded motion |
| `hip_lag` | 0.011 | Metres of hip trail per m/s² |
| `lean_gain` | 0.011 | Radians of lean per m/s² |
| `head_wobble` | 0.85 | Bobble-head strength |
| `arm_flop` | 1.0 | Hand trail and flail |
| `turn_lag` | 0.55 | Share of a sudden turn the body lags behind |
| `dizziness` | 1.0 | Post-spin wobble |
| `idle_fidgets` | 1.0 | Idle weight shifts and fidgets |
| `step_springiness` | 1.0 | Footfall dip and squash |

`PlayerMotionView` adds `turn_drag` and `accel_drag` for the first-person hands.

Tests: `tests/test_expressive_movement.gd` covers the stop, overshoot and settle, frame-rate
independence, stability under 20 s of chaotic input, turn lag, players-only, and capsule/camera safety.
