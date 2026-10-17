#!/usr/bin/env python3
"""Scan the tree for stray control characters.

Several edits were applied through PowerShell double-quoted here-strings
(@" ... "@), where a backtick is an ESCAPE character. A markdown code span
written as `awesome` inside such a string does not produce a backtick plus
"awesome" - it produces BEL (U+0007) plus "wesome". That silently corrupted
a README table row.

This finds any character below 0x20 other than tab, LF and CR, so the class of
damage is visible instead of assumed absent.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"D:\opencode\ashline")
SUFFIXES = {".md", ".json", ".jsonc", ".ps1", ".py", ".cmd", ".template",
            ".txt", ".html", ".c", ".bat"}

CONTROL_NAMES = {
    0x00: "NUL", 0x07: "BEL", 0x08: "BS", 0x0B: "VT", 0x0C: "FF",
    0x1B: "ESC", 0x7F: "DEL",
}

total = 0
for f in sorted(ROOT.rglob("*")):
    if not f.is_file() or ".git" in f.parts:
        continue
    if f.suffix.lower() not in SUFFIXES:
        continue
    raw = f.read_bytes()
    try:
        t = raw[3:].decode("utf-8") if raw.startswith(b"\xef\xbb\xbf") else raw.decode("utf-8")
    except (UnicodeDecodeError, PermissionError):
        continue
    for i, ch in enumerate(t):
        o = ord(ch)
        if o < 32 and ch not in "\n\r\t":
            line = t[:i].count("\n") + 1
            name = CONTROL_NAMES.get(o, "ctrl")
            ctx = " ".join(t[max(0, i - 48): i + 48].split())
            print(f"  {f.relative_to(ROOT)}:{line}  U+{o:04X} {name}")
            print(f"      ...{ctx}...")
            total += 1
    # also catch the zero-width family, which hides in text just as well
    for m in re.finditer("[\u200b\u200c\u200d\ufeff\u00ad]", t):
        line = t[: m.start()].count("\n") + 1
        ctx = " ".join(t[max(0, m.start() - 48): m.start() + 48].split())
        print(f"  {f.relative_to(ROOT)}:{line}  zero-width U+{ord(m.group()):04X}")
        print(f"      ...{ctx}...")
        total += 1

print(f"\n  total: {total}")
if total:
    print("  DAMAGED - these are invisible in most viewers but corrupt the text")
else:
    print("  clean")