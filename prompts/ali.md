# Prompt — Ali Imad (`ali`)

> **Role:** 3D, World, Art & UI
> **GitHub:** [@Ali-Imad-Dev](https://github.com/Ali-Imad-Dev) · **Progress file:** `data/progress/ali.json`

## هويتك بالمشروع (for the AI)

تشتغل ويا **Ali Imad**، المسؤول عن **كل شي يشوفه اللاعب**:

- **الـ 3D والعالم:** grey-box لمركز Station 4، غرفة العمليات، خرائط المهام (Farmhouse، Flooded Lake House، Abandoned Highway)، الأبواب والـ props.
- **الفن:** موديلات الشخصيات والأعداء، الإضاءة (Volumetric Fog، الظلال)، شكل VHS / Bodycam، الـ key art والتريلر.
- **الواجهات (UI/UX):** القائمة واللوبي، الهاتف والحوارات، واجهة الـ VSA، الكاميرات، السجلات، لوحة القضية، HUD الميدان، تقرير النوبة، شاشة التفرعات (Flowchart)، الإعدادات، التعليم، صور متجر Steam، و Steam Deck.
- **محرر الحوارات المرئي** (GraphEdit plugin).

المجلدات: `scenes/boot/`, `scenes/dispatch/`, `scenes/field/<maps>/`, `scenes/aftermath/`, `ui/`, `art/`, `addons/dialogue_editor/`.
المرجع: الـ GDD للجو العام (واقعي مظلم، VHS، Bodycam)، و `docs/GAMEPLAY_MECHANICS.md` §5 (أدوات غرفة العمليات) و §10 (السيناريوهات).

**يعتمد على:** Adnan (player controller، signals الـ CallDirector، Health/Sanity، Mission flow)، و Mohamed (Resources الحوارات والمكالمات P2-01/P2-02).
**نصيحة:** ابدأ بـ grey-box و placeholder UI بسرعة، لأن الكل يحتاجها للاختبار. الأصول الكبيرة ترفعها بـ Git LFS.

## المهام (24)

| ID | Cat | المجموعة | المهمة |
| :--- | :--- | :--- | :--- |
| P1-14 | GAME | Player Controller | Door system (open, peek, kick, locked) — replicated |
| P1-18 | ART | Grey-box | Grey-box Station 4 ops room + armory + parking |
| P1-19 | UI | Grey-box | Main menu, host/join, lobby with class cards |
| P2-03 | UI | Data Layer | Visual dialogue graph editor plugin |
| P2-07 | UI | Dispatch Tools | Phone/headset UI + choice pings |
| P2-09 | UI | Dispatch Tools | VSA scrub-and-tag mini-game |
| P2-11 | UI | Dispatch Tools | CCTV grid (SubViewports) |
| P2-12 | UI | Dispatch Tools | Records database terminal |
| P2-13 | UI | Dispatch Tools | Case Board |
| P2-18 | ART | Content | Operations room art pass v1 |
| P3-16 | ART | Missions | Map: Farmhouse |
| P3-17 | ART | Missions | Map: Flooded Lake House + water shader |
| P3-18 | ART | Missions | Map: Abandoned Highway + RPG set piece |
| P3-20 | UI | Missions | Field HUD (bodycam overlay) |
| P3-21 | ART | Missions | Character models (4 classes + 3 hostiles) |
| P4-06 | UI | Consequences | Aftermath shift report |
| P4-07 | UI | Consequences | Detroit-style flowchart screen |
| P4-11 | ART | Polish | VHS / bodycam post-process |
| P4-12 | ART | Polish | Lighting pass |
| P4-14 | UI | Polish | Settings & accessibility |
| P4-15 | UI | Polish | Onboarding tutorial ("Training Night") |
| P5-04 | UI | Steam Release | Store page assets |
| P5-05 | ART | Steam Release | Key art & trailer |
| P5-08 | UI | Steam Release | Steam Deck verification |

> المصدر الحي للحالات: `data/progress/ali.json` + `data/tasks.json`.

---

## برومبتات جاهزة

### 🟢 بداية الجلسة
```text
أنا Ali. اقرأ AGENTS.md و prompts/ali.md و data/progress/ali.json.
لخّصلي وين وصلت، وشوف data/progress/adnan.json و mohamed.json إذا الأنظمة اللي تحتاجها واجهاتي وخرائطي خلصت، واقترح المهمة الجاية.
```

### 🧱 Grey-box والأبواب والقوائم (P1-14, P1-18, P1-19)
```text
أنا Ali. سوّي grey-box لـ Station 4 (غرفة عمليات بـ 4 مكاتب dispatch، مخزن سلاح، موقف سيارات) بـ CSGCombiner3D،
ونظام أبواب (open / peek / kick / locked) يتزامن عبر الشبكة، وقائمة رئيسية + Host/Join + لوبي بـ 4 بطاقات فئات.
الستايل: مظلم تكتيكي، أمبر #f59e0b وسيان #06b6d4.
```

### 🖥️ واجهات غرفة العمليات (P2-07, P2-09, P2-11 → P2-13)
```text
أنا Ali. ابني <Phone UI | VSA scrub & tag | CCTV grid | Records terminal | Case Board> بـ ui/dispatch/
حسب docs/GAMEPLAY_MECHANICS.md §5. شكل الشاشات CRT قديم (scanlines، خط monospace). اربطها بـ signals الـ CallDirector و VSA من Adnan.
```

### ✍️ محرر الحوارات (P2-03)
```text
أنا Ali. اكتب EditorPlugin بـ addons/dialogue_editor/ يعرض DialogueGraph (من Mohamed P2-02) كـ GraphEdit:
nodes للسطور، ports للخيارات، وحقول required_class و required_evidence، مع Save/Load لملف .tres.
```

### 🗺️ الخرائط والشخصيات (P2-18, P3-16 → P3-18, P3-21)
```text
أنا Ali. ابني خريطة <Farmhouse | Flooded Lake House | Abandoned Highway> حسب سيناريوهات GAMEPLAY_MECHANICS §10:
grey-box أولاً + NavigationRegion3D + نقاط اقتحام + مناطق مظلمة للكيانات، وبعدها art pass.
```

### 🎞️ الشكل النهائي والواجهات (P3-20, P4-06, P4-07, P4-11, P4-12, P4-14, P4-15)
```text
أنا Ali. نفّذ <Field HUD | Shift report | Flowchart | VHS post-process | Lighting | Settings | Tutorial>.
الـ VHS: chromatic aberration + scanlines + noise + timestamp، ويتأثر بالـ Sanity.
الـ Flowchart: يقرأ FlagSystem.events ويعرض الفروع المفتوحة والمقفولة مثل Detroit: Become Human.
```

### 🛒 Steam (P5-04, P5-05, P5-08)
```text
أنا Ali. جهّز صور متجر Steam (capsules، screenshots)، و key art بستايل bodycam، وتأكد إن الواجهات تشتغل على Steam Deck (controller + حجم الخط).
```

### 🔄 التسجيل والرفع (تلقائي)
ما تحتاج تطلبه. بعد كل شغل مكتمل الـ AI يحدّث `data/progress/ali.json` ويسوي commit و push من نفسه (AGENTS.md §3).
إذا تريد تفرض تحديث معيّن:
```text
المهمة <ID> صارت <done|testing|blocked>، الملاحظة: <...>. سجّلها وارفعها.
```
