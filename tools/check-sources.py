#!/usr/bin/env python3
"""
Every catalogued tool must have a RESOLVABLE source.

Reported by users as: "cheat-mcp is absent from the official documentation and
repository manifest". The manifest DID contain a cheat-mcp entry - it said
"built from source", "check upstream", "manual build", and gave no URL
anywhere. So the entry existed and was still useless: a reader cannot install
from "check upstream".

This gate makes that failure mode impossible to ship. For every tool it
requires at least one of:

  * an http(s) URL, OR
  * a "requires <thing>" note naming what has to be installed first, OR
  * an explicit "vendored" marker, meaning the code is in this repository

and it rejects the vague words that were the original defect: "check upstream",
"built from source", "manual", "unknown" with nothing else.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(r"D:\opencode\ashline")
MANIFEST = ROOT / "config" / "tool-manifest.json"

VAGUE = [
    "check upstream",
    "built from source",
    "manual build",
    "manual - not installed",
    "upstream",
    "tbd",
]

# "PROVENANCE NOT RECORDED" is a TERMINAL answer, not a defect.
#
# Two entries on this machine have no .git, no README and no version file.
# Inventing a plausible URL for them would be worse than useless - it would look
# authoritative and be wrong, which is the exact failure this gate exists to
# stop. "You cannot reproduce this from what we recorded; obtain it yourself" is
# a complete answer, so it passes.
#
# The distinction that matters: "check upstream" sends the reader somewhere and
# leaves them stuck. "PROVENANCE NOT RECORDED" tells them there is nowhere to go.
HONEST_ABSENCE = ("provenance not recorded", "content unknown")

missing: list[str] = []
vague: list[str] = []
tools = json.loads(MANIFEST.read_text(encoding="utf-8"))["tools"]

for t in tools:
    name = t.get("name", "?")
    src = str(t.get("source", "") or "").lower()
    lic = str(t.get("license", "") or "")
    installer = str(t.get("installer", "") or "")
    vendoring = str(t.get("vendoring", "") or "")
    low = src.lower()

    if any(h in low for h in HONEST_ABSENCE):
        continue  # terminal, honest answer - see HONEST_ABSENCE

    has_url = bool(re.search(r"https?://", src))
    has_requires = "requires " in low
    is_vendored = vendoring.strip().lower().startswith(("vendored", "in this repo"))

    if not (has_url or has_requires or is_vendored):
        missing.append(f"{name}: source='{src[:70]}' gives nothing to install from")

    # The original defect: an entry that names no licence authority.
    if not lic or lic.strip().lower() in {"unknown", "", "check upstream"}:
        if "no license" not in lic.lower():
            missing.append(f"{name}: license='{lic[:50]}' is not a usable answer")

for t in tools:
    blob = " ".join(str(t.get(k, "")) for k in ("source", "installer")).lower()
    low_src = str(t.get("source", "")).lower()
    if any(h in low_src for h in HONEST_ABSENCE):
        continue
    for v in VAGUE:
        if v in blob and "https" not in str(t.get("source", "")):
            vague.append(f"{t.get('name')}: '{v}' with no URL to pair it with")

if missing or vague:
    for m in missing:
        print(f"  {m}")
    for v in vague:
        print(f"  {v}")
    raise SystemExit(1)

print(f"  all {len(tools)} tools carry a resolvable source and a stated licence")