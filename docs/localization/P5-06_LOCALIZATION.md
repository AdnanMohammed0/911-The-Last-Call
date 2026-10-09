# Localization Pipeline — 911: The Last Call (P5-06)

## Overview
English and Arabic, with the whole interface mirrored right-to-left in Arabic. Translations run on
Godot's built-in `TranslationServer`, so scene text is translated without touching a single `.tscn`
and code strings use the normal `tr()` helper.

Task: `P5-06` · Owner: `@mohamed` · Authority: LOCAL

---

## 1. How it works

```
data/localization/ui_en.loc  ─┐
data/localization/ui_ar.loc  ─┤  Localization (autoload) ─> TranslationServer
assets/fonts/NotoSansArabic…  ─┘        │
                                         ├─> tr() in code
GameSettings.language (user://settings) ─┤
                                         └─> root Window.layout_direction (LTR / RTL)
```

1. **`data/localization/ui_<locale>.csv`** — one table per language. The **key is the English
   source string** and the value is the translation. That single choice is what makes both
   `text = "Settings"` in a scene and `tr("Settings")` in code work with one table.
2. **`autoload/localization.gd`** — on boot it reads every table in `SUPPORTED_LOCALES`, builds a
   `Translation` resource per language and registers it with the `TranslationServer`.
3. **`GameSettings.language`** — persisted in `user://settings.cfg` under `[language] locale`, so the
   choice survives a restart. The autoload applies it on the next boot.
4. **Settings ▸ General ▸ Language** — the picker. Each language is listed in its own script
   (`English`, `العربية`), so an Arabic player never has to read English to find their language.

Registered **after** `GameSettings` in `project.godot`, because it reads the saved language during
`_ready()`.

## 2. Right-to-left support

| Concern | How it is handled |
|:---|:---|
| Layout mirroring | `get_tree().root.layout_direction` is set to `LAYOUT_DIRECTION_RTL` / `LAYOUT_DIRECTION_LTR`. Every `Control` inherits the direction from the root window, so **no scene needs per-node changes**. |
| Why not `LAYOUT_DIRECTION_APPLICATION_LOCALE`? | That resolves through the engine's own locale detection. The project keeps its own `RTL_LOCALES` list, so the direction is set explicitly — deterministic, and testable without an OS locale. |
| Text order | Godot's text server shapes Arabic (contextual letter forms and ligatures) automatically. |
| Font | `assets/fonts/NotoSansArabic-Regular.ttf` is installed as the theme's default font while Arabic is active. The engine's built-in font has **no Arabic glyphs**, so without this every Arabic label renders as empty boxes. English restores the engine default. |
| Live menus | The settings menu listens for `language_changed` and rebuilds its tabs, because labels are assigned once at build time. |
| Mirrored widgets | `Control` mirrors its own layout, but a widget that must stay readable (a VSA waveform, a CCTV feed, a minimap) should set `layout_direction = LAYOUT_DIRECTION_LTR` on itself. |

## 3. Adding or changing a string

1. Add the English source string as the key to **both** tables:
   ```csv
   "Ankle Monitor","Ankle Monitor"
   ```
   ```csv
   "Ankle Monitor","مراقب الكاحل"
   ```
2. Or wrap the code string in `tr()` and run the validator, which will tell you the key is missing:
   ```gdscript
   _label.text = tr("Ankle Monitor")
   ```
3. Run `python docs/scripts/validate_locales.py`.

**No scene edits are needed** for a `text = "..."` property — add the key and it is translated.

## 4. Validation

`docs/scripts/validate_locales.py` runs in CI (`.github/workflows/ci.yml`, job `docs`) and fails on:

- a key present in one language but missing from another;
- a duplicate or empty entry;
- **format specifiers that differ from English** — a dropped `%s` would crash the format call at runtime;
- a value not written in its own script (an English string left in the Arabic column, or Arabic in the English one);
- a non-English key;
- a `tr("...")` literal or a `.tscn` `text` / `placeholder_text` property with **no table entry** — the
  case that otherwise fails silently in-game and shows the player raw English;
- a language listed in `SUPPORTED_LOCALES` with no CSV file.

Placeholder strings are skipped: `00:00` and `127.0.0.1` contain no letters and are never translated.

The interface is assembled in code (`UiKit` / `KitButton`) rather than stored as `.tscn` text, and
helpers such as `_row()` and `_section()` call `tr()` on whatever they are handed. A bare `tr("...")`
scan would therefore miss most of the menu, so the validator also collects prose literals passed to
those helpers. Those are reported as a **backlog warning**, not an error: untranslated copy is a gap
in content, not a broken pipeline, and it stays visible so it is not forgotten. Strings that are
actually passed through `tr()` without a table entry remain hard errors.

`docs/scripts/check_gdscript.py` also runs in CI. It is not a compiler; it catches bracket, quote and
indentation damage in the GDScript files touched by this task.

## 5. Testing

`tests/test_localization.gd` (GUT) covers: both tables registered, Arabic output, English passthrough,
placeholder integrity, unknown-key passthrough, locale switching, the `language_changed` signal, unknown
locales falling back to English, RTL flags, root-window mirroring, the Arabic font being installed, the
settings round trip, and the native language labels.

## 6. Adding a third language

1. Add the code to `SUPPORTED_LOCALES`, and to `RTL_LOCALES` if it reads right-to-left.
2. Add `LOCALE_LABELS["<code>"]` in its own script.
3. Copy `ui_en.loc` to `ui_<code>.loc` and fill in the values.
4. Add a font if the script is not covered by the existing ones.
5. Run the validator — it will list every string still untranslated.

## 7. Known limits

- Coverage is the **main menu, settings, pause menu and HUD** (159 strings). The station OS, loadout,
  dispatch terminal and class card are still English-only: they are built with the same `UiKit`
  helpers but have not been routed through `tr()` yet, and the validator reports them as a backlog
  warning (see §4). Dialogue, call scripts and VO subtitles are also still English-only; those need
  per-call subtitle files, tracked separately.
- The validator skips non-Latin **plural forms**; Arabic has six. Strings with counts currently reuse
  the singular phrasing.
- Arabic is not yet proof-read by a native speaker; treat the current table as a working baseline.
- Pseudo-localization (`TranslationServer.pseudolocalization_enabled`) is available for layout testing
  but is not enabled by default.

## 8. Asset licence

`assets/fonts/NotoSansArabic-Regular.ttf` — **Noto Sans Arabic**, Google, licensed under the
**SIL Open Font License 1.1**. Tracked via Git LFS.
