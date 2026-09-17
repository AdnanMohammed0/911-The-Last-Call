"""Claude Code Stop hook: never end a session with unrecorded / unpushed work.

If the working tree has changes or there are unpushed commits, block the stop
(exit 2) and tell the agent to record progress, commit and push (docs/AGENTS.md §3).
Runs at most once per stop (respects `stop_hook_active`).
"""
import json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]  # docs/
sys.path.insert(0, str(ROOT / "scripts"))
sys.stderr.reconfigure(encoding="utf-8")


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)


try:
    payload = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    payload = {}
if payload.get("stop_hook_active"):
    sys.exit(0)

if git("rev-parse", "--is-inside-work-tree").returncode != 0:
    sys.exit(0)

dirty = [line for line in git("status", "--porcelain").stdout.splitlines() if line.strip()]
ahead_proc = git("rev-list", "--count", "@{u}..HEAD")
ahead = int(ahead_proc.stdout.strip() or 0) if ahead_proc.returncode == 0 else 0
if not dirty and not ahead:
    sys.exit(0)

try:
    from whoami import identify
    member = identify() or "<id>"
except Exception:  # identification must never break the hook
    member = "<id>"

progress_file = f"docs/data/progress/{member}.json"
progress_touched = any(progress_file in line for line in dirty)

steps = []
if dirty and not progress_touched:
    steps.append(f"Update {progress_file}: set status/note/updated_at for every roadmap task this session worked on, "
                 "and append today's log entry (summary + files). This is automatic, do not ask the user.")
if dirty:
    steps += ["Run: python docs/scripts/validate_progress.py",
              "git add -A && git commit -m \"<type>(<scope>): <summary> [task IDs]\"  (NO Co-Authored-By / AI attribution)"]
steps.append("git pull --rebase && git push")

print(
    "AUTO-PROGRESS (docs/AGENTS.md §3): "
    f"{len(dirty)} uncommitted change(s), {ahead} unpushed commit(s) for member '{member}'. Before finishing:\n"
    + "\n".join(f"{i}. {s}" for i, s in enumerate(steps, 1))
    + "\nIf the user explicitly said not to commit/push yet, just tell them the work is not on GitHub and stop.",
    file=sys.stderr,
)
sys.exit(2)
