# 911: The Last Call

> Co-op (2–4 players) **dispatch simulation + tactical CQB / psychological horror**, built with **Godot 4 (GDScript)**.

It's midnight at **Station 4, Blackvale County**. Three patrols vanished and the shift supervisor is dead. Your team runs the 00:00–06:00 night shift. You answer 911 calls, work out which callers are pranking you, which ones are genuine, and which calls are **ambushes by the Sons of the Dusk** or something using the **Dead Frequency**. Then you go out and handle them. Every choice carries over between shifts.

## Core Loop
1. **Dispatch:** take calls, analyze voice stress, trace the caller, check CCTV and records.
2. **Assess, Loadout & Vote:** classify the call, gear up within budget, and vote on how to approach.
3. **Field Response:** first-person breach, negotiate, arrest, fight, or survive anomalies.
4. **Aftermath:** a Detroit-style butterfly effect that carries forward injuries, trauma, public trust, budget, and story branches.

## Classes
| Class | Role |
| :--- | :--- |
| Tech Operator | CCTV, geo-tracking, terminal hacking, recon drone |
| Profiler / Negotiator | Voice stress analysis, lie detection, hostage negotiation |
| Breacher | Shields, heavy weapons, door kicking, damage resistance |
| Investigator / Medic | Sanity management, paranormal detection, revives |

## Documentation
| File | Contents |
| :--- | :--- |
| [`game_design_document_911_The_Last_call.md`](game_design_document_911_The_Last_call.md) | Original game design document (Arabic): story, endings, scenarios |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Multiplayer architecture, voice chat, flag/consequence system, save schema |
| [`docs/GAMEPLAY_MECHANICS.md`](docs/GAMEPLAY_MECHANICS.md) | Class balance, traits, dispatch mechanics, AI behavior trees and anomaly FSMs |
| [`docs/PROJECT_ROADMAP.md`](docs/PROJECT_ROADMAP.md) | 5 phases, 84 tagged tasks, milestones, risk register |
| [`PROGRESS.md`](PROGRESS.md) | Sprint tracker, daily log, bug backlog, KPIs |
| [`index.html`](index.html) | Interactive progress dashboard (open it in any browser, works offline) |

## Progress Dashboard
Open `index.html` directly, or enable GitHub Pages for this repo (Settings → Pages → `main` / root).
It includes a Kanban board (drag-and-drop), a milestone tracker, category filters, and JSON export/import. Progress is saved in your browser's `localStorage`, so each browser keeps its own copy. Use Export/Import to share it.

## Tech Stack
Godot 4.x · GDScript · SceneMultiplayer (ENet / Steam P2P via GodotSteam) · Opus voice · GUT tests
