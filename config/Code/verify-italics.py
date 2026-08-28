#!/usr/bin/env python3
"""Check the generated italic rules resolve as intended, across languages.

Simulates VS Code's TextMate resolution: theme rules and customisations
compete in one pool, the most specific selector matching the token's scope
stack wins, ties go to the later rule, and a rule with no fontStyle does not
compete at all (it inherits from its root). Run after generate-italics.py.

    python3 config/Code/verify-italics.py     # exits non-zero on any failure
"""
import json, os, sys
from pathlib import Path
SETTINGS = Path.home() / ".dotfiles/config/Code/User/settings.json"
cfg = json.loads(SETTINGS.read_text())
THEME_NAME = cfg["workbench.colorTheme"]
flavour = THEME_NAME.split()[-1].lower() + ".json"
theme_dir = sorted(Path.home().glob(".vscode/extensions/catppuccin.catppuccin-vsc-*/themes"))[-1]
theme = json.loads((theme_dir / flavour).read_text())["tokenColors"]
custom = cfg["editor.tokenColorCustomizations"][f"[{THEME_NAME}]"]["textMateRules"]
def norm(r):
    sc=r.get("scope",""); return (sc if isinstance(sc,list) else [x.strip() for x in sc.split(",")],
                                  r.get("settings",{}).get("fontStyle"))
def spec(sel,stack):
    parts=sel.split()
    if not all(any(t==p or t.startswith(p+".") for t in stack) for p in parts): return None
    return max(len(p.split(".")) for p in parts)
def resolve(stack):
    best=(-1,-1,None)
    for o,(scopes,fs) in enumerate(list(map(norm,theme))+list(map(norm,custom))):
        if fs is None: continue
        for sel in scopes:
            if not sel: continue
            s=spec(sel,stack)
            if s is not None and (s,o)>(best[0],best[1]): best=(s,o,fs)
    return "italic" if best[2]=="italic" else "upright"
C=[("VOCABULARY -> ITALIC","italic",[
 ("java    static",["source.java","storage.modifier.java"]),
 ("java    final",["source.java","storage.modifier.java"]),
 ("dart    const",["source.dart","keyword.declaration.dart"]),
 ("dart    final",["source.dart","keyword.declaration.dart"]),
 ("dart    static",["source.dart","storage.modifier.dart"]),
 ("ts      const",["source.ts","storage.type.ts"]),
 ("ts      static",["source.ts","storage.modifier.ts"]),
 ("ts      readonly",["source.ts","storage.modifier.ts"]),
 ("ts      async",["source.ts","storage.modifier.async.ts"]),
 ("ts      function",["source.ts","storage.type.function.ts"]),
 ("ts      class",["source.ts","storage.type.class.ts"]),
 ("ts      return",["source.ts","keyword.control.flow.ts"]),
 ("ts      import",["source.ts","keyword.control.import.ts"]),
 ("python  def",["source.python","storage.type.function.python"]),
 ("python  class",["source.python","storage.type.class.python"]),
 ("rust    struct",["source.rust","storage.type.struct.rust"]),
 ("rust    pub",["source.rust","storage.modifier.rust"]),
 ("rust    impl",["source.rust","storage.type.impl.rust"]),
 ("go      func",["source.go","keyword.function.go"]),
 ("go      var",["source.go","keyword.var.go"]),
 ("c#      static",["source.cs","storage.modifier.cs"]),
 ("kotlin  val",["source.kotlin","storage.type.kotlin"]),
 ("swift   let",["source.swift","keyword.declaration.swift"]),
 ("cpp     const",["source.cpp","storage.modifier.specifier.const.cpp"]),
 ("word op typeof",["source.ts","keyword.operator.expression.typeof.ts"]),
 ("word op in",["source.python","keyword.operator.word.python"]),
 ("comment //",["source.java","comment.line.double-slash.java"]),
 ("markdown *emph*",["text.html.markdown","markup.italic.markdown"]),
 ("shell   #!/bin/sh",["source.shell","comment.line.shebang.shell"]),
 ("shell   shebang punc",["source.shell","comment.line.shebang","punctuation.definition.comment"]),
]),("NAMES / SYMBOLS -> UPRIGHT","upright",[
 ("fn name fetchUser",["source.ts","entity.name.function.ts"]),
 ("class   UserStore",["source.ts","entity.name.class.ts"]),
 ("type    User",["source.ts","entity.name.type.ts"]),
 ("enum    Status",["source.ts","entity.name.enum.ts"]),
 ("param   id",["source.ts","variable.parameter.ts"]),
 ("ts prim string",["source.ts","support.type.primitive.ts"]),
 ("java prim int",["source.java","storage.type.primitive.java"]),
 ("method  .get()",["source.ts","meta.function-call.method.ts"]),
 ("operator =>",["source.ts","keyword.operator.assignment.ts"]),
 ("operator +",["source.ts","keyword.operator.arithmetic.ts"]),
 ("hs operator ::",["source.haskell","keyword.operator.double-colon.haskell"]),
 ("py self",["source.python","variable.language.special.self.python"]),
 ("py decorator",["source.python","entity.name.function.decorator.python"]),
 ("rust attr #[..]",["source.rust","meta.attribute.rust"]),
 ("rust trait name",["source.rust","entity.name.trait.rust"]),
 ("julia macro",["source.julia","support.function.macro.julia"]),
 ("jsdoc @param",["source.js","comment.block.documentation.js","storage.type.class.jsdoc"]),
 ("ini key",["source.ini","keyword.other.definition.ini"]),
])]
fails=0; total=0
for title,want,cases in C:
    print(f"\n{title}\n"+"-"*46)
    for label,stack in cases:
        got=resolve(stack); ok=got==want; fails+=not ok; total+=1
        print(f"  {label:<20} {got:<9} {'OK' if ok else '<<< FAIL'}")
print(f"\n{'ALL '+str(total)+' PASS' if not fails else f'{fails}/{total} FAILED'}")
sys.exit(1 if fails else 0)
