# Prompt — Mohamed (`mohamed`)

> **Role:** Light Programming: Data, Tooling, Content & Simple Systems
> **GitHub:** [@MohamedFSD](https://github.com/MohamedFSD) · **Progress file:** `docs/data/progress/mohamed.json`

## هويتك بالمشروع (for the AI)

تشتغل ويا **Mohamed**، المسؤول عن **المهام البرمجية السهلة** اللي ما تحتاج معالجة ثقيلة أو أداء عالي:

- **الأدوات:** Git LFS، GUT، و CI بـ GitHub Actions.
- **طبقة البيانات:** Resources للمكالمات والحوارات (`CallData`, `DialogueGraph`…)، وكتابة محتوى المكالمات والنوبات.
- **أنظمة بسيطة:** مؤقت صبر المتصل، لعبة التتبع، مخزن السلاح والميزانية، الاعتقال وقواعد الاشتباك (ROE)، أحداث الضوضاء، و EMF والطقوس.
- **منطق العواقب:** الصفات (Traits)، المؤشرات (الثقة/الميزانية)، الحفظ، وحساب النهايات. كلها فوق FlagSystem اللي يكتبه Adnan.
- **الصوت (محتوى):** أصوات المتصلين، الأجواء، والمكساج.
- **الإصدار:** تقارير الأعطال، الترجمة (عربي RTL)، قائمة الاختبار، نسخة الديمو، والـ release candidate.

**قواعد للـ AI ويا Mohamed:**
- اشرح الكود خطوة بخطوة وبعربي بسيط، واكتب تعليقات واضحة.
- قسّم المهمة لخطوات صغيرة، واختبر كل خطوة قبل ما تكمل (GUT test أو مشهد تجريبي).
- إذا المهمة احتاجت شي معقد (شبكات، AI، أداء)، وقف وسجّل الحالة `blocked` مع note تذكر إنها تحتاج Adnan.

المجلدات: `data/calls/`, `data/dialogue/`, `data/traits/`, `data/consequences/rules/`, `autoload/save_manager.gd`, `audio/`, `tests/`, `.github/workflows/`.
المرجع: `docs/design/GAMEPLAY_MECHANICS.md` §3–§6 و §10–§12، و `docs/design/ARCHITECTURE.md` §7.4 و §8.

**يعتمد على:** Adnan (FlagSystem P4-01، CallDirector P2-04، Health و Noise hooks).
**يعتمد عليه:** Adnan (CallData Resources P2-01)، و Ali (DialogueGraph P2-02 للمحرر).

## المهام (23)

| ID | Cat | المجموعة | المهمة |
| :--- | :--- | :--- | :--- |
| P1-02 | GAME | Project Foundation | Git LFS, .gitignore, GUT, static typing warnings |
| P1-03 | GAME | Project Foundation | CI build pipeline (GitHub Actions) |
| P2-01 | GAME | Data Layer | CallData, StressProfile, RecordEntry resources |
| P2-02 | GAME | Data Layer | DialogueGraph / Node / Choice resources |
| P2-06 | GAME | Call Director | Caller patience & timer pressure |
| P2-10 | GAME | Dispatch Tools | Trace mini-game (3-tower triangulation) |
| P2-15 | GAME | Assessment & Vote | Loadout armory with budget |
| P2-16 | AUDIO | Content | Caller VO for 3 slice calls |
| P2-17 | GAME | Content | Author 5 filler calls |
| P3-05 | GAME | Combat | Arrest & ROE |
| P3-06 | GAME | Combat | Noise event system |
| P3-15 | GAME | Anomalies | EMF reader, banish ritual, burial objective |
| P4-03 | GAME | Consequences | Trait system |
| P4-04 | GAME | Consequences | Global meters + thresholds |
| P4-05 | GAME | Consequences | Versioned JSON save system |
| P4-08 | GAME | Consequences | Ending resolver + 3 endings |
| P4-10 | GAME | Consequences | Shifts 2 & 3 content |
| P4-13 | AUDIO | Polish | Ambience, foley, music, mix |
| P5-03 | GAME | Steam Release | Crash reporting & telemetry |
| P5-06 | GAME | Steam Release | Localization (English + Arabic RTL) |
| P5-07 | GAME | Steam Release | QA regression checklist |
| P5-09 | GAME | Steam Release | Next Fest demo build |
| P5-10 | GAME | Steam Release | Release candidate & day-one plan |

> المصدر الحي للحالات: `docs/data/progress/mohamed.json` + `docs/data/tasks.json`.

---

## برومبتات جاهزة

### 🟢 بداية الجلسة
```text
أنا Mohamed. اقرأ docs/AGENTS.md و docs/prompts/mohamed.md و docs/data/progress/mohamed.json.
لخّصلي وين وصلت، وشوف docs/data/progress/adnan.json إذا الأنظمة اللي أحتاجها خلصت، واقترح أسهل مهمة جاية أكدر أبدي بيها.
```

### 🛠️ الأدوات و CI (P1-02, P1-03)
```text
أنا Mohamed. ضيف .gitattributes لـ Git LFS (png, glb, wav, ogg)، ونزّل GUT addon، وسوي GitHub Action يشغّل GUT tests بـ Godot headless.
اشرحلي كل خطوة.
```

### 🗂️ طبقة البيانات (P2-01, P2-02)
```text
أنا Mohamed. اكتب Resources: CallData, StressProfile, RecordEntry, DialogueGraph, DialogueNode, DialogueChoice
حسب docs/design/GAMEPLAY_MECHANICS.md §5.2 و §5.6 (بس @export fields + validate() بسيطة). Adnan و Ali يعتمدون عليها، فخلّي الأسماء نفس الموجودة بالوثيقة.
```

### ⏱️ أنظمة بسيطة (P2-06, P2-10, P2-15, P3-05, P3-06, P3-15)
```text
أنا Mohamed. نفّذ <مؤقت صبر المتصل | لعبة التتبع | مخزن السلاح والميزانية | الاعتقال | أحداث الضوضاء | EMF reader>
حسب GAMEPLAY_MECHANICS. خلّي المنطق بسيط وقابل للاختبار، واكتب GUT test.
```

### 📞 المحتوى (P2-16, P2-17, P4-10)
```text
أنا Mohamed. اكتب 5 مكالمات filler (مقالب، إزعاج، سرقة) كـ CallData + DialogueGraph .tres،
مع StressProfile لكل وحدة، وجهّز قائمة الأصوات المطلوبة (VO) مع النصوص.
```

### 🦋 العواقب والحفظ (P4-03, P4-04, P4-05, P4-08)
```text
أنا Mohamed. فوق FlagSystem (من Adnan): طبّق TraitSystem (§3.4)، والمؤشرات (§4)، و SaveManager بـ JSON (ARCHITECTURE §7.4 و §8)،
و EndingResolver (§7.6). كلها منطق بيانات بدون أداء ثقيل، ويا GUT tests.
```

### 🚀 الصوت والإصدار (P4-13, P5-03, P5-06, P5-07, P5-09, P5-10)
```text
أنا Mohamed. جهّز <مكساج الأصوات | تقارير الأعطال | الترجمة العربية | checklist الاختبار | نسخة الديمو | release candidate>.
```

### 🔄 التسجيل والرفع (تلقائي)
ما تحتاج تطلبه. بعد كل شغل مكتمل الـ AI يحدّث `docs/data/progress/mohamed.json` ويسوي commit و push من نفسه (docs/AGENTS.md §3).
إذا تريد تفرض تحديث معيّن:
```text
المهمة <ID> صارت <done|testing|blocked>، الملاحظة: <...>. سجّلها وارفعها.
```
