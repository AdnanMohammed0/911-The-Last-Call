# Prompt — Adnan (`adnan`)

> **Role:** Lead Programmer: Networking, Core Systems & Release
> **GitHub:** [@AdnanMohammed0](https://github.com/AdnanMohammed0) · **Progress file:** `data/progress/adnan.json`

## هويتك بالمشروع (for the AI)

تشتغل ويا **Adnan**، قائد المشروع ومبرمج البنية التحتية. هو المسؤول عن:

- **هيكل مشروع Godot** والـ autoloads (`EventBus`, `GameState`, `NetManager`) والـ CI.
- **الشبكات:** ENet، Steam P2P، اللوبي، spawn، synchronization، التحقق من الـ RPC.
- **خط الصوت الشبكي:** التقاط المايك، Opus، الصوت القريب، الراديو.
- **طبقة البيانات:** Resources للمكالمات والحوارات، ونظام التصويت.
- **نظام الرايات والعواقب** (`FlagSystem`, `ConsequenceRule`) والحفظ.
- **الأداء، Steamworks، الـ QA، والإصدار.**

المجلدات الأساسية: `autoload/`, `core/net/`, `core/`, `data/consequences/`, `tests/`.
المرجع التقني: `docs/ARCHITECTURE.md` (§3، §4، §6، §7، §8).

**يعتمد عليه:** Ali (spawn، sync، FlagSystem) و Mohamed (voice bus، data resources).
أولوية Adnan: **كل شي يمنع الآخرين من الشغل يُنجز أولاً** (P1-01، P1-04، P1-06، P2-01، P4-01).

## المهام (27)

| ID | Cat | المجموعة | المهمة |
| :--- | :--- | :--- | :--- |
| P1-01 | GAME | Project Foundation | Create Godot 4.x project, folder layout, autoload skeletons |
| P1-02 | GAME | Project Foundation | Git LFS, .gitignore, GUT, static typing warnings |
| P1-03 | GAME | Project Foundation | CI build pipeline (GitHub Actions) |
| P1-04 | NET | Networking | NetManager host/join via ENet |
| P1-05 | NET | Networking | Lobby roster sync, ready-up, class selection |
| P1-06 | NET | Networking | MultiplayerSpawner for players |
| P1-07 | NET | Networking | MultiplayerSynchronizer for player state |
| P1-08 | NET | Networking | Host-side movement & RPC validation |
| P1-09 | NET | Networking | Steam P2P transport via GodotSteam |
| P1-10 | NET | Networking | Disconnect handling & reconnect slots |
| P1-11 | NET | Networking | Network debug overlay |
| P1-15 | AUDIO | Voice Prototype | Mic → Opus → channel 2 → playback |
| P1-16 | AUDIO | Voice Prototype | Proximity attenuation + PTT / VAD |
| P1-17 | AUDIO | Voice Prototype | Radio channel bus + squelch |
| P2-01 | GAME | Data Layer | CallData, StressProfile, RecordEntry resources |
| P2-02 | GAME | Data Layer | DialogueGraph / Node / Choice resources |
| P2-05 | NET | Call Director | Handset token & replicated dialogue state |
| P2-14 | NET | Assessment & Vote | Verdict & approach voting system |
| P4-01 | GAME | Consequences | FlagSystem runtime + replication |
| P4-02 | GAME | Consequences | ConsequenceRule / FlagCondition / FlagEffect |
| P4-05 | GAME | Consequences | Versioned JSON save system |
| P4-16 | GAME | Polish | Performance pass |
| P5-01 | NET | Steam Release | Steamworks: achievements, presence, cloud |
| P5-02 | NET | Steam Release | NAT traversal / relay validation |
| P5-03 | GAME | Steam Release | Crash reporting & telemetry |
| P5-07 | GAME | Steam Release | Full QA regression (network matrix) |
| P5-10 | GAME | Steam Release | Release candidate & day-one plan |

> المصدر الحي للحالات: `data/progress/adnan.json` + `data/tasks.json`.

---

## برومبتات جاهزة

### 🟢 بداية الجلسة
```text
أنا Adnan. اقرأ AGENTS.md و prompts/adnan.md و data/progress/adnan.json.
لخّصلي وين وصلت، وشنو المهام اللي توقف شغل Ali و Mohamed (blocked عندهم بسببي)، واقترح المهمة الجاية.
```

### 🧱 أساس المشروع (P1-01 → P1-03)
```text
أنا Adnan. نفّذ P1-01 و P1-02: أنشئ مشروع Godot 4 بالهيكل الموجود بـ docs/ARCHITECTURE.md §2،
وسوي autoload skeletons (EventBus, GameState, NetManager, FlagSystem, VoiceManager, SaveManager) بـ static typing،
وأضف GUT وملف .gitattributes لـ Git LFS. بعدين حدّث تقدمي.
```

### 🌐 الشبكات (P1-04 → P1-11)
```text
أنا Adnan. اشتغل على <P1-04 | P1-05 | P1-06 | P1-07 | P1-08>.
اتبع docs/ARCHITECTURE.md §4 حرفياً: host-authoritative، وكل RPC من نوع any_peer يتحقق من المرسل، ورايبليتي حسب جدول §4.3.
اكتب مشهد اختبار scenes/boot/net_test.tscn يشغّل host + client على نفس الجهاز. حدّث تقدمي بحالة testing لحد ما أأكد الاختبار.
```

### 🎙️ الصوت الشبكي (P1-15 → P1-17)
```text
أنا Adnan. نفّذ خط الصوت حسب docs/ARCHITECTURE.md §6: AudioEffectCapture → Opus → rpc على channel 2 unreliable_ordered → jitter buffer → AudioStreamGenerator.
سوي الـ buses (VoiceProximity, VoiceRadio) بالإعدادات المكتوبة، واترك الـ SFX والمكساج النهائي لـ Mohamed.
```

### 🗂️ طبقة البيانات والتصويت (P2-01, P2-02, P2-05, P2-14)
```text
أنا Adnan. اكتب Resources: CallData, StressProfile, RecordEntry, DialogueGraph, DialogueNode, DialogueChoice
حسب docs/GAMEPLAY_MECHANICS.md §5، مع validator بسيط. بعدها نظام التصويت (verdict + approach) مع timeout و tie-breaker.
هذي المهام يعتمد عليها Ali (CallDirector) و Mohamed (Dialogue editor)، فخلّي الـ API واضح وموثّق.
```

### 🦋 نظام العواقب والحفظ (P4-01, P4-02, P4-05)
```text
أنا Adnan. طبّق FlagSystem و ConsequenceRule و FlagCondition و FlagEffect من docs/ARCHITECTURE.md §7،
مع GUT tests تغطي: IMMEDIATE، DELAYED_MINUTES، NEXT_SHIFT، once. بعدها SaveManager (atomic write + schema_version + migrations).
```

### 🚀 الإصدار (P5-*)
```text
أنا Adnan. جهّز <P5-01 | P5-02 | P5-07>. اكتب checklist بـ PROGRESS.md للاختبار (2/3/4 لاعبين، 150ms latency، 5% packet loss) وحدّث تقدمي.
```

### 🔄 التسجيل والرفع (تلقائي)
ما تحتاج تطلبه. بعد كل شغل مكتمل الـ AI يحدّث `data/progress/adnan.json` ويسوي commit و push من نفسه (AGENTS.md §3).
إذا تريد تفرض تحديث معيّن:
```text
المهمة <ID> صارت <done|testing|blocked>، الملاحظة: <...>. سجّلها وارفعها.
```
