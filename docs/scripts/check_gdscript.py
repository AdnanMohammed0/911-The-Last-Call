"""Lightweight structural check for GDScript: indentation, bracket balance, and tabs-vs-spaces.

Not a compiler. It catches the mechanical mistakes that are easy to make when editing blind:
an unclosed bracket, a stray quote, or a line indented with spaces in a tab-indented file.
Run: python docs/scripts/check_gdscript.py [paths...]
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
TARGETS = [ROOT / "autoload/localization.gd", ROOT / "tests/test_localization.gd",
           ROOT / "ui/settings/settings_menu.gd", ROOT / "autoload/game_settings.gd",
           ROOT / "tests/test_net_matrix.gd", ROOT / "autoload/net_manager.gd",
           ROOT / "autoload/lag_compensation.gd"]

errors = []


def strip_code(line):
    """Remove comments and string literals so only real code characters are counted."""
    out, i, quote = [], 0, None
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            i += 1
            continue
        if ch == "#":
            break
        out.append(ch)
        i += 1
    return "".join(out), quote


for path in TARGETS:
    rel = path.relative_to(ROOT).as_posix()
    if not path.exists():
        errors.append(f"{rel}: missing")
        continue
    depth = 0
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, unterminated = strip_code(line)
        if unterminated:
            errors.append(f"{rel}:{lineno}: unterminated string literal")
        body = line.lstrip("\t")
        if body.startswith(" ") and body.strip():
            errors.append(f"{rel}:{lineno}: indented with spaces, file uses tabs")
        depth += code.count("(") - code.count(")")
        depth += code.count("[") - code.count("]")
        depth += code.count("{") - code.count("}")
        if depth < 0:
            errors.append(f"{rel}:{lineno}: more closing than opening brackets")
            depth = 0
    if depth != 0:
        errors.append(f"{rel}: {depth} bracket(s) left unclosed at end of file")

    text = path.read_text(encoding="utf-8")
    for match in re.finditer(r"^func\s+([a-z_0-9]+)\s*\(", text, re.M):
        name = match.group(1)
        if text.count("func %s(" % name) > 1:
            errors.append(f"{rel}: duplicate function {name!r}")

for e in errors:
    print("ERROR", e)
print("OK" if not errors else f"{len(errors)} error(s)")
sys.exit(1 if errors else 0)
