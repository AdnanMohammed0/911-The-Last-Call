# PROJECT ROADMAP — 911: The Last Call

> Target: **Steam Early Access** with a complete first campaign (3 shifts, 3 endings) for 2–4 players.
> Team assumption: 2–4 core developers + contract audio/3D. Estimates are in weeks from project start.
> Task IDs match the website ([`index.html`](../index.html)). Tags: `NET` Networking · `GAME` Core Gameplay · `AUDIO` Audio/Voice · `AI` AI · `UI` UI/UX · `ART` 3D Art.
> Owner tags: `@adnan` · `@ali` · `@mohamed` (see [`data/team.json`](../data/team.json)). After editing tasks here, run `python scripts/build_tasks.py`.

## Team Ownership

| Member | Focus | Tasks |
| :--- | :--- | :---: |
| **Adnan** `@adnan` | AI (behavior trees, anomalies, director), networking & voice, core gameplay (player, combat, call director, flags) | 37 |
| **Ali Imad** `@ali` | 3D, world & art (grey-box, maps, characters, lighting, VHS look) and all UI/UX | 24 |
| **Mohamed** `@mohamed` | Lighter programming: data resources, tooling/CI, content authoring, meters/traits/save logic, audio mix, QA & release chores | 23 |

| Phase | Name | Weeks | Exit Criteria (Definition of Done) |
| :--- | :--- | :--- | :--- |
| **1** | Core Prototype & Networking | 1–6 | 4 players connect over ENet & Steam, walk around a grey-box station, interact with doors, basic voice works |
| **2** | Dispatch & Dialogue Engine | 7–12 | Full playable Dispatch phase: 3 data-driven calls with VSA, trace, CCTV, verdicts, votes |
| **3** | Field Gameplay & AI | 13–22 | 3 field missions playable end-to-end with hostile AI and one anomaly |
| **4** | Consequence Matrix & Polish | 23–30 | Persistent campaign across 3 shifts, traits, meters, 3 endings, art & audio pass |
| **5** | Steam Release | 31–36 | Store page live, Steamworks integration, QA passed, Early Access launch |

---

## Phase 1 — Core Prototype & Networking (Weeks 1–6)

**Goal:** prove the co-op foundation. Nothing else matters if 4 players can't reliably share a world.

### 1.1 Project Foundation
- [ ] `P1-01` `GAME` `@adnan` Create Godot 4.x project, folder layout, autoload skeletons (`EventBus`, `GameState`, `NetManager`)
- [ ] `P1-02` `GAME` `@mohamed` Set up Git LFS, `.gitignore`, GUT test framework, static-typing warnings as errors
- [ ] `P1-03` `GAME` `@mohamed` CI build pipeline (GitHub Actions: headless export Windows/Linux + GUT tests)

### 1.2 Networking
- [ ] `P1-04` `NET` `@adnan` `NetManager` host/join via ENet (port 24911, 4 peers max)
- [ ] `P1-05` `NET` `@adnan` Lobby roster sync, ready-up, class selection RPCs
- [ ] `P1-06` `NET` `@adnan` `MultiplayerSpawner` for players with class-aware spawn function
- [ ] `P1-07` `NET` `@adnan` `MultiplayerSynchronizer` for player transform, stance, flashlight
- [ ] `P1-08` `NET` `@adnan` Host-side movement validation & RPC validation helpers
- [ ] `P1-09` `NET` `@adnan` Steam P2P transport via GodotSteam (`SteamMultiplayerPeer`), lobby invites
- [ ] `P1-10` `NET` `@adnan` Disconnect handling, return-to-menu, reconnect slot reservation
- [ ] `P1-11` `NET` `@adnan` Network debug overlay (RTT, packet loss, bandwidth per channel)

### 1.3 Player Controller
- [ ] `P1-12` `GAME` `@adnan` First-person controller (walk, sprint, crouch, lean, stamina)
- [ ] `P1-13` `GAME` `@adnan` Interaction system (raycast, prompts, hold-to-interact, networked)
- [ ] `P1-14` `GAME` `@ali` Door system (open, peek, kick, locked) — replicated

### 1.4 Voice Prototype
- [ ] `P1-15` `AUDIO` `@adnan` Mic capture → Opus → unreliable channel 2 → `AudioStreamGenerator` playback
- [ ] `P1-16` `AUDIO` `@adnan` Proximity attenuation on `AudioStreamPlayer3D` + push-to-talk / VAD
- [ ] `P1-17` `AUDIO` `@adnan` Radio channel with bandpass/distortion bus + squelch SFX

### 1.5 Grey-box
- [ ] `P1-18` `ART` `@ali` Grey-box Station 4 operations room + armory + parking lot
- [ ] `P1-19` `UI` `@ali` Main menu, host/join screens, lobby UI with class cards

**Milestone M1 — "Four On The Line":** 4-player session over Steam, 30-minute soak test, no desyncs.

---

## Phase 2 — Dispatch & Dialogue Engine (Weeks 7–12)

**Goal:** the operations room is fun on its own.

### 2.1 Data Layer
- [ ] `P2-01` `GAME` `@mohamed` `CallData`, `StressProfile`, `RecordEntry` resources + validator tool
- [ ] `P2-02` `GAME` `@mohamed` `DialogueGraph` / `DialogueNode` / `DialogueChoice` resources
- [ ] `P2-03` `UI` `@ali` Editor plugin: visual dialogue graph editor (GraphEdit based)

### 2.2 Call Director
- [ ] `P2-04` `GAME` `@adnan` `CallDirector` (host): shift clock, call queue, ring/answer/missed lifecycle
- [ ] `P2-05` `NET` `@adnan` Handset token ownership & replicated dialogue state
- [ ] `P2-06` `GAME` `@mohamed` Caller patience timer & timer-pressure modifiers

### 2.3 Dispatch Tools
- [ ] `P2-07` `UI` `@ali` Phone/headset UI with dialogue choices & teammate choice pings
- [ ] `P2-08` `AUDIO` `@adnan` Voice Stress Analyzer: live spectrum + authored stress curves, loop detector, background isolate
- [ ] `P2-09` `UI` `@ali` VSA scrub-and-tag mini-game → Case Board evidence
- [ ] `P2-10` `GAME` `@mohamed` Trace mini-game (3-tower triangulation) for Tech Operator
- [ ] `P2-11` `UI` `@ali` CCTV grid with camera hijack & feed rendering (SubViewports)
- [ ] `P2-12` `UI` `@ali` Records database terminal (criminal records, property history)
- [ ] `P2-13` `UI` `@ali` Case Board (evidence pins, Pattern Link for Investigator)

### 2.4 Assessment & Vote
- [ ] `P2-14` `NET` `@adnan` Verdict & approach voting system with timeouts and tie-breakers
- [ ] `P2-15` `GAME` `@mohamed` Loadout armory with budget, class-locked items, requisition

### 2.5 Content
- [ ] `P2-16` `AUDIO` `@mohamed` Record/source caller VO for 3 slice calls (Closet Monster, Cut Line, Meat Truck)
- [ ] `P2-17` `GAME` `@mohamed` Author 5 filler calls (pranks, noise complaints, shoplifting)
- [ ] `P2-18` `ART` `@ali` Operations room art pass v1 (CRT monitors, analog phones, wall map)

**Milestone M2 — "Is This A Prank?":** playtest where 70 % of testers correctly classify ≥ 2 of 3 slice calls and rate dispatch ≥ 4/5 fun.

---

## Phase 3 — Field Gameplay & AI (Weeks 13–22)

**Goal:** tense, readable CQB and genuine horror.

### 3.1 Combat
- [ ] `P3-01` `GAME` `@adnan` Weapon framework (hitscan, recoil patterns, reload, host-validated fire with lag compensation)
- [ ] `P3-02` `GAME` `@adnan` Health, location damage, downed/revive, bleed-out
- [ ] `P3-03` `GAME` `@adnan` Sanity system + bands + Panic audio bus driver
- [ ] `P3-04` `GAME` `@adnan` Class abilities: shield, kick, ram, drone, megaphone, tear gas, revive, sedative, salt, tone
- [ ] `P3-05` `GAME` `@mohamed` Arrest & ROE (surrender, cuffs, excessive-force events)
- [ ] `P3-06` `GAME` `@mohamed` Noise event system (footsteps, gunshots, voice loudness)

### 3.2 Hostile AI
- [ ] `P3-07` `AI` `@adnan` Behavior tree runtime (selector, sequence, decorators, blackboard) + debugger
- [ ] `P3-08` `AI` `@adnan` Perception: vision cone, flashlight detection, hearing, awareness meter
- [ ] `P3-09` `AI` `@adnan` Cover query system & navmesh baking per mission
- [ ] `P3-10` `AI` `@adnan` Archetypes: Thug, Cultist Gunman, Zealot, Ambush Leader, Hostage Taker
- [ ] `P3-11` `AI` `@adnan` Squad tactics: flank tokens, callouts, morale & surrender

### 3.3 Anomalies
- [ ] `P3-12` `AI` `@adnan` Anomaly FSM base + Drowned Woman (dormant→manifest→stalk→hunt→attack→retreat)
- [ ] `P3-13` `AI` `@adnan` Tension Director + per-peer hallucinations
- [ ] `P3-14` `AUDIO` `@adnan` Dead Frequency radio mimicry (teammate voice replay / reverse)
- [ ] `P3-15` `GAME` `@mohamed` EMF reader, banish ritual, remains-burial objective

### 3.4 Missions
- [ ] `P3-16` `ART` `@ali` Mission map: Farmhouse ("Scratching Behind the Wall")
- [ ] `P3-17` `ART` `@ali` Mission map: Flooded Lake House ("Call From a Cut Line") with water-rise shader
- [ ] `P3-18` `ART` `@ali` Mission map: Abandoned Highway ("The Meat Truck") + decoy cruiser RPG set piece
- [ ] `P3-19` `GAME` `@adnan` Mission flow: patrol drive, arrival, objectives, extraction, mission result
- [ ] `P3-20` `UI` `@ali` Field HUD: minimal bodycam overlay, radio indicator, sanity vignette, objective ticker
- [ ] `P3-21` `ART` `@ali` Character models: 4 officer classes + 3 hostile variants (rigged)

**Milestone M3 — "Vertical Slice":** one shift with 3 calls → 3 missions playable start to finish with 4 players.

---

## Phase 4 — Consequence Matrix & Polish (Weeks 23–30)

**Goal:** choices matter, and the game looks & sounds like a VHS nightmare.

### 4.1 Consequences
- [ ] `P4-01` `GAME` `@adnan` `FlagSystem` with events, pending rules, replication, snapshot
- [ ] `P4-02` `GAME` `@adnan` `ConsequenceRule` / `FlagCondition` / `FlagEffect` resources + authoring of slice rules
- [ ] `P4-03` `GAME` `@mohamed` Trait system (Limping, Fractured Hand, PTSD, Phantom Ringing, Hardened…)
- [ ] `P4-04` `GAME` `@mohamed` Global meters: Public Trust, Station Budget, Cult Awareness + threshold effects
- [ ] `P4-05` `GAME` `@mohamed` Save system: versioned JSON, atomic writes, migrations, Steam Cloud
- [ ] `P4-06` `UI` `@ali` Aftermath shift report (events timeline, meter deltas, traits gained, leads unlocked)
- [ ] `P4-07` `UI` `@ali` Detroit-style flowchart screen showing branches taken / locked
- [ ] `P4-08` `GAME` `@mohamed` Ending resolver + 3 endings (Whistleblowers, Station Under Siege, Lost in the Static)
- [ ] `P4-09` `AI` `@adnan` Station Siege horde-survival mode (wave spawner in operations room)
- [ ] `P4-10` `GAME` `@mohamed` Shifts 2 & 3 content: interrogation call, cult hideout mission, diversion calls

### 4.2 Polish
- [ ] `P4-11` `ART` `@ali` VHS / bodycam post-process (chromatic aberration, scanlines, timestamp overlay)
- [ ] `P4-12` `ART` `@ali` Lighting pass (volumetric fog, flashlight shadows, SDFGI/LightmapGI per map)
- [ ] `P4-13` `AUDIO` `@mohamed` Ambience, foley, music stingers, full mix pass
- [ ] `P4-14` `UI` `@ali` Settings: graphics, audio devices, mic test, keybinds, accessibility (subtitles, colorblind, arachnophobia-style toggles)
- [ ] `P4-15` `UI` `@ali` Onboarding tutorial shift ("Training Night")
- [ ] `P4-16` `GAME` `@adnan` Performance pass: profiling, LODs, occlusion culling, AI tick budget

**Milestone M4 — "Content Complete":** 3-shift campaign with all endings reachable; external playtest (20+ groups).

---

## Phase 5 — Steam Release (Weeks 31–36)

- [ ] `P5-01` `NET` `@adnan` Steamworks: achievements, rich presence, friends invites, Steam Cloud
- [ ] `P5-02` `NET` `@adnan` NAT traversal / relay fallback validation (Steam Datagram Relay)
- [ ] `P5-03` `GAME` `@mohamed` Crash reporting & telemetry opt-in (anonymous KPIs)
- [ ] `P5-04` `UI` `@ali` Store page assets: capsule art, screenshots, trailer, description
- [ ] `P5-05` `ART` `@ali` Key art & trailer capture (bodycam footage style)
- [ ] `P5-06` `GAME` `@mohamed` Localization pipeline (English + Arabic with RTL UI support)
- [ ] `P5-07` `GAME` `@mohamed` Full QA regression: networking matrix (2/3/4 players, high latency, packet loss)
- [ ] `P5-08` `UI` `@ali` Steam Deck verification (controller UI, text size, performance)
- [ ] `P5-09` `GAME` `@mohamed` Steam Next Fest demo build (Training Night + Shift 1)
- [ ] `P5-10` `GAME` `@mohamed` Release candidate, day-one patch plan, community Discord & bug report flow

**Milestone M5 — "The Last Call":** Early Access launch.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
| :--- | :---: | :---: | :--- |
| Voice chat latency / quality in Godot | High | High | Prototype in Phase 1; Steam Voice fallback |
| Scope creep in branching content | High | High | Data-driven rules; cap slice to 3 shifts; flowchart audit each sprint |
| Host-authoritative combat feels laggy | Medium | High | Client-side hit prediction + host confirm; 150 ms test gate |
| Horror loses tension in co-op banter | Medium | Medium | Per-peer hallucinations, Listener anomaly punishing loud voice |
| Asset production bottleneck | Medium | Medium | Kitbash packs, grey-box-first, contractor for characters |
| Steam P2P NAT issues | Low | High | Steam Datagram Relay, ENet direct-IP fallback |
