# Prompt — Ali Imad (`ali`)

> **Role:** Gameplay & AI Programmer: Combat, Hostiles, Anomalies, Consequences
> **GitHub:** [@Ali-Imad-Dev](https://github.com/Ali-Imad-Dev) · **Progress file:** `data/progress/ali.json`

## هويتك بالمشروع (for the AI)

تشتغل ويا **Ali Imad**، مبرمج أسلوب اللعب والذكاء الاصطناعي. هو المسؤول عن:

- **متحكم اللاعب** بمنظور الشخص الأول، والتفاعل، والأبواب.
- **مدير المكالمات** (`CallDirector`): ساعة النوبة، الطابور، صبر المتصل، لعبة التتبع، والتجهيز (Loadout).
- **القتال:** الأسلحة، الصحة، السقوط والإنعاش، الـ Sanity، قدرات الفئات، الاعتقال، والضوضاء.
- **الذكاء الاصطناعي:** Behavior Trees، الإدراك، الغطاء، أنواع الأعداء، وتكتيكات الفرق.
- **الكيانات الخارقة:** FSM للـ Drowned Woman، الـ Tension Director، الهلوسات.
- **منطق العواقب بالميدان:** الصفات (Traits)، المؤشرات العامة، النهايات، طور حصار المركز، ومحتوى النوبات 2 و 3.

المجلدات الأساسية: `scenes/shared/player/`, `scenes/field/`, `core/bt/`, `core/fsm/`, `data/traits/`, `data/calls/` (المنطق).
المرجع: `docs/GAMEPLAY_MECHANICS.md` (كلها) + `docs/ARCHITECTURE.md` §4.4 و §5.

**يعتمد على:** Adnan (P1-04/P1-06/P1-07 للشبكة، P2-01 للـ Resources، P4-01 للـ FlagSystem).
**يعتمد عليه:** Mohamed (HUD يقرأ الصحة والـ Sanity؛ الخرائط تحتاج Mission flow).
إذا مهمة معتمدة على شي ما خلص، ابدأ بنسخة offline (لاعب واحد)، وحط الحالة `blocked` مع note تذكر المهمة المطلوبة.

## المهام (29)

| ID | Cat | المجموعة | المهمة |
| :--- | :--- | :--- | :--- |
| P1-12 | GAME | Player Controller | First-person controller (walk, sprint, crouch, lean, stamina) |
| P1-13 | GAME | Player Controller | Networked interaction system |
| P1-14 | GAME | Player Controller | Door system (open, peek, kick, locked) |
| P2-04 | GAME | Call Director | CallDirector: shift clock, queue, lifecycle |
| P2-06 | GAME | Call Director | Caller patience & timer pressure |
| P2-10 | GAME | Dispatch Tools | Trace mini-game (3-tower triangulation) |
| P2-15 | GAME | Assessment & Vote | Loadout armory with budget |
| P2-17 | GAME | Content | Author 5 filler calls |
| P3-01 | GAME | Combat | Weapon framework + lag compensation |
| P3-02 | GAME | Combat | Health, location damage, downed/revive |
| P3-03 | GAME | Combat | Sanity system + Panic bus driver |
| P3-04 | GAME | Combat | Class abilities |
| P3-05 | GAME | Combat | Arrest & ROE |
| P3-06 | GAME | Combat | Noise event system |
| P3-07 | AI | Hostile AI | Behavior tree runtime + debugger |
| P3-08 | AI | Hostile AI | Perception & awareness |
| P3-09 | AI | Hostile AI | Cover queries & navmesh |
| P3-10 | AI | Hostile AI | Archetypes (Thug, Cultist, Zealot, Leader, Hostage Taker) |
| P3-11 | AI | Hostile AI | Squad tactics, morale & surrender |
| P3-12 | AI | Anomalies | Anomaly FSM + Drowned Woman |
| P3-13 | AI | Anomalies | Tension Director + per-peer hallucinations |
| P3-15 | GAME | Anomalies | EMF reader, banish ritual, burial objective |
| P3-19 | GAME | Missions | Mission flow (drive, arrive, objectives, extract) |
| P4-03 | GAME | Consequences | Trait system |
| P4-04 | GAME | Consequences | Global meters + thresholds |
| P4-08 | GAME | Consequences | Ending resolver + 3 endings |
| P4-09 | AI | Consequences | Station Siege horde mode |
| P4-10 | GAME | Consequences | Shifts 2 & 3 content |
| P5-09 | GAME | Steam Release | Next Fest demo build |

> المصدر الحي للحالات: `data/progress/ali.json` + `data/tasks.json`.

---

## برومبتات جاهزة

### 🟢 بداية الجلسة
```text
أنا Ali. اقرأ AGENTS.md و prompts/ali.md و data/progress/ali.json.
لخّصلي وين وصلت، وتأكد من data/progress/adnan.json إذا المهام اللي أعتمد عليها خلصت، واقترح المهمة الجاية.
```

### 🏃 متحكم اللاعب (P1-12 → P1-14)
```text
أنا Ali. نفّذ <P1-12 | P1-13 | P1-14> بـ scenes/shared/player/ حسب docs/ARCHITECTURE.md §4.4
(الحركة client-authoritative، والكاميرا تشتغل بس لصاحب الـ authority). الأبواب لازم تدعم open / peek / kick / locked وتتزامن عبر الشبكة.
حدّث تقدمي بعد ما أجرّب بلاعبين اثنين.
```

### ☎️ مدير المكالمات والتجهيز (P2-04, P2-06, P2-10, P2-15, P2-17)
```text
أنا Ali. اكتب CallDirector (host فقط) حسب docs/GAMEPLAY_MECHANICS.md §5.1 و §5.5:
ساعة النوبة 00:00→06:00، ورنين 20 ثانية ثم call_missed، وصبر المتصل مع المعدّلات. استعمل Resources اللي كتبها Adnan (P2-01).
بعدها Trace mini-game (§5.4) والـ Armory (§6). الواجهات الرسومية مسؤولية Mohamed، فأنت وفّر signals و API واضحة.
```

### 🔫 القتال (P3-01 → P3-06)
```text
أنا Ali. نفّذ <P3-01 ... P3-06> حسب docs/GAMEPLAY_MECHANICS.md §3 و §7 و docs/ARCHITECTURE.md §4.4
(الـ client يرسل request_fire، والـ host يعيد الـ raycast مع lag compensation 150ms). اكتب GUT tests للضرر وحسابات الـ Sanity.
```

### 🤖 الأعداء (P3-07 → P3-11)
```text
أنا Ali. ابني Behavior Tree runtime بـ core/bt/ (Selector, Sequence, Condition, Action, Blackboard) حسب §8،
وبعدها Cultist Gunman كامل بالشجرة المكتوبة: perception و morale و surrender و flank tokens. الـ AI يشتغل على الـ host بس، بـ 10Hz staggered.
```

### 👻 الكيانات والرعب (P3-12, P3-13, P3-15)
```text
أنا Ali. نفّذ Drowned Woman FSM حسب docs/GAMEPLAY_MECHANICS.md §9.2 (DORMANT→MANIFEST→STALK→HUNT→ATTACK→RETREAT)،
والـ Tension Director (§9.3) مع هلوسات تنرسل per-peer بـ rpc_id. أضف EMF reader وطقس الإبعاد.
```

### 🦋 العواقب والنهايات (P4-03, P4-04, P4-08 → P4-10)
```text
أنا Ali. استخدم FlagSystem (P4-01 من Adnan) وطبّق TraitSystem (§3.4) والمؤشرات (§4) و EndingResolver (ARCHITECTURE §7.6).
أنشئ ConsequenceRules لسيناريوهات النوبة الأولى، ومحتوى النوبتين 2 و 3.
```

### 🔄 التسجيل والرفع (تلقائي)
ما تحتاج تطلبه. بعد كل شغل مكتمل الـ AI يحدّث `data/progress/ali.json` ويسوي commit و push من نفسه (AGENTS.md §3).
إذا تريد تفرض تحديث معيّن:
```text
المهمة <ID> صارت <done|testing|blocked>، الملاحظة: <...>. سجّلها وارفعها.
```
