"""Regenerate data/tasks.json from docs/PROJECT_ROADMAP.md.

Owners come from the `@owner` tag on each roadmap line, e.g.
- [ ] `P1-04` `NET` `@adnan` NetManager host/join ...
Run: python scripts/build_tasks.py
"""
import json, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LINE = re.compile(r"^- \[[ x]\] `(P(\d)-\d+)` `(\w+)` `@(\w+)` (.+)$")
GROUP = re.compile(r"^### (\d\.\d) (.+)$")
PHASE = re.compile(r"^## Phase \d — (.+?) \(")

tasks, group = [], ""
for line in (ROOT / "docs/PROJECT_ROADMAP.md").read_text(encoding="utf-8").splitlines():
    if m := PHASE.match(line):
        group = m.group(1)
    elif m := GROUP.match(line):
        group = m.group(2)
    elif m := LINE.match(line):
        tasks.append({"id": m.group(1), "phase": int(m.group(2)), "group": group,
                      "cat": m.group(3), "owner": m.group(4), "title": m.group(5).replace("`", "")})

out = ROOT / "data/tasks.json"
out.write_text(json.dumps({"tasks": tasks}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
print(f"{len(tasks)} tasks -> {out.relative_to(ROOT)}")
