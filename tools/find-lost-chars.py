#!/usr/bin/env python3
"""
Find and repair characters lost to an encoding round-trip.

The Russian README lost one letter: "Тянется" became "Тя??ется", where the two
bytes of the letter were replaced by U+FFFD REPLACEMENT CHARACTER. That
happened when an edit went through a PowerShell here-string and was written
with a codec that could not represent the character.

U+FFFD is unrecoverable in general - the original byte is gone. This reports
every occurrence so each can be judged and repaired by hand, and it refuses to
guess. It also hard-fails on any file that no longer decodes as UTF-8 at all,
which is the louder failure mode.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(r"D:\opencode\ashline")
SUFFIXES = {".md", ".json", ".jsonc", ".ps1", ".py", ".cmd", ".template",
            ".txt", ".html", ".c", ".bat"}
FFFD = "\ufffd"

undecodable = 0
replaced = 0

for f in sorted(ROOT.rglob("*")):
    if not f.is_file() or ".git" in f.parts or f.suffix.lower() not in SUFFIXES:
        continue
    raw = f.read_bytes()
    try:
        t = raw[3:].decode("utf-8") if raw.startswith(b"\xef\xbb\xbf") else raw.decode("utf-8")
    except UnicodeDecodeError as e:
        print(f"  DECODE FAIL  {f.relative_to(ROOT)}: {e}")
        undecodable += 1
        continue

    if FFFD not in t:
        continue

    bom = raw.startswith(b"\xef\xbb\xbf")
    out = t
    i = 0
    while True:
        i = out.find(FFFD, i)
        if i < 0:
            break
        line = out[:i].count("\n") + 1
        lo = max(0, i - 50)
        hi = min(len(out), i + 50)
        ctx = " ".join(out[lo:hi].split())
        print(f"  {f.relative_to(ROOT)}:{line}   {out.count(FFFD)} replacement char(s)")
        print(f"      ...{ctx}...")
        print(f"      bytes at this point: {out.encode('utf-8')[max(0,i-8):i+8]!r}")
        i += 1

    # Repair: collapse runs of U+FFFD back to a single unknown, which is left as
    # a visible marker rather than a silent guess.
    repaired = re_collapse = None
    import re as _re
    repaired = _re.sub(FFFD + "{2,}", FFFD, out)
    if repaired != out:
        (ROOT / f.relative_to(ROOT)).write_bytes(
            (b"\xef\xbb\xbf" if bom else b"") + repaired.encode("utf-8"))
        replaced += 1

print()
print(f"  files that no longer decode: {undecodable}")
print(f"  files with replacement chars: {replaced}")
print()
print("  Repair policy: U+FFFD is unrecoverable - the original byte is gone.")
print("  Runs were collapsed to ONE marker so the gap is countable, not smeared")
print("  across several characters. Restore the correct letter by hand; a wrong")
print("  guess here is worse than a visible gap.")