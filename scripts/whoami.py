"""Identify which team member is working in this clone.

Matches `git config user.email` / `user.name` (and the gh CLI login, if available)
against data/team.json. Prints the member id, or exits 1 if nobody matches.
Run: python scripts/whoami.py
"""
import json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _run(*cmd: str) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT, timeout=10).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def load_members() -> list[dict]:
    return json.loads((ROOT / "data/team.json").read_text(encoding="utf-8"))["members"]


def match_member(members: list[dict], email: str = "", name: str = "", login: str = "") -> str | None:
    email, name, login = email.lower(), name.lower(), login.lower()
    for m in members:
        emails = [e.lower() for e in m.get("git_emails", [])]
        names = [n.lower() for n in m.get("git_names", [])]
        gh = m.get("github", "").lower()
        if (email and email in emails) or (login and login == gh) or (name and name in names) \
                or (email and gh and email.endswith(f"+{gh}@users.noreply.github.com")):
            return m["id"]
    return None


def identify() -> str | None:
    members = load_members()
    return match_member(members, _run("git", "config", "user.email"), _run("git", "config", "user.name")) \
        or match_member(members, login=_run("gh", "api", "user", "--jq", ".login"))


if __name__ == "__main__":
    member = identify()
    if member:
        print(member)
        sys.exit(0)
    print(f"unknown (git email={_run('git', 'config', 'user.email') or '-'})", file=sys.stderr)
    sys.exit(1)
