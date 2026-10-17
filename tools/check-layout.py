#!/usr/bin/env python3
"""
Check that centered <div> blocks contain only inline content.

GitHub's `align="center"` is inherited text-align, and text-align does not
apply to block-level boxes. A fenced code block, table, callout or <details>
inside a centered div therefore renders at the left margin while everything
around it sits centred - which reads as a layout mistake even though the markup
is valid. Headings are the exception: GitHub renders them centred inside the
div, which is why the H1 and H3 above stay put.

This also reports the gate-count badge so it can be compared against the real
number, because that badge went stale when a gate was added and nothing
noticed.
"""
from __future__ import annotations

import re
from pathlib import Path

p = Path(r"D:\opencode\ashline\README.md")
t = p.read_text(encoding="utf-8")

print("=== block elements inside centered divs ===")
issues = 0
for m in re.finditer(r'<div align="center">(.*?)</div>', t, re.S):
    body = m.group(1)
    line = t[: m.start()].count("\n") + 1
    bad = []
    if "```" in body:
        bad.append("fenced code block")
    if re.search(r"(?m)^\s*\|", body):
        bad.append("table")
    if re.search(r"(?m)^\s*>", body):
        bad.append("blockquote/callout")
    if re.search(r"(?m)^\s*---+\s*$", body):
        bad.append("horizontal rule")
    if "<details>" in body:
        bad.append("details block")
    print(f"  div at line {line}: {', '.join(bad) if bad else 'inline only - centres correctly'}")
    issues += len(bad)

print()
print("=== badge vs reality ===")
badge = re.search(r"release_gates-([0-9/]+)-", t)
if badge:
    claimed = badge.group(1)
    gate_src = Path(r"D:\opencode\ashline\tools\gate.py").read_text(encoding="utf-8")
    defined = len(set(re.findall(r"(?m)^def (gate_\w+)\(", gate_src)))
    called = len(set(re.findall(r"(?m)^    (gate_\w+)\(\)", gate_src)))
    print(f"  badge claims: {claimed}")
    print(f"  gates defined: {defined}   called: {called}")
    if str(defined) not in claimed.split("/"):
        print(f"  STALE - should read {called}/{defined}")
else:
    print("  no gate-count badge found")

raise SystemExit(1 if issues else 0)