# 911: The Last Call

> Co-op (2–4 players) **dispatch simulation + tactical CQB / psychological horror**, built with **Godot 4 (GDScript)**.

🌐 **Website (story, game info, ideas, live team progress):** https://adnanmohammed0.github.io/911-The-Last-Call/

It's midnight at **Station 4, Blackvale County**. Three patrols vanished and the shift supervisor is dead. Your team runs the 00:00–06:00 night shift. You answer 911 calls, work out which callers are pranking you, which ones are genuine, and which calls are **ambushes by the Sons of the Dusk** or something using the **Dead Frequency**. Then you go out and handle them. Every choice carries over between shifts.

## Team

| Member | GitHub | Focus | Tasks |
| :--- | :--- | :--- | :---: |
| Adnan | [@AdnanMohammed0](https://github.com/AdnanMohammed0) | Lead: networking, voice pipeline, data layer, save/flags, release | 27 |
| Ali Imad | [@Ali-Imad-Dev](https://github.com/Ali-Imad-Dev) | Gameplay & AI: player, call director, combat, hostiles, anomalies, endings | 29 |
| Mohamed | [@MohamedFSD](https://github.com/MohamedFSD) | UI/UX, audio & art: dispatch tools, maps, characters, VHS look, store | 28 |

## How progress tracking works (automatic)

1. Each member opens the repo with their AI tool and pastes the start prompt from [`prompts/<id>.md`](prompts/).
2. The AI reads [`AGENTS.md`](AGENTS.md), identifies the member (`scripts/whoami.py` → `git config` / `gh`), and works on their tasks.
3. **When work is done, the AI updates `data/progress/<id>.json`, then commits and pushes by itself.** Nobody edits the website by hand.
4. Safety nets:
   - **Claude Code Stop hook** (`.claude/settings.json`) stops the AI from ending a session while work is uncommitted or unpushed.
   - **GitHub Action** (`.github/workflows/auto-progress.yml`) logs any push that didn't update a progress file under the author's name. Write `done P1-04` in the commit message to mark a task complete.
5. The GitHub Pages site reads `data/*.json` and shows each member's progress, current tasks, and activity log.

Ideas are posted from the website as GitHub Issues titled `[فكرة] …` (label `idea`) and show up on the site for everyone.

## Repository map

| Path | Contents |
| :--- | :--- |
| `index.html`, `assets/` | Static website (GitHub Pages, no build step) |
| `data/team.json` | Members, roles, git identities |
| `data/tasks.json` | 84 roadmap tasks with owners (generated: `python scripts/build_tasks.py`) |
| `data/progress/<id>.json` | Per-member status, notes, activity log |
| `data/ideas.json` | Curated ideas (plus GitHub Issues) |
| `AGENTS.md`, `CLAUDE.md` | Rules for AI agents |
| `prompts/` | Per-member prompts |
| `scripts/` | `whoami.py`, `validate_progress.py`, `build_tasks.py`, `auto_progress.py`, hooks |
| `docs/ARCHITECTURE.md` | Multiplayer, voice, flag/consequence system, save schema |
| `docs/GAMEPLAY_MECHANICS.md` | Classes, traits, dispatch, AI behavior trees, anomalies |
| `docs/PROJECT_ROADMAP.md` | 5 phases, tasks with `@owner` tags, risks |
| `game_design_document_911_The_Last_call.md`, `docs/911_The_Last_Call_GDD.pdf` | Game design documents (Arabic) |
| `PROGRESS.md` | Sprint notes, bug backlog, KPIs |

## Run the site locally

```bash
python -m http.server 8000
```

Then open http://localhost:8000.
