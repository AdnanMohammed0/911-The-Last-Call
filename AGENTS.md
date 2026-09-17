# AGENTS.md — تعليمات الذكاء الاصطناعي لمشروع 911: The Last Call

> هذا الملف موجّه لأي مساعد ذكاء اصطناعي (Claude Code, Cursor, Copilot, ChatGPT…) يشتغل على هذا المستودع.
> This file instructs any AI coding agent working in this repository. Follow it before doing anything else.

---

## 0. قواعد ثابتة (Hard Rules)

1. **ممنوع إضافة أي توقيع للذكاء الاصطناعي** في الـ commits أو الـ PRs: لا `Co-Authored-By: Claude`، ولا `Generated with …`، ولا أي attribution مشابه. المساهمون بالمشروع هم أعضاء الفريق فقط.
2. لا تعدّل ملف تقدم عضو آخر (`data/progress/<id>.json`). كل عضو يحدّث ملفه فقط، وبهذي الطريقة ما يصير تعارض (merge conflict).
3. لا تغيّر `data/tasks.json` يدوياً. المصدر هو `docs/PROJECT_ROADMAP.md`، وبعد تعديله شغّل `python scripts/build_tasks.py`.
4. قبل الـ push: `python scripts/validate_progress.py` ثم `git pull --rebase`.
5. **التسجيل والرفع تلقائي:** بعد أي شغل مكتمل حدّث ملف التقدم وسوّي commit + push بدون ما ينطلب منك (§3).

---

## 1. تعرّف على صاحب الجلسة (Identify the member)

شغّل:

```bash
python scripts/whoami.py
```

- يطابق `git config user.email` / `user.name` / حساب `gh` مع `data/team.json`.
- إذا طبع `adnan` أو `ali` أو `mohamed` → هذا هو العضو.
- إذا فشل (exit 1) → **اسأل المستخدم**: «منو أنت؟ adnan / ali / mohamed»، ولا تكمل قبل الجواب.
- إذا المستخدم ذكر اسمه صراحةً بالبرومبت («أنا علي…») فاعتمد كلامه.

| id | الاسم | GitHub | ملف البرومبت | ملف التقدم |
| :--- | :--- | :--- | :--- | :--- |
| `adnan` | Adnan | AdnanMohammed0 | [`prompts/adnan.md`](prompts/adnan.md) | `data/progress/adnan.json` |
| `ali` | Ali Imad | Ali-Imad-Dev | [`prompts/ali.md`](prompts/ali.md) | `data/progress/ali.json` |
| `mohamed` | Mohamed | MohamedFSD | [`prompts/mohamed.md`](prompts/mohamed.md) | `data/progress/mohamed.json` |

## 2. حمّل سياق العضو (Load context)

اقرأ بالترتيب:

1. `prompts/<id>.md`: دور العضو، مهامه، وقواعده الخاصة.
2. `data/progress/<id>.json`: وين وصل.
3. `data/tasks.json`: فلتر المهام على `"owner": "<id>"`.
4. الوثائق حسب الحاجة: `docs/ARCHITECTURE.md` و`docs/GAMEPLAY_MECHANICS.md` و`docs/PROJECT_ROADMAP.md` و`game_design_document_911_The_Last_call.md`.

بعدها لخّص للمستخدم بسطرين: شنو آخر شي سواه، وشنو المهمة الجاية المقترحة (أول مهمة `progress`، وإذا ماكو فأول مهمة `backlog` بترتيب الـ ID).

## 3. سجّل التقدم وارفعه تلقائياً (إلزامي، بدون ما يطلب المستخدم)

**أول ما تخلص أي شغل** (مهمة كاملة، أو جزء واضح منها، أو نهاية الجلسة)، سوّي هذي الخطوات **من نفسك** بدون ما تسأل المستخدم. العضو **ما يضيف أي شي يدوياً** بالموقع:

1. حدّث `data/progress/<id>.json`:

```jsonc
{
  "member": "ali",
  "updated_at": "2026-09-20",            // تاريخ اليوم
  "tasks": {
    "P1-12": {
      "status": "progress",              // backlog | progress | testing | done | blocked
      "note": "حركة المشي والركض جاهزة، باقي lean و crouch",
      "updated_at": "2026-09-20"
    }
  },
  "log": [                                // أحدث إدخال بالأسفل
    {
      "date": "2026-09-20",
      "tasks": ["P1-12"],
      "summary": "بناء FPS controller: walk/sprint/stamina + اختبار مع لاعبين.",
      "files": ["scenes/shared/player/player.gd"]
    }
  ]
}
```

2. تحقق وارفع على GitHub:

```bash
python scripts/validate_progress.py
git add -A
git commit -m "feat(player): FPS controller walk/sprint — P1-12"
git pull --rebase
git push
```

| الحالة | متى |
| :--- | :--- |
| `progress` | بدأ الشغل فعلياً |
| `testing` | الكود مكتمل وينتظر اختبار (خصوصاً اختبار شبكة بلاعبين 2+) |
| `done` | اختُبر واشتغل ومرفوع على `main` |
| `blocked` | متوقف. اكتب السبب بـ `note` (مثلاً: ينتظر P1-06 من adnan) |
| `backlog` | لا تكتبها. غياب المهمة من الملف يعني backlog |

**رسائل الـ commit:** دائماً اذكر رقم المهمة (`P1-12`)، واستخدم `done P1-12` لما تكتمل. هذا يخلي الـ GitHub Action يفهمها حتى لو نسيت تحدّث الملف.

### طبقات الحماية (لا تعطّلها)

| الطبقة | شنو تسوي |
| :--- | :--- |
| **هذا الملف** | القاعدة الأساسية لأي AI |
| **Claude Code Stop hook** (`.claude/settings.json` → `scripts/hooks/stop_check.py`) | إذا حاولت تنهي الجلسة وأكو تغييرات مو مرفوعة، يمنعك ويطلب تسجّل التقدم وتسوي push |
| **GitHub Action** (`.github/workflows/auto-progress.yml`) | أي push ما حدّث `data/progress/` يتسجّل تلقائياً بملف صاحبه، والحالة تنقرأ من رسالة الـ commit (`done P1-04`، `test P1-04`، `blocked P1-04`) |

إذا المستخدم قال صراحةً «لا ترفع هسه»، التزم بكلامه وبلّغه إن الشغل مو مرفوع.

## 4. الأفكار (Ideas)

إذا العضو قال «عندي فكرة…» أو «ضيف فكرة»:

- **الطريقة المفضلة:** افتح GitHub Issue بعنوان يبدأ بـ `[فكرة]` مع label `idea`:
  `gh issue create --title "[فكرة] <العنوان>" --label idea --body "<التفاصيل>\n\n— <id>"`
- **البديل** (بدون gh): أضف عنصر بـ `data/ideas.json` بـ id جديد متسلسل (`I-007`…)، و`author` = id العضو، و`status` = `new`.

## 5. أسلوب الكود

- Godot 4.x + GDScript مع static typing كامل.
- اتبع `docs/ARCHITECTURE.md` §10 (Coding Standards) وقواعد الشبكة §4.3 (كل RPC من نوع `any_peer` يتحقق من المرسل).
- Commits بصيغة Conventional Commits: `feat(net): …`, `fix(ai): …`, `progress(ali): …`.
