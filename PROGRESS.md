# PROGRESS — 911: The Last Call

> Living sprint tracker. Update daily. Task IDs reference [`docs/PROJECT_ROADMAP.md`](docs/PROJECT_ROADMAP.md).
> Visual version: open [`index.html`](index.html) in any browser.

**Current Phase:** Phase 1 — Core Prototype & Networking
**Current Milestone:** M1 — "Four On The Line"
**Sprint Length:** 1 week (Mon → Sun)
**Last Updated:** 2026-09-17

---

## 📊 Status Snapshot

Live per-member progress is on the website (**Team** tab) and in `data/progress/<id>.json`. It updates automatically when each member's AI finishes work (see `AGENTS.md` §3).

| Member | Tasks | Progress file |
| :--- | :---: | :--- |
| Adnan (`@adnan`) | 37 | [`data/progress/adnan.json`](data/progress/adnan.json) |
| Ali Imad (`@ali`) | 24 | [`data/progress/ali.json`](data/progress/ali.json) |
| Mohamed (`@mohamed`) | 23 | [`data/progress/mohamed.json`](data/progress/mohamed.json) |
| **Total** | **84** | |

---

## 🏃 Active Sprint

### Sprint 01 — 2026-09-14 → 2026-09-20
**Sprint Goal:** Godot project skeleton + two players connected over ENet in a grey-box room.

| ID | Task | Owner | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| P1-01 | Project, folder layout, autoload skeletons | Adnan | 🟦 Todo | |
| P1-02 | Git LFS, GUT, typing warnings | Mohamed | 🟦 Todo | |
| P1-04 | ENet host/join | Adnan | 🟦 Todo | |
| P1-12 | First-person controller | Adnan | 🟦 Todo | |
| P1-18 | Grey-box operations room | Ali | 🟦 Todo | |

**Legend:** 🟦 Todo · 🟨 In Progress · 🟪 Testing · 🟩 Done · 🟥 Blocked

---

## 📅 Daily Log

<!-- Copy this block for each day. Newest on top. -->

### 2026-09-17 (Thu)
- **Done:**
  - [x] Documentation suite written (Architecture, Gameplay Mechanics, Roadmap)
  - [x] Progress dashboard (`index.html`) created
  - [x] Repository initialized and pushed
  - [x] Tasks split across 3 members, per-member prompts, automatic progress (hook + Action), new website on GitHub Pages
- **Doing next:**
  - [ ] P1-01 Create Godot project skeleton
- **Blockers:** none
- **Notes:** GDD working title "911: Dead Line" → shipping title "911: The Last Call".

<!--
### YYYY-MM-DD (Day)
- **Done:**
  - [x]
- **Doing next:**
  - [ ]
- **Blockers:**
- **Notes:**
-->

---

## ✅ Completed Features

| Date | ID | Feature | Phase | PR / Commit |
| :--- | :--- | :--- | :--- | :--- |
| 2026-09-17 | — | Documentation suite & progress dashboard | Pre-production | initial docs commit |

---

## 🐞 Bug Backlog

| ID | Severity | Area | Summary | Repro Steps | Status | Found | Fixed |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| BUG-000 | — | — | *(template row — delete when first real bug is logged)* | — | — | — | — |

**Severity:** `S1` Crash / data loss / desync · `S2` Blocks progression · `S3` Major functional · `S4` Minor / cosmetic

### Bug Report Template
```text
ID:            BUG-###
Severity:      S1 | S2 | S3 | S4
Area:          NET | GAME | AUDIO | AI | UI | ART
Build:         <commit hash>
Players:       <n>, host = <name>, transport = ENet | Steam
Steps:         1. … 2. … 3. …
Expected:      …
Actual:        …
Frequency:     Always | Often | Rare
Logs/Video:    <link>
```

---

## 📈 Key Performance Indicators

### Development KPIs
| KPI | Target | Current | Trend |
| :--- | :--- | :--- | :--- |
| Sprint task completion rate | ≥ 80 % | — | — |
| Open S1/S2 bugs | 0 at milestone | 0 | — |
| GUT test pass rate | 100 % | — | — |
| CI build success rate | ≥ 95 % | — | — |
| Roadmap schedule variance | ≤ 1 week | 0 | — |

### Technical KPIs
| KPI | Target | Current |
| :--- | :--- | :--- |
| Average FPS (GTX 1060, 1080p) | ≥ 60 | — |
| 1 % low FPS | ≥ 45 | — |
| Bandwidth per client (gameplay) | ≤ 64 kbps | — |
| Voice mouth-to-ear latency | ≤ 200 ms | — |
| Desyncs per 30-min 4P session | 0 | — |
| Level load time (SSD) | ≤ 8 s | — |
| Crash-free sessions | ≥ 99.5 % | — |

### Design / Playtest KPIs
| KPI | Target | Current |
| :--- | :--- | :--- |
| Correct call classification rate | 55–70 % (hard but fair) | — |
| Dispatch fun rating | ≥ 4 / 5 | — |
| Field mission fun rating | ≥ 4 / 5 | — |
| "I felt scared" rating | ≥ 3.5 / 5 | — |
| Players who noticed a consequence of an earlier choice | ≥ 80 % | — |
| Session completion (full shift) | ≥ 70 % | — |
| Ending distribution (Gold / Siege / Static) | ~20 / 45 / 35 % | — |

### Release KPIs (Phase 5)
| KPI | Target | Current |
| :--- | :--- | :--- |
| Steam wishlists at Next Fest | 20,000 | — |
| Demo → wishlist conversion | ≥ 15 % | — |
| Steam review score (first 30 days) | ≥ 85 % positive | — |
| Median playtime | ≥ 4 h | — |

---

## 🗓️ Milestone History

| Milestone | Planned | Actual | Result | Retro Notes |
| :--- | :--- | :--- | :--- | :--- |
| M1 — Four On The Line | Week 6 | — | — | — |
| M2 — Is This A Prank? | Week 12 | — | — | — |
| M3 — Vertical Slice | Week 22 | — | — | — |
| M4 — Content Complete | Week 30 | — | — | — |
| M5 — The Last Call | Week 36 | — | — | — |

---

## 🔁 Sprint Retrospective Template

```markdown
### Sprint NN Retro — YYYY-MM-DD
**Went well:**
-
**Didn't go well:**
-
**Action items:**
- [ ]
**Velocity:** planned X / done Y
```
