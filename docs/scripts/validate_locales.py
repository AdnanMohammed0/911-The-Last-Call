"""Validate the localization string tables in data/localization/.

Checks key parity across languages, format-specifier agreement with the source language, and that
each value is actually written in its own script. Run: python docs/scripts/validate_locales.py
(exit code 1 on errors).
"""
import csv, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
TABLE_DIR = ROOT / "data/localization"
AUTOLOAD = ROOT / "autoload/localization.gd"
SOURCE_LOCALE = "en"
ARABIC = re.compile(r"[؀-ۿ]")
# %s, %d, %+.2f ... but not the escaped %% literal, and not a prose percentage like "100%": a real
# specifier never sits directly after a digit, because that digit is part of a percentage.
FORMAT = re.compile(r"(?<!\d)%(?!%)[-+ #0]*[\d.]*[a-zA-Z]")

errors, warnings = [], []


def read_locales_from_autoload():
    """The GDScript constant is the single source of truth for which languages ship."""
    text = AUTOLOAD.read_text(encoding="utf-8")
    match = re.search(r"const\s+SUPPORTED_LOCALES\s*:\s*Array\[String\]\s*=\s*\[([^\]]*)\]", text)
    if not match:
        errors.append("autoload/localization.gd: could not read SUPPORTED_LOCALES")
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def read_table(locale):
    path = TABLE_DIR / f"ui_{locale}.loc"
    if not path.exists():
        errors.append(f"data/localization/ui_{locale}.csv is missing (declared in SUPPORTED_LOCALES)")
        return None
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    if not rows or rows[0][:2] != ["key", locale]:
        errors.append(f"data/localization/ui_{locale}.csv: header must be 'key,{locale}'")
        return None
    table, seen = {}, set()
    for lineno, row in enumerate(rows[1:], start=2):
        if not row or not row[0].strip() or row[0].lstrip().startswith("#"):
            continue
        if len(row) < 2:
            errors.append(f"data/localization/ui_{locale}.csv:{lineno}: row needs a key and a value")
            continue
        key, value = row[0], row[1]
        if key in seen:
            errors.append(f"data/localization/ui_{locale}.csv:{lineno}: duplicate key {key!r}")
        seen.add(key)
        if not value.strip():
            errors.append(f"data/localization/ui_{locale}.csv:{lineno}: {key!r} has an empty value")
        table[key] = value
    return table


locales = read_locales_from_autoload()
if SOURCE_LOCALE not in locales:
    errors.append(f"SUPPORTED_LOCALES must contain the source locale '{SOURCE_LOCALE}'")

tables = {locale: read_table(locale) for locale in locales}
source = tables.get(SOURCE_LOCALE)

if source:
    for locale, table in tables.items():
        if table is None:
            continue
        for key in sorted(set(source) - set(table)):
            errors.append(f"ui_{locale}.csv: missing translation for {key!r}")
        for key in sorted(set(table) - set(source)):
            errors.append(f"ui_{locale}.csv: {key!r} does not exist in ui_{SOURCE_LOCALE}.csv")
        for key in sorted(set(source) & set(table)):
            # A missing %s or an extra one would crash the format call at runtime.
            expected = sorted(FORMAT.findall(source[key]))
            actual = sorted(FORMAT.findall(table[key]))
            if expected != actual:
                errors.append(
                    f"ui_{locale}.csv: {key!r} format specifiers {actual} do not match "
                    f"ui_{SOURCE_LOCALE}.csv {expected}"
                )

for locale, table in tables.items():
    if not table:
        continue
    for key, value in sorted(table.items()):
        rtl = locale != SOURCE_LOCALE
        if ARABIC.search(key):
            errors.append(f"ui_{locale}.csv: key {key!r} is not an English source string")
        if rtl and not ARABIC.search(value):
            errors.append(f"ui_{locale}.csv: {key!r} value is not written in its own script")
        if not rtl and ARABIC.search(value):
            errors.append(f"ui_{locale}.csv: {key!r} value must stay in {SOURCE_LOCALE}")
        if not rtl and value != key and locale == SOURCE_LOCALE:
            warnings.append(f"ui_{locale}.csv: {key!r} value differs from its key (source language)")


def collect_used_keys():
    """Every string the game asks to translate: tr("...") literals and scene `text` properties.

    Both are auto-translated by Godot, so a missing table entry shows up in-game as the raw English
    string with no error anywhere. Catching it here is the only cheap place to do it.

    Returns (translated_keys, untranslated_prose). The first must have a table entry or the game
    shows a missing string. The second is interface copy that is rendered but not routed through
    tr() yet: the menu is assembled in code (UiKit/KitButton) instead of stored as .tscn text, and
    helpers such as _row()/_section() translate whatever they are handed, so a bare tr() scan cannot
    see it. That is a translation backlog, not a broken pipeline, so it is reported, not fatal.
    """
    used = {}
    backlog = {}
    builders = re.compile(
        r"\b(?:_row|_section|_brush|make|caps|label|paragraph|pill|tab)\("
    )
    for path in ROOT.rglob("*.gd"):
        if "addons" in path.parts:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if line.lstrip().startswith("#"):
                continue  # a doc comment mentioning tr() is not a translation call
            place = f"{path.relative_to(ROOT).as_posix()}:{lineno}"
            for match in re.finditer(r'\btr\(\s*"((?:[^"\\]|\\.)*)"\s*\)', line):
                used.setdefault(match.group(1), []).append(place)
            if builders.search(line) and "tr(" not in line:
                for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', line):
                    text = match.group(1)
                    # Prose only: needs a space and letters, so node names and enum-ish tokens
                    # ("RejoinButton", "medium", "primary") are not mistaken for interface copy.
                    if " " in text and re.search(r"[A-Za-z]", text) and not text.startswith("res://"):
                        backlog.setdefault(text, []).append(place)
    for path in ROOT.rglob("*.tscn"):
        if "addons" in path.parts:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            match = re.match(r'^\s*(?:text|placeholder_text)\s*=\s*"(.*)"\s*$', line)
            # "00:00" and "127.0.0.1" are placeholders, not prose, so they are never translated.
            if match and re.search(r"[A-Za-z]", match.group(1)):
                used.setdefault(match.group(1), []).append(f"{path.relative_to(ROOT).as_posix()}:{lineno}")
    return used, backlog


used_keys, backlog = collect_used_keys()

for key, places in sorted(used_keys.items()):
    if key not in source:
        errors.append(f"no entry in ui_{SOURCE_LOCALE}.csv for {key!r} (used at {', '.join(places[:3])})")

# Interface copy that is rendered but not routed through tr() yet. Non-fatal: it is a backlog, and
# it is reported so the gap stays visible instead of being forgotten.
todo = sorted(k for k in backlog if k not in source)
if todo:
    warnings.append(f"{len(todo)} interface string(s) are not routed through tr() yet, e.g. "
                    + "; ".join(repr(k) for k in todo[:4]) + (" …" if len(todo) > 4 else ""))

for w in warnings:
    print("WARN ", w)
for e in errors:
    print("ERROR", e)
print("OK" if not errors else f"{len(errors)} error(s)")
sys.exit(1 if errors else 0)
