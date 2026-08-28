#!/usr/bin/env python3
"""Regenerate editor.tokenColorCustomizations for the active Catppuccin theme.

THE PRINCIPLE (two rules, every language)

    italic  = the language's own vocabulary
              comment / keyword / storage
              storage.type     -> const let var function class def fn
              storage.modifier -> static final public private abstract async
    upright = names the programmer chose
              functions, classes, types, enums, parameters, variables,
              and library symbols under support.*

TextMate scope names are cross-language, so those roots hold everywhere
without naming a single language. Sub-scopes with no explicit fontStyle
inherit from their root, which is what makes `storage.modifier.final.java`,
`keyword.declaration.dart` and `storage.type.struct.rust` all come out
italic for free.

TWO PRINCIPLED EXCEPTIONS

    keyword.operator      -> upright. Symbolic operators (= + => ?.) are
                             punctuation, not vocabulary. The word operators
                             underneath (.word/.new/.expression: and, or, in,
                             is, new, typeof, await) go back to italic.
    storage.type.primitive-> upright, so `int` in Java reads like `string`
                             in TS. Types are upright, no matter which family
                             the grammar files them under.

WHY THERE IS STILL A LIST

VS Code picks the rule whose selector is most specific for the token, so a
theme rule on `support.function.macro.julia` beats a customisation on
`support.function`. The undo set therefore has to match the theme's own
specificity. It is DERIVED here rather than hand-written: the script reads the
theme, finds every scope it italicises, and keeps only those that contradict
the principle. Re-run after a theme update; the list re-derives itself.

    python3 config/Code/generate-italics.py [--dry-run]
"""

import json
import re
import sys
from pathlib import Path

SETTINGS = Path.home() / ".dotfiles/config/Code/User/settings.json"
EXT_GLOB = ".vscode/extensions/catppuccin.catppuccin-vsc-*/themes"

# Scope roots whose tokens are language vocabulary -> italic.
ITALIC_ROOTS = ("comment", "keyword", "storage", "markup.italic")

# Principled exceptions to the roots, applied at higher specificity.
UPRIGHT_EXCEPTIONS = ["keyword.operator", "storage.type.primitive"]
ITALIC_EXCEPTIONS = [
    "keyword.operator.word",
    "keyword.operator.new",
    "keyword.operator.expression",
]

# Scopes filed under a vocabulary root that actually name something.
NAME_LIKE = {"keyword.other.definition.ini"}      # INI/TOML keys, not keywords

DOC_TAG_MARKERS = ("jsdoc", "javadoc", "phpdoc", "doxygen")


def vocabulary(selector: str) -> bool:
    """True if this scope is language vocabulary and belongs in italic.

    Three carve-outs, all principled rather than per-language:
      - doc tags inside comments (@param, @return) keep the theme's
        deliberate upright-inside-italic contrast;
      - symbolic operators (= + => :: <-) are punctuation, not vocabulary,
        while the word forms (and, or, in, is, new, typeof) are;
      - a handful of scopes name things despite sitting under keyword.*.
    """
    parts = selector.split()               # descendant selector
    key = parts[-1]                        # innermost scope decides

    if any(m in key for m in DOC_TAG_MARKERS):
        return False
    if ".operator" in key and not any(w in key for w in (".word", ".new", ".expression")):
        return False
    if key in NAME_LIKE:
        return False

    # Nested inside a comment: a keyword there is a doc tag (@param, @return),
    # which the theme deliberately leaves upright for contrast against the
    # italic comment around it. Anything else is comment prose - a shebang
    # line, its punctuation - and stays italic like the rest of the comment.
    if any(p.startswith("comment") for p in parts[:-1]) or "shebang" in selector:
        return not key.startswith(("keyword", "storage"))

    if "comment" in key:
        return True
    return any(key == r or key.startswith(r + ".") for r in ITALIC_ROOTS)


def scopes_of(rule) -> list:
    sc = rule.get("scope", "")
    return sc if isinstance(sc, list) else [s.strip() for s in sc.split(",") if s.strip()]


def derive(theme_path: Path):
    """Read the theme and find both directions in which it fights the principle.

    upright: scopes it italicises that name things.
    italic : scopes it flattens to upright that are vocabulary. This half is
             what makes `static`, `final` and `const` work - the theme pins
             storage.type and storage.modifier to "" at specificity 2, which
             outranks a customisation on the `storage` root at specificity 1.
    """
    rules = json.loads(theme_path.read_text())["tokenColors"]
    upright, italic = [], []
    for rule in rules:
        fs = rule.get("settings", {}).get("fontStyle")
        if fs is None:                                   # inherits; never competes
            continue
        is_italic = "italic" in str(fs).lower()
        for sel in scopes_of(rule):
            if is_italic and not vocabulary(sel) and sel not in upright:
                upright.append(sel)
            elif not is_italic and vocabulary(sel) and sel not in italic:
                italic.append(sel)
    italic = [s for s in italic if s not in UPRIGHT_EXCEPTIONS + ITALIC_EXCEPTIONS]
    return upright, italic


def build(theme_name: str, upright: list, italic: list) -> dict:
    return {
        f"[{theme_name}]": {
            "textMateRules": [
                {
                    "name": "italic: language vocabulary (comments, keywords, storage)",
                    "scope": list(ITALIC_ROOTS) + ["punctuation.definition.comment"],
                    "settings": {"fontStyle": "italic"},
                },
                {
                    "name": "italic: vocabulary the theme flattens (derived from theme)",
                    "scope": italic,
                    "settings": {"fontStyle": "italic"},
                },
                {
                    "name": "upright: identifiers the theme italicises (derived from theme)",
                    "scope": upright,
                    "settings": {"fontStyle": ""},
                },
                {
                    "name": "upright: symbolic operators and primitive types",
                    "scope": UPRIGHT_EXCEPTIONS,
                    "settings": {"fontStyle": ""},
                },
                {
                    "name": "italic: word operators (and, or, in, is, new, typeof, await)",
                    "scope": ITALIC_EXCEPTIONS,
                    "settings": {"fontStyle": "italic"},
                },
            ]
        }
    }


def splice(text: str, key: str, value: dict) -> str:
    """Replace one top-level key's object in place, leaving the rest byte-identical."""
    needle = f'  "{key}": {{'
    start = text.index(needle)
    i = text.index("{", start)
    depth, j = 0, i
    while True:                                   # brace-match, no strings contain braces here
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    body = json.dumps(value, indent=2)
    body = "\n".join(("  " + ln) if ln.strip() else ln for ln in body.splitlines()).lstrip()
    return text[:i] + body + text[j + 1:]


def main() -> int:
    themes = sorted(Path.home().glob(EXT_GLOB))
    if not themes:
        print("catppuccin theme not found", file=sys.stderr)
        return 1

    text = SETTINGS.read_text()
    theme_name = json.loads(text)["workbench.colorTheme"]           # e.g. "Catppuccin Mocha"
    flavour = theme_name.split()[-1].lower() + ".json"              # -> mocha.json
    theme_path = themes[-1] / flavour
    if not theme_path.exists():
        print(f"no theme file at {theme_path}", file=sys.stderr)
        return 1

    upright, italic = derive(theme_path)
    updated = splice(text, "editor.tokenColorCustomizations",
                     build(theme_name, upright, italic))
    json.loads(updated)                                             # fail loudly on bad JSON

    print(f"theme      {theme_name}  ({theme_path.name})")
    print(f"italic     {len(ITALIC_ROOTS) + 1} roots + {len(ITALIC_EXCEPTIONS)} exceptions "
          f"+ {len(italic)} derived")
    print(f"upright    {len(UPRIGHT_EXCEPTIONS)} exceptions + {len(upright)} derived")

    if "--dry-run" in sys.argv:
        print("\n(dry run, not written)")
        return 0
    SETTINGS.write_text(updated)
    print(f"\nwrote {SETTINGS}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
