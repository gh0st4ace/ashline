#!/usr/bin/env python3
"""Neutralize image links in shipped markdown whose assets are not redistributed.

docs/agentic-security.source.md is the full-length source guide. Its seven
illustrations were never copied, so every `![alt](./assets/...)` is a dead
link. A dead link in a repository is worse than an absent image, so each one
becomes an explicit note saying what the illustration showed.

Kept separate from sanitize-and-copy.py because this is a content fix, not a
path fix.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DESCRIPTIONS = {
    "attack-chain.png":
        "attack chain diagram: initial access, execution, persistence, "
        "privilege escalation, lateral movement, exfiltration",
    "badrudi-exploit.mp4":
        "screen recording of the referenced published exploit being reproduced "
        "against a deliberately vulnerable target",
    "sandboxing-comparison.png":
        "sandboxing comparison: process, container, and VM isolation boundaries "
        "and what each one does not stop",
    "sandboxing-brain.png":
        "diagram of the sandbox decision point - what the agent is allowed to "
        "reach given its current identity and tool set",
    "sanitization.png":
        "where untrusted content enters and where it is sanitized before "
        "reaching the model",
    "observability.png":
        "observability chain: tool invocation, decision, action, audit record",
    "ghostyy-overflow.jpeg":
        "screenshot from the referenced overflow write-up",
}

changed = 0
for md in ROOT.rglob("*.md"):
    if ".git" in md.parts:
        continue
    text = original = md.read_text(encoding="utf-8")

    def sub(m: re.Match) -> str:
        alt, path = m.group(1), m.group(2)
        name = path.rsplit("/", 1)[-1]
        desc = DESCRIPTIONS.get(name, alt or name)
        return (f"*[Illustration not redistributed: {desc}. "
                f"The upstream source is linked in the References section.]*")

    text = re.sub(r"!\[([^\]]*)\]\(([^)]+\.(?:png|jpe?g|gif|svg|mp4|webm))\)", sub, text)

    # Relative markdown links to assets that do not exist -> plain note.
    text = re.sub(
        r"\[([^\]]+)\]\((\./?assets/[^)]+)\)",
        lambda m: f"*{m.group(1)}* (asset not redistributed)",
        text,
    )

    if text != original:
        md.write_text(text, encoding="utf-8", newline="\n")
        changed += 1
        print(f"  neutralized asset links in {md.relative_to(ROOT)}")

print(f"{changed} file(s) changed")