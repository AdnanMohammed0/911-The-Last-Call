# 911: The Last Call

> Co-op (2–4 players) **dispatch simulation + tactical CQB / psychological horror**, built with **Godot 4 (GDScript)**.

🌐 **Website (story, game info, ideas, live team progress):** https://adnanmohammed0.github.io/911-The-Last-Call/

It's midnight at **Station 4, Blackvale County**. Three patrols vanished and the shift supervisor is dead. Your team runs the 00:00–06:00 night shift. You answer 911 calls, work out which callers are pranking you, which ones are genuine, and which calls are **ambushes by the Sons of the Dusk** or something using the **Dead Frequency**. Then you go out and handle them. Every choice carries over between shifts.

## Team

| Member | GitHub | Focus | Tasks |
| :--- | :--- | :--- | :---: |
| Adnan | [@AdnanMohammed0](https://github.com/AdnanMohammed0) | AI, networking & voice, core gameplay (player, combat, call director, flags) | 37 |
| Ali Imad | [@Ali-Imad-Dev](https://github.com/Ali-Imad-Dev) | 3D, world, art & all UI/UX | 24 |
| Mohamed | [@MohamedFSD](https://github.com/MohamedFSD) | Light programming: data resources, tooling/CI, content, traits/meters/save, audio mix, QA & release | 23 |

## Folder layout

```text
/                        ← Godot project goes here (project.godot, autoload/, scenes/, ...)
├── docs/                ← ALL project management files (Godot ignores it via .gdignore)
│   ├── README.md               this file
│   ├── AGENTS.md               rules for AI agents
│   ├── index.html, assets/     website (GitHub Pages serves this folder)
│   ├── data/                   team.json, tasks.json, progress/<id>.json, ideas.json
│   ├── design/                 GDD (md + pdf), ARCHITECTURE, GAMEPLAY_MECHANICS, PROJECT_ROADMAP
│   ├── prompts/                per-member AI prompts
│   ├── scripts/                whoami, validate_progress, build_tasks, auto_progress, hooks
│   └── PROGRESS.md             sprint notes, bug backlog, KPIs
├── .claude/             Claude Code: CLAUDE.md pointer + Stop hook (must be at root)
├── .cursor/rules/       Cursor pointer to docs/AGENTS.md (must be at root)
├── .github/             GitHub Actions + Copilot pointer (must be at root)
└── .gitignore
```

## How progress tracking works (automatic)

1. Each member opens the repo with their AI tool and pastes the start prompt from [`docs/prompts/<id>.md`](prompts/).
2. The AI reads [`docs/AGENTS.md`](AGENTS.md), identifies the member (`docs/scripts/whoami.py` → `git config` / `gh`), and works on their tasks.
3. **When work is done, the AI updates `docs/data/progress/<id>.json`, then commits and pushes by itself.** Nobody edits the website by hand.
4. Safety nets:
   - **Claude Code Stop hook** (`.claude/settings.json`) stops the AI from ending a session while work is uncommitted or unpushed.
   - **GitHub Action** (`.github/workflows/auto-progress.yml`) logs any push that didn't update a progress file under the author's name. Write `done P1-04` in the commit message to mark a task complete.
5. The GitHub Pages site (`docs/`) reads `docs/data/*.json` and shows each member's progress, current tasks, and activity log.

Ideas are posted from the website as GitHub Issues titled `[فكرة] …` (label `idea`) and show up on the site for everyone.

To change task owners, edit the `@owner` tags in `docs/design/PROJECT_ROADMAP.md`, then run `python docs/scripts/build_tasks.py`.

## Run the site locally

```bash
python -m http.server 8000 --directory docs
```

Then open http://localhost:8000.
