# Prompt — Mohamed (`mohamed`)

> **Role:** UI/UX, Audio & Art: Dispatch Experience & Maps
> **GitHub:** [@MohamedFSD](https://github.com/MohamedFSD) · **Progress file:** `data/progress/mohamed.json`

## هويتك بالمشروع (for the AI)

تشتغل ويا **Mohamed**، المسؤول عن كل شي يشوفه ويسمعه اللاعب:

- **واجهات غرفة العمليات:** الهاتف والحوارات، محلل نبرة الصوت (VSA)، شبكة الكاميرات، قاعدة السجلات، ولوحة القضية.
- **أدوات المحرر:** محرر الحوارات المرئي (GraphEdit plugin).
- **الصوت:** أصوات المتصلين، مؤثرات Dead Frequency، الأجواء، الموسيقى، والمكساج.
- **الفن:** مباني الـ grey-box، غرفة العمليات، خرائط المهام الثلاث، الشخصيات، شكل VHS/Bodycam، والإضاءة.
- **الواجهات العامة:** القائمة الرئيسية، اللوبي، HUD الميدان، تقرير النوبة، شاشة التفرعات (Flowchart)، الإعدادات، والتعليم.
- **متجر Steam:** الصور، التريلر، الترجمة (عربي RTL)، و Steam Deck.

المجلدات الأساسية: `ui/`, `audio/`, `scenes/dispatch/`, `scenes/field/<maps>`, `scenes/boot/`, `scenes/aftermath/`, `addons/dialogue_editor/`.
المرجع: `docs/GAMEPLAY_MECHANICS.md` §5 (أدوات الإرسال)، §9 (الرعب)، `docs/ARCHITECTURE.md` §6.3 (Audio buses)، والـ GDD للجو العام (واقعي مظلم، VHS، Bodycam).

**يعتمد على:** Adnan (P2-01/P2-02 Resources، P1-15 voice buses)، Ali (CallDirector signals، Health/Sanity للـ HUD، Mission flow).
**يعتمد عليه:** الكل، لأن الخرائط والواجهات لازمة للاختبار. ابدأ بـ grey-box و placeholder UI بسرعة.

## المهام (28)

| ID | Cat | المجموعة | المهمة |
| :--- | :--- | :--- | :--- |
| P1-18 | ART | Grey-box | Grey-box Station 4 ops room + armory + parking |
| P1-19 | UI | Grey-box | Main menu, host/join, lobby with class cards |
| P2-03 | UI | Data Layer | Visual dialogue graph editor plugin |
| P2-07 | UI | Dispatch Tools | Phone/headset UI + choice pings |
| P2-08 | AUDIO | Dispatch Tools | Voice Stress Analyzer |
| P2-09 | UI | Dispatch Tools | VSA scrub-and-tag mini-game |
| P2-11 | UI | Dispatch Tools | CCTV grid (SubViewports) |
| P2-12 | UI | Dispatch Tools | Records database terminal |
| P2-13 | UI | Dispatch Tools | Case Board |
| P2-16 | AUDIO | Content | Caller VO for 3 slice calls |
| P2-18 | ART | Content | Operations room art pass v1 |
| P3-14 | AUDIO | Anomalies | Dead Frequency radio mimicry |
| P3-16 | ART | Missions | Map: Farmhouse |
| P3-17 | ART | Missions | Map: Flooded Lake House + water shader |
| P3-18 | ART | Missions | Map: Abandoned Highway + RPG set piece |
| P3-20 | UI | Missions | Field HUD (bodycam overlay) |
| P3-21 | ART | Missions | Character models (4 classes + 3 hostiles) |
| P4-06 | UI | Consequences | Aftermath shift report |
| P4-07 | UI | Consequences | Detroit-style flowchart screen |
| P4-11 | ART | Polish | VHS / bodycam post-process |
| P4-12 | ART | Polish | Lighting pass |
| P4-13 | AUDIO | Polish | Ambience, foley, music, mix |
| P4-14 | UI | Polish | Settings & accessibility |
| P4-15 | UI | Polish | Onboarding tutorial ("Training Night") |
| P5-04 | UI | Steam Release | Store page assets |
| P5-05 | ART | Steam Release | Key art & trailer |
| P5-06 | GAME | Steam Release | Localization (English + Arabic RTL) |
| P5-08 | UI | Steam Release | Steam Deck verification |

> المصدر الحي للحالات: `data/progress/mohamed.json` + `data/tasks.json`.

---

## برومبتات جاهزة

### 🟢 بداية الجلسة
```text
أنا Mohamed. اقرأ AGENTS.md و prompts/mohamed.md و data/progress/mohamed.json.
لخّصلي وين وصلت، وشوف data/progress/adnan.json و ali.json إذا الأنظمة اللي تحتاجها واجهاتي خلصت، واقترح المهمة الجاية.
```

### 🧱 Grey-box والقوائم (P1-18, P1-19)
```text
أنا Mohamed. سوّي grey-box لـ Station 4 (غرفة عمليات فيها 4 مكاتب dispatch، مخزن سلاح، موقف سيارات) بـ CSGCombiner3D،
وقائمة رئيسية + Host/Join + لوبي بـ 4 بطاقات فئات (Tech Operator, Profiler, Breacher, Investigator/Medic).
استخدم NetManager.lobby_updated signal من Adnan. الستايل: مظلم تكتيكي، أمبر #f59e0b وسيان #06b6d4. حدّث تقدمي.
```

### 🖥️ أدوات غرفة العمليات (P2-07 → P2-13)
```text
أنا Mohamed. ابني <Phone UI | VSA | CCTV grid | Records terminal | Case Board> بـ ui/dispatch/
حسب docs/GAMEPLAY_MECHANICS.md §5.3 و §5.6. الـ VSA يعرض AudioEffectSpectrumAnalyzer حي + منحنيات StressProfile،
ومعاه scrub window و Tag. خلّي شكل الشاشات CRT قديم (scanlines، خط monospace). اربط بـ signals الـ CallDirector من Ali.
```

### ✍️ محرر الحوارات (P2-03)
```text
أنا Mohamed. اكتب EditorPlugin بـ addons/dialogue_editor/ يعرض DialogueGraph (P2-02 من Adnan) كـ GraphEdit:
nodes للسطور، ports للخيارات، وحقول required_class و required_evidence و patience_delta، مع Save/Load لملف .tres.
```

### 🔊 الصوت (P2-08, P2-16, P3-14, P4-13)
```text
أنا Mohamed. جهّز الصوت لـ <مكالمة | Dead Frequency | الأجواء>: رتّب audio/ حسب الـ buses بـ docs/ARCHITECTURE.md §6.3.
للـ Dead Frequency: reverse + pitch shift + bandpass على صوت زميل مسجّل، وتتفعل عن طريق Tension Director (من Ali).
```

### 🗺️ الخرائط والشخصيات (P3-16 → P3-18, P3-21)
```text
أنا Mohamed. ابني خريطة <Farmhouse | Flooded Lake House | Abandoned Highway> حسب سيناريوهات docs/GAMEPLAY_MECHANICS.md §10:
grey-box أولاً + NavigationRegion3D + نقاط الاقتحام + مناطق مظلمة لنقاط الـ Anomaly. ارفع الملفات الكبيرة بـ Git LFS.
```

### 🎞️ الشكل النهائي (P4-06, P4-07, P4-11 → P4-15)
```text
أنا Mohamed. نفّذ <VHS post-process | Shift report | Flowchart | Settings | Tutorial>.
الـ VHS: chromatic aberration + scanlines + noise + timestamp overlay، ويتأثر بالـ Sanity.
الـ Flowchart: يقرأ FlagSystem.events ويعرض الفروع المفتوحة والمقفولة مثل Detroit: Become Human.
```

### 🔄 التسجيل والرفع (تلقائي)
ما تحتاج تطلبه. بعد كل شغل مكتمل الـ AI يحدّث `data/progress/mohamed.json` ويسوي commit و push من نفسه (AGENTS.md §3).
إذا تريد تفرض تحديث معيّن:
```text
المهمة <ID> صارت <done|testing|blocked>، الملاحظة: <...>. سجّلها وارفعها.
```
