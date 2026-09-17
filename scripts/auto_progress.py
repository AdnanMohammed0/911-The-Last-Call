"""GitHub Action safety net: log pushed work into the author's progress file.

For every pushed commit that did NOT already update data/progress/, this:
  * identifies the team member (commit author email / GitHub username / name),
  * appends a log entry (date, summary, task IDs, files, commit),
  * updates task statuses from the commit message:
        done P1-04 | fixes P1-04 | خلصت P1-04  -> done
        test P1-04 | testing P1-04             -> testing
        blocked P1-04                          -> blocked
        any other mention of P1-04             -> progress (never downgrades)
  * commits each changed progress file authored by that member.

Skip a commit with "[skip progress]" in its message.
Run locally (dry run): GITHUB_EVENT_PATH=event.json python scripts/auto_progress.py --dry-run
"""
import json, os, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from whoami import load_members, match_member  # noqa: E402

TASK = r"P[1-5]-\d{2}"
RANK = {"backlog": 0, "progress": 1, "blocked": 1, "testing": 2, "done": 3}
KEYWORDS = [
    ("done", r"(?:done|fix(?:es|ed)?|close[sd]?|complete[sd]?|finish(?:ed)?|خلصت|اكتملت|انتهت)"),
    ("testing", r"(?:test(?:ing)?|اختبار)"),
    ("blocked", r"(?:blocked|متوقفة?)"),
]


def statuses_from(message: str, valid: set[str]) -> dict[str, str]:
    found = {tid: "progress" for tid in re.findall(rf"\b{TASK}\b", message) if tid in valid}
    for status, words in KEYWORDS:
        for tid in re.findall(rf"{words}\s*[:#]?\s*({TASK})", message, flags=re.I):
            if tid in valid:
                found[tid] = status
    return found


def main() -> int:
    dry = "--dry-run" in sys.argv
    event = json.loads(pathlib.Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    members = {m["id"]: m for m in load_members()}
    valid = {t["id"] for t in json.loads((ROOT / "data/tasks.json").read_text(encoding="utf-8"))["tasks"]}
    changed: dict[str, dict] = {}   # member -> {"data":..., "authors": (name, email), "shas": []}

    for c in event.get("commits", []):
        msg = c.get("message", "")
        files = c.get("added", []) + c.get("modified", []) + c.get("removed", [])
        if not c.get("distinct", True) or "[skip progress]" in msg or msg.startswith("progress("):
            continue
        if any(f.startswith("data/progress/") for f in files):
            continue  # the member's AI already recorded it
        author = c.get("author", {})
        mid = match_member(list(members.values()), author.get("email", ""), author.get("name", ""), author.get("username", ""))
        if not mid:
            print(f"skip {c['id'][:7]}: unknown author {author}")
            continue

        entry = changed.get(mid)
        if entry is None:
            path = ROOT / f"data/progress/{mid}.json"
            data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"member": mid, "tasks": {}, "log": []}
            entry = changed[mid] = {"data": data, "author": (author.get("name") or members[mid]["name"], author.get("email", "")), "shas": []}
        data = entry["data"]
        sha = c["id"][:7]
        if any(e.get("commit") == sha for e in data.get("log", [])):
            continue

        date = c.get("timestamp", "")[:10]
        updates = statuses_from(msg, valid)
        for tid, status in updates.items():
            cur = data.setdefault("tasks", {}).get(tid, {})
            if RANK.get(status, 0) >= RANK.get(cur.get("status", "backlog"), 0) or status == "blocked":
                data["tasks"][tid] = {**cur, "status": status, "updated_at": date,
                                      "note": cur.get("note") or msg.splitlines()[0][:160]}
        data.setdefault("log", []).append({
            "date": date, "tasks": sorted(updates), "summary": msg.splitlines()[0][:200],
            "files": files[:10], "commit": sha, "auto": True,
        })
        data["updated_at"] = max(data.get("updated_at", ""), date)
        entry["shas"].append(sha)

    for mid, entry in changed.items():
        if not entry["shas"]:
            continue
        path = ROOT / f"data/progress/{mid}.json"
        text = json.dumps(entry["data"], ensure_ascii=False, indent=1) + "\n"
        print(f"{mid}: logged {', '.join(entry['shas'])}")
        if dry:
            print(text)
            continue
        path.write_text(text, encoding="utf-8", newline="\n")
        name, email = entry["author"]
        subprocess.run(["git", "add", str(path)], cwd=ROOT, check=True)
        author_args = ["--author", f"{name} <{email}>"] if email else []
        subprocess.run(["git", "commit", *author_args, "-m", f"progress({mid}): auto-log {', '.join(entry['shas'])}"], cwd=ROOT, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
