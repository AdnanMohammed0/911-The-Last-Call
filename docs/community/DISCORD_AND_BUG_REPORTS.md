# Community Discord & Bug Report Flow — 911: The Last Call (P5-10)

Task: `P5-10` · Owner: `@mohamed` · Authority: LOCAL
Companion: [`../release/P5-10_RELEASE_CANDIDATE.md`](../release/P5-10_RELEASE_CANDIDATE.md) · [`../release/DAY_ONE_PATCH_PLAN.md`](../release/DAY_ONE_PATCH_PLAN.md)

The server is the community front door; GitHub is the bug ledger. The in-game reporter is the bridge:
it produces one anonymous, copyable bundle that works in both places.

```
in-game pause menu → Report a bug → Copy report
        │
        ├─ Discord #bug-reports  (fast conversation, screenshots)
        ├─ GitHub issue form     (reproducible ticket, fix trail)
        └─ Steam forums          (players who do not use Discord)
                    │
                    └─ triage → label + severity → fix → verify → close
```

---

## 1. Server structure

| Category | Channel | Purpose | Who can post |
|:---|:---|:---|:---|
| **START HERE** | `#welcome` | Rules, what the game is, download/build info | read-only |
| | `#announcements` | Patches, events, server maintenance | @Dev / @Mod |
| | `#roles` | Self-assign: `@Playtester`, `@LFG`, patch pings | @Player (reactions) |
| **COMMUNITY** | `#general` | Off-topic-lite, screenshots, clips | @Player |
| | `#looking-for-group` | Squad finding, time zones, voice | @Player |
| | `#clips-and-stories` | Bodycam moments, close calls | @Player |
| | `#suggestions` | Ideas; link a GitHub discussion if it grows | @Player |
| **SUPPORT** | `#bug-reports` | Reproducible bugs, copied diagnostic report | @Player |
| | `#crash-reports` | Crash dumps, launch failures (S0/S1) | @Player |
| | `#tech-support` | Setup, voice, host/join, compatibility | @Player |
| | `#known-issues` | Pinned list for the current build | read-only |
| **VOICE** | `Dispatch 1–4` | 4-player squads (game cap is 4 total) | @Player |
| | `War Room` | Dev + moderators during launch window | @Dev / @Mod |
| **STAFF** | `#mod-log`, `#triage`, `#release-war-room` | Private operations | @Mod / @Dev |

Keep the public list short at launch. Empty channels look abandoned; add them when the community needs
them.

## 2. Roles and permissions

| Role | Colour | Granted by | Key permissions |
|:---|:---|:---|:---|
| `@Player` | grey | join / self-assign | read public, post in community + support, voice |
| `@Playtester` | blue | self-assign or invite | early builds, `#playtest-builds` |
| `@Moderator` | amber | lead | timeout/kick/ban, manage messages, pin known issues |
| `@Dev` | red | lead | all channels, announcements, release posts |
| `@Bot` | — | lead | webhook + automation only |

Rules of thumb:

- `@everyone` is denied in support channels; use `@Player` for patch pings.
- Only `@Dev` posts in `#announcements` and `#known-issues`.
- Moderators do not promise fix dates. They confirm receipt, ask for the report, and link the issue.
- Give moderators a written escalation path: harassment → timeout, doxxing/security → ban + preserve
  evidence + notify lead.

## 3. Setup checklist (one-time)

- [ ] Create the server and enable Community features (rules screening, welcome).
- [ ] Create the categories/channels above; set slow mode (10 s) in `#bug-reports`.
- [ ] Create roles and permission overwrites; test with a second account.
- [ ] Enable AutoMod: block invite spam, mass mentions, and common slurs.
- [ ] Publish the rules in `#welcome` and require acceptance.
- [ ] Create a permanent invite with **no expiry** and limited uses only if needed.
- [ ] Set `BuildInfo.DISCORD_INVITE_URL` in `core/build_info.gd` to that invite. The in-game
      *Open Discord* button is hidden while the constant is empty.
- [ ] Add the invite to the Steam store page, website and README.
- [ ] Pin the bug-report template in `#bug-reports`.
- [ ] Add a moderator, a `#mod-log` webhook, and a backup owner account.
- [ ] Test the flow: report a bug in-game → copy → paste in `#bug-reports` → open a GitHub issue.

## 4. Bug intake

### 4.1 In-game reporter (preferred)

Pause menu → **Report a bug**. The player writes what happened, optionally includes diagnostics, and
presses **Copy report**. The bundle contains:

- build version + channel;
- OS, GPU, CPU, renderer, locale;
- host/client, player count, shift, phase, meters, active call, crash-dump count;
- the player's description and category.

It never contains the player's name, IP address, voice audio or the settings file. A JSON copy is kept in
`user://bug_reports/` for 20 reports.

### 4.2 Discord template

Pin this in `#bug-reports`:

```
**Build:** (main-menu footer, e.g. BUILD 1.0.0-rc.1 · RC)
**Platform:** Windows / Linux / Steam Deck
**Category:** Gameplay / Crash / Performance / Audio / Multiplayer / UI
**What happened:**
**Steps to reproduce:**
1.
2.
**Expected:**
**Diagnostic report:** (paste the in-game copied report)
```

Ask for the copied report, not a screenshot of it — the text is searchable and can be attached to a
GitHub issue.

### 4.3 GitHub

The issue form (`.github/ISSUE_TEMPLATE/bug_report.yml`) requires build, platform, category and what
happened, and has a dedicated diagnostics field. Labels applied on creation: `bug`, `needs-triage`.
Add `s0`/`s1`/`s2`/`s3`, a platform label, and the affected version as triage progresses.

### 4.4 Steam forums

Community managers mirror confirmed bugs into GitHub and reply with the tracking link. Do not run two
separate ledgers.

## 5. Triage flow

```
new → needs-info → confirmed → fix-in-progress → fixed-in-build → verified → closed
             └──────────────────────────────→ duplicate / not-a-bug / wont-fix
```

| State | Meaning | Who moves it |
|:---|:---|:---|
| `new` | not read yet | on-call triager |
| `needs-info` | missing build/repro/report; ask once with the template | triager |
| `confirmed` | reproduced on a named build | QA / dev |
| `fix-in-progress` | owner + branch assigned | dev |
| `fixed-in-build` | fix is in a beta/RC build | dev |
| `verified` | fix checked on the build players will get | QA |
| `closed` | shipped, duplicate, not-a-bug, or wont-fix | triager |

Service targets (best effort, not a contract): first response S0 ≤ 30 min, S1 ≤ 2 h, S2 ≤ 1 business day,
S3 ≤ 3 business days. Severity definitions live in the day-one plan.

Every confirmed bug gets:

- one canonical GitHub issue (dedupe Discord/Steam threads into it);
- the affected build(s) and a reproduction;
- a linked fix commit/PR and the build where it shipped;
- a reply in the original thread when it is fixed.

## 6. Privacy and safety

- Never ask for an IP address, home address, full name, or voice recordings in a public channel.
- The in-game report is anonymous by design; do not add identifying fields to the template.
- If a player pastes a path with a username, edit the message and ask them to remove it.
- Crash dumps may contain scene state; treat them as internal unless the player explicitly shares one.
- Doxxing, threats, and cheat distribution: remove, preserve evidence, ban, notify the lead.
- GDPR/deletion requests go to the privacy contact listed on the store page; do not handle them in chat.

## 7. Launch-day comms

| Time | Action |
|:---|:---|
| T-24h | Pin `#known-issues` with the RC's open S1/S2 list; post the launch time in `#announcements`. |
| T-0 | Post the launch build number and the bug-report link; open the war room. |
| T+2h | First health post: crash-free sessions, top reports, any hotfix decision. |
| T+24h | Patch or known-issue update; thank testers by name where they helped. |
| T+72h | Retro: what the server caught that CI did not. Feed it back into the QA checklist. |

## 8. Metrics to review weekly

- reports per 1,000 players, and the share that include a diagnostic report;
- time to first response and time to verified fix, by severity;
- duplicate rate (a high rate means the template/search is not working);
- Discord → GitHub conversion (how many chat reports became tickets);
- crash-free session rate and the top three crash signatures.
