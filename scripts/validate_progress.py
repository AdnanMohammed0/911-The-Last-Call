"""Validate data/progress/*.json against data/tasks.json and data/team.json.

Run: python scripts/validate_progress.py   (exit code 1 on errors)
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATUSES = {"backlog", "progress", "testing", "done", "blocked"}
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

tasks = {t["id"]: t for t in json.loads((ROOT / "data/tasks.json").read_text(encoding="utf-8"))["tasks"]}
members = {m["id"] for m in json.loads((ROOT / "data/team.json").read_text(encoding="utf-8"))["members"]}
errors, warnings = [], []

for path in sorted((ROOT / "data/progress").glob("*.json")):
    rel = path.relative_to(ROOT).as_posix()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"{rel}: invalid JSON ({e})")
        continue
    member = data.get("member")
    if member != path.stem or member not in members:
        errors.append(f"{rel}: 'member' must be '{path.stem}' and exist in team.json")
    if not DATE.match(str(data.get("updated_at", ""))):
        errors.append(f"{rel}: 'updated_at' must be YYYY-MM-DD")
    for tid, entry in data.get("tasks", {}).items():
        if tid not in tasks:
            errors.append(f"{rel}: unknown task {tid}")
            continue
        if entry.get("status") not in STATUSES:
            errors.append(f"{rel}: {tid} status must be one of {sorted(STATUSES)}")
        if "updated_at" in entry and not DATE.match(entry["updated_at"]):
            errors.append(f"{rel}: {tid} updated_at must be YYYY-MM-DD")
        if tasks[tid]["owner"] != member:
            warnings.append(f"{rel}: {tid} is owned by '{tasks[tid]['owner']}' (helping is fine, but coordinate)")
    for i, entry in enumerate(data.get("log", [])):
        if not DATE.match(str(entry.get("date", ""))) or not entry.get("summary"):
            errors.append(f"{rel}: log[{i}] needs 'date' (YYYY-MM-DD) and 'summary'")
        for tid in entry.get("tasks", []):
            if tid not in tasks:
                errors.append(f"{rel}: log[{i}] references unknown task {tid}")

for w in warnings:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
print("OK" if not errors else f"{len(errors)} error(s)")
sys.exit(1 if errors else 0)
