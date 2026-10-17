#!/usr/bin/env python3
"""
Fix the encoding of .ps1 files that genuinely contain non-ASCII.

Windows PowerShell 5.1 decides a script's encoding from its BOM:
  * BOM present  -> read as UTF-8, non-ASCII is correct
  * BOM absent   -> read as ANSI (the OEM code page), non-ASCII is MOJIBAKE

Worse than mojibake: a mangled byte can land on `"` and terminate a string
literal early, which turns a valid script into a parse error. That is exactly
what happened to scripts/update-ecc.ps1, whose `throw` messages are in Russian.

So the correct rule is NOT "all .ps1 must be ASCII". It is:

  non-ASCII present  -> MUST carry a UTF-8 BOM
  pure ASCII         -> MUST NOT carry a BOM (BOM breaks YAML frontmatter and
                        confuses some tooling)

An earlier gate asserted ASCII unconditionally and was wrong. This fixes the
files and corrects the rule.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOM = b"\xef\xbb\xbf"

fixed: list[str] = []
problems: list[str] = []

for ps1 in sorted(ROOT.rglob("*.ps1")):
    if ".git" in ps1.parts:
        continue
    raw = ps1.read_bytes()
    has_bom = raw.startswith(BOM)
    body = raw[len(BOM):] if has_bom else raw
    non_ascii = any(b > 127 for b in body)

    if non_ascii and not has_bom:
        # Validate it is really UTF-8 before committing to a BOM, otherwise we
        # would be blessing bytes that were already corrupted upstream.
        try:
            body.decode("utf-8")
        except UnicodeDecodeError as e:
            problems.append(f"{ps1.relative_to(ROOT)}: non-ASCII but not valid UTF-8 ({e}) - "
                            f"source is damaged, needs manual repair")
            continue
        ps1.write_bytes(BOM + body)
        fixed.append(f"{ps1.relative_to(ROOT)}: added UTF-8 BOM (contains non-ASCII)")
    elif not non_ascii and has_bom:
        ps1.write_bytes(body)
        fixed.append(f"{ps1.relative_to(ROOT)}: removed UTF-8 BOM (pure ASCII)")

for f in fixed:
    print(f"  {f}")
for p in problems:
    print(f"  PROBLEM  {p}")

if problems:
    sys.exit(1)
print(f"{len(fixed)} file(s) adjusted")