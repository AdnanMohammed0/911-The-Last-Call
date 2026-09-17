# Prompt — Adnan (`adnan`)

> **Role:** AI, Networking & Core Gameplay
> **GitHub:** [@AdnanMohammed0](https://github.com/AdnanMohammed0) · **Progress file:** `docs/data/progress/adnan.json`

## هويتك بالمشروع (for the AI)

تشتغل ويا **Adnan**، قائد المشروع. هو مسؤول عن **المهام البرمجية الثقيلة**:

- **الذكاء الاصطناعي:** Behavior Trees، الإدراك، الغطاء، أنواع الأعداء، تكتيكات الفرق، الكيانات الخارقة (FSM)، الـ Tension Director، الهلوسات، وطور حصار المركز.
- **الشبكات والصوت الشبكي:** ENet، Steam P2P، اللوبي، spawn/sync، التحقق من الـ RPC، الصوت القريب، الراديو، والتصويت.
- **جزء من اللعب:** هيكل المشروع، متحكم اللاعب والتفاعل، مدير المكالمات، القتال والصحة والـ Sanity وقدرات الفئات، منطق محلل نبرة الصوت، مسار المهمة، ونظام الرايات (FlagSystem) والأداء.

المجلدات: `autoload/`, `core/net/`, `core/bt/`, `core/fsm/`, `scenes/shared/player/`, `scenes/field/anomalies/`, `tests/`.
المرجع: `docs/design/ARCHITECTURE.md` (§3–§7)، و `docs/design/GAMEPLAY_MECHANICS.md` (§2، §3، §5، §7–§9).

**يعتمد عليه:** Ali (الخرائط تحتاج player و mission flow، والواجهات تحتاج signals)، و Mohamed (يبني فوق FlagSystem و CallDirector).
**الأولوية:** المهام اللي توقف شغل الباقين تخلص أولاً: P1-01، P1-04، P1-06، P1-12، P2-04، P4-01.

## المهام (37)

| ID | Cat | المجموعة | المهمة |
| :--- | :--- | :--- | :--- |
| P1-01 | GAME | Project Foundation | Create Godot 4.x project, folder layout, autoload skeletons |
| P1-04 | NET | Networking | NetManager host/join via ENet |
| P1-05 | NET | Networking | Lobby roster sync, ready-up, class selection RPCs |
| P1-06 | NET | Networking | MultiplayerSpawner for players |
| P1-07 | NET | Networking | MultiplayerSynchronizer for player state |
| P1-08 | NET | Networking | Host-side movement & RPC validation |
| P1-09 | NET | Networking | Steam P2P transport via GodotSteam |
| P1-10 | NET | Networking | Disconnect handling & reconnect slots |
| P1-11 | NET | Networking | Network debug overlay |
| P1-12 | GAME | Player Controller | First-person controller (walk, sprint, crouch, lean, stamina) |
| P1-13 | GAME | Player Controller | Networked interaction system |
| P1-15 | AUDIO | Voice Prototype | Mic → Opus → channel 2 → playback |
| P1-16 | AUDIO | Voice Prototype | Proximity attenuation + PTT / VAD |
| P1-17 | AUDIO | Voice Prototype | Radio channel bus + squelch |
| P2-04 | GAME | Call Director | CallDirector: shift clock, queue, lifecycle |
| P2-05 | NET | Call Director | Handset token & replicated dialogue state |
| P2-08 | AUDIO | Dispatch Tools | Voice Stress Analyzer (logic) |
| P2-14 | NET | Assessment & Vote | Verdict & approach voting system |
| P3-01 | GAME | Combat | Weapon framework + lag compensation |
| P3-02 | GAME | Combat | Health, location damage, downed/revive |
| P3-03 | GAME | Combat | Sanity system + Panic bus driver |
| P3-04 | GAME | Combat | Class abilities |
| P3-07 | AI | Hostile AI | Behavior tree runtime + debugger |
| P3-08 | AI | Hostile AI | Perception & awareness |
| P3-09 | AI | Hostile AI | Cover queries & navmesh |
| P3-10 | AI | Hostile AI | Archetypes (Thug, Cultist, Zealot, Leader, Hostage Taker) |
| P3-11 | AI | Hostile AI | Squad tactics, morale & surrender |
| P3-12 | AI | Anomalies | Anomaly FSM + Drowned Woman |
| P3-13 | AI | Anomalies | Tension Director + per-peer hallucinations |
| P3-14 | AUDIO | Anomalies | Dead Frequency radio mimicry |
| P3-19 | GAME | Missions | Mission flow (drive, arrive, objectives, extract) |
| P4-01 | GAME | Consequences | FlagSystem runtime + replication |
| P4-02 | GAME | Consequences | ConsequenceRule / FlagCondition / FlagEffect |
| P4-09 | AI | Consequences | Station Siege horde mode |
| P4-16 | GAME | Polish | Performance pass |
| P5-01 | NET | Steam Release | Steamworks: achievements, presence, cloud |
| P5-02 | NET | Steam Release | NAT traversal / relay validation |

> المصدر الحي للحالات: `docs/data/progress/adnan.json` + `docs/data/tasks.json`.

---

## برومبتات جاهزة

### 🟢 بداية الجلسة
```text
أنا Adnan. اقرأ docs/AGENTS.md و docs/prompts/adnan.md و docs/data/progress/adnan.json.
لخّصلي وين وصلت، وشنو مهامي اللي موقفة شغل Ali و Mohamed، واقترح المهمة الجاية.
```

### 🧱 أساس المشروع واللاعب (P1-01, P1-12, P1-13)
```text
أنا Adnan. أنشئ مشروع Godot 4 بالهيكل الموجود بـ docs/design/ARCHITECTURE.md §2 مع autoload skeletons بـ static typing،
وبعدها FPS controller (walk/sprint/crouch/lean/stamina) ونظام التفاعل الشبكي حسب §4.4.
```

### 🌐 الشبكات (P1-04 → P1-11, P2-05, P2-14)
```text
أنا Adnan. اشتغل على <P1-04 | P1-05 | P1-06 | P1-07 | P1-08 | P2-14>.
اتبع docs/design/ARCHITECTURE.md §4 حرفياً: host-authoritative، وكل RPC من نوع any_peer يتحقق من المرسل.
اكتب مشهد اختبار يشغّل host + client على نفس الجهاز.
```

### 🎙️ الصوت الشبكي والتحليل (P1-15 → P1-17, P2-08, P3-14)
```text
أنا Adnan. نفّذ خط الصوت حسب docs/design/ARCHITECTURE.md §6 (Capture → Opus → channel 2 → jitter buffer → Generator)،
ومنطق محلل نبرة الصوت (GAMEPLAY_MECHANICS §5.3) مع API واضح. الواجهة الرسومية للـ VSA يسويها Ali.
```

### ☎️ مدير المكالمات والقتال (P2-04, P3-01 → P3-04, P3-19)
```text
أنا Adnan. اكتب CallDirector (host فقط) حسب §5.1، ونظام الأسلحة مع lag compensation، والصحة/السقوط/الإنعاش، والـ Sanity، وقدرات الفئات،
وبعدها Mission flow. وفّر signals واضحة لـ Ali (HUD) و Mohamed (المؤقتات، الصفات، المؤشرات).
```

### 🤖 الأعداء (P3-07 → P3-11)
```text
أنا Adnan. ابني Behavior Tree runtime بـ core/bt/ (Selector, Sequence, Condition, Action, Blackboard) حسب §8،
وبعدها Cultist Gunman كامل: perception و morale و surrender و flank tokens. الـ AI يشتغل على الـ host بس، بـ 10Hz staggered.
```

### 👻 الكيانات والرعب (P3-12, P3-13, P4-09)
```text
أنا Adnan. نفّذ Drowned Woman FSM حسب GAMEPLAY_MECHANICS §9.2، والـ Tension Director (§9.3) مع هلوسات per-peer،
وطور Station Siege (wave spawner بغرفة العمليات).
```

### 🦋 نظام الرايات والأداء (P4-01, P4-02, P4-16)
```text
أنا Adnan. طبّق FlagSystem و ConsequenceRule و FlagCondition و FlagEffect من ARCHITECTURE §7 مع GUT tests،
حتى Mohamed يبني فوقها الصفات والمؤشرات والنهايات.
```

### 🔄 التسجيل والرفع (تلقائي)
ما تحتاج تطلبه. بعد كل شغل مكتمل الـ AI يحدّث `docs/data/progress/adnan.json` ويسوي commit و push من نفسه (docs/AGENTS.md §3).
إذا تريد تفرض تحديث معيّن:
```text
المهمة <ID> صارت <done|testing|blocked>، الملاحظة: <...>. سجّلها وارفعها.
```
