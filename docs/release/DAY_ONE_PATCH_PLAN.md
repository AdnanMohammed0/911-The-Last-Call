# Day-One Patch Plan — 911: The Last Call (P5-10)

Task: `P5-10` · Owner: `@mohamed` · Authority: LOCAL
Companion: [`P5-10_RELEASE_CANDIDATE.md`](P5-10_RELEASE_CANDIDATE.md) · [`../community/DISCORD_AND_BUG_REPORTS.md`](../community/DISCORD_AND_BUG_REPORTS.md)

The launch build is frozen. Anything found after the RC ships is either a **day-one patch** or a
**known issue** — never a silent change to the release branch.

---

## 1. Freeze window

| Window | Rule |
|:---|:---|
| T-7 days | RC cut. Only S0/S1 fixes, localization text, and store metadata may land. |
| T-3 days | Content lock. Only S0 fixes and crash regressions. |
| Launch day | No code changes to `main` except the hotfix branch. |
| T+24h | War room active. Patch only after the fix is reproduced and tested. |
| T+72h | First retrospective; decide whether the next patch is weekly or as-needed. |

Every exception needs a named approver (release manager) and a ticket. "It's a one-line fix" is not an
exception policy.

## 2. Severity and response

| Severity | Definition | Examples | First response | Fix target |
|:---|:---|:---|:---|:---|
| **S0** | Cannot launch / data loss / security / all players blocked | crash on boot, save corruption, remote code execution, server takeover | 30 min | same day, hotfix |
| **S1** | Core loop broken for many players | cannot host or join, shift cannot complete, ending never resolves | 2 h | ≤ 24 h |
| **S2** | Feature broken but a workaround exists | one call stuck, trace tool unusable, subtitles wrong | 1 business day | next patch |
| **S3** | Cosmetic / low impact | typo, minor animation, rare audio pop | 3 business days | backlog |

The on-call triager sets severity, not the reporter. When unsure, start one level higher.

## 3. Hotfix workflow

```
issue (GitHub / Discord / crash dump)
  → reproduced on the release tag
  → severity + owner assigned
  → branch hotfix/<version> from the release tag
  → minimal fix + regression test
  → bump PATCH version in project.godot
  → CI green (GUT, locales, calls, export)
  → tag v<version> → release.yml builds the artifact + manifest
  → upload to Steam branch "beta"
  → 2-hour smoke on beta (see RC §5)
  → promote the same build to "default"
  → announce + close the issue with the build ID
```

Branch rules:

- Branch from the **release tag**, never from `main`; `main` may already contain unreleased content.
- Cherry-pick the fix back to `main` after the patch ships.
- One fix theme per patch. Do not bundle unrelated gameplay changes.
- Every fix needs a test or a written manual reproduction step. No test, no patch.

Version rules:

- Patch release: `1.0.0` → `1.0.1`; RC suffix is dropped for the public build.
- If launch is still on an RC, the first public patch is the next PATCH after the promoted version, not
  another `rc`.
- `rc_manifest.py --check-version` must pass for the tag used to build.

## 4. SteamPipe upload (manual, release manager)

The repository never stores depot IDs or Steam credentials. Use the RC artifact from the GitHub release:

```
steamcmd +login <build-account> +run_app_build ../scripts/app_build_<version>.vdf +quit
```

`app_build_<version>.vdf` (kept outside the repo, one per patch):

```
"appbuild"
{
  "appid" "APPID"
  "desc" "911: The Last Call 1.0.1"
  "buildoutput" "../output/"
  "contentroot" "../content/"
  "setlive" "beta"
  "preview" "0"
  "depots"
  {
    "DEPOT_WINDOWS" { "File" "depot_windows.vdf" }
    "DEPOT_LINUX"   { "File" "depot_linux.vdf" }
  }
}
```

Promotion order: `beta` → smoke → `default`. Keep `previous` pointing at the last known-good build until
T+72h.

## 5. Rollback

1. Set the `default` branch back to the previous build in Steamworks.
2. Keep the bad build on `beta` for diagnosis.
3. Revert the offending commit on the hotfix branch; do not rewrite the tag.
4. Publish a new patch version with the revert and a note in the patch notes.
5. If saves are involved, ship a migration or a restore path before anything else.

Never ask players to delete their save as the primary fix. Provide an export/restore path or a migration.

## 6. What to watch (first 72 hours)

| Signal | Source | Action |
|:---|:---|:---|
| Crash-free sessions | `TelemetryService` + Steam crash reports | S0/S1 triage |
| Crash dumps | `user://crash_dumps/` (attached to reports) | reproduce, link issue |
| Host/join failures | Discord `#tech-support`, GitHub `bug` | check build, network matrix row |
| Shift completion | telemetry KPIs | find blocked calls/missions |
| Save/load failures | reports + telemetry | treat as S0 if data is lost |
| Refund/negative review themes | Steam | convert repeated themes into S2 tickets |

Privacy: telemetry is opt-in and anonymous. Never ask a player to post an IP, full log with personal
paths, or voice audio. Ask for the in-game copied report and the build line.

## 7. Communication

### Steam news / patch notes template

```
Patch 1.0.1 — <date>

Fixed
- <player-facing description> (reported by <name/handle>, thanks)
- ...

Known issues
- <issue> — workaround: <...>

Thanks for playing. Report bugs in-game (pause menu → Report a bug) or on Discord.
```

### Discord announcement template

```
@Player Patch 1.0.1 is live on the default branch.
Fixed: <one line>.
Build: v1.0.1 · <commit short sha>
If you still see it, post in #bug-reports with the in-game copied report.
```

### Known-issue pin

```
KNOWN ISSUE — <title>
Affected builds: <version(s)>
Symptom: <one sentence>
Workaround: <one sentence>
Tracking: <GitHub issue link>
```

## 8. War-room roles

| Role | Person | Responsibility |
|:---|:---|:---|
| Release manager | Mohamed | severity, freeze exceptions, Steam upload, comms sign-off |
| Networking on-call | Adnan | host/join, desync, Steam transport |
| UI/art on-call | Ali | Steam Deck, UI blockers, store assets |
| Community/mod | Mohamed + moderator | Discord triage, dedupe, known-issue pins |
| QA | rotating | reproduce, verify fix, sign beta |

## 9. Day-one checklist

- [ ] RC artifact and manifest archived; `previous` branch points at it.
- [ ] `#announcements` and Steam news drafted, not posted.
- [ ] `#bug-reports` template pinned; GitHub issue form live.
- [ ] `BuildInfo.DISCORD_INVITE_URL` set; Discord button visible in the reporter.
- [ ] Crash/telemetry dashboards open; on-call names in the channel topic.
- [ ] Hotfix branch name reserved; patch version decided.
- [ ] Rollback rehearsed on `beta`.
- [ ] Known-issue pin drafted for host migration (not implemented — see P5-07 notes).
