#!/usr/bin/env python3
"""
Generate CHANGELOG.md from git history, and keep a visible block of recent
changes inside README.md.

WHY THIS EXISTS
---------------
The changelog was hand-written once and then never regenerated, so it sat at
0.1.0 while nineteen commits landed - including two renames, four real bug
fixes and a gate suite growing from nothing to fourteen. v0.1.0 was never
tagged either, which is why there was nothing to compare against.

A changelog nobody regenerates is a changelog that lies, quietly. Deriving it
from git means it cannot drift, because git cannot drift.

DESIGN
------
  * Conventional Commit prefixes become sections: feat, fix, docs, refactor,
    perf, security, chore, test, build, ci.
  * Version headings come from git TAGS, not guesses. An untagged history
    lands under "Unreleased", which is the truthful label.
  * Hand-written prose already under a version heading is PRESERVED and the
    generated bullets are appended beneath it. Automation should not delete
    the reasoning a human wrote.
  * The README block sits between two HTML comment markers and is replaced
    wholesale. It shows the five most recent user-visible changes, so someone
    opening the repository root sees that something moved without opening
    the history.
"""
from __future__ import annotations

import re
import subprocess
import sys
from collections import OrderedDict
from datetime import date
from pathlib import Path

ROOT = Path(r"D:\opencode\ashline")
CHANGELOG = ROOT / "CHANGELOG.md"
README = ROOT / "README.md"

BEGIN = "<!-- RECENT-CHANGES:BEGIN -->"
END = "<!-- RECENT-CHANGES:END -->"

CATEGORIES = OrderedDict([
    ("feat", ("Added", "feat")),
    ("fix", ("Fixed", "fix")),
    ("security", ("Security", "security")),
    ("perf", ("Performance", "perf")),
    ("refactor", ("Changed", "refactor")),
    ("docs", ("Documentation", "docs")),
    ("test", ("Tests", "test")),
    ("build", ("Build", "build")),
    ("ci", ("CI", "ci")),
    ("chore", ("Housekeeping", "chore")),
])

REPO_URL = "https://github.com/gh0st4ace/ashline"


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True).stdout


def log_entries(ref: str = "HEAD") -> list[tuple[str, str, str, str]]:
    """Return (sha7, date, subject, body-first-paragraph)."""
    out = git("log", ref, "--pretty=format:%h%x1f%ad%x1f%s%x1f%b%x1e",
              "--date=short")
    entries = []
    for chunk in out.split("\x1e"):
        chunk = chunk.strip("\n")
        if not chunk.strip():
            continue
        parts = chunk.split("\x1f")
        if len(parts) < 3:
            continue
        sha, when, subject = parts[0], parts[1], parts[2]
        body = parts[3].strip() if len(parts) > 3 else ""
        entries.append((sha, when, subject, body))
    return entries


def split_type(subject: str) -> tuple[str, str]:
    m = re.match(r"^(\w+)(?:\([^)]*\))?(!?):\s*(.*)$", subject)
    if m:
        kind = m.group(1).lower()
        scope = m.group(0)
        return kind, m.group(3).strip()
    return "chore", subject.strip()


def classify(subject: str) -> tuple[str, str, str]:
    """-> (category key, heading, text)"""
    kind, text = split_type(subject)
    for key, (heading, _) in CATEGORIES.items():
        if kind == key:
            return key, heading, text
    return "chore", "Housekeeping", text


def is_user_visible(cat: str) -> bool:
    return cat not in {"chore", "ci", "build", "test"}


# ---------------------------------------------------------------------------
def build_changelog() -> str:
    tags = {}
    for t in git("tag", "--sort=-creatordate").split():
        sha = git("rev-list", "-n", "1", t).strip()
        tags[sha] = t
    tag_order = git("tag", "--sort=-creatordate").split()

    entries = log_entries()
    # Group: released versions by tag, then everything newer as Unreleased.
    groups: list[tuple[str, str | None, list]] = []
    seen_tags: set[str] = set()
    head: list = []

    for sha, when, subject, body in entries:
        if sha in tags:
            tag = tags[sha]
            if tag not in seen_tags:
                seen_tags.add(tag)
                groups.append((tag, when, []))
            groups[-1][2].append((sha, when, subject, body))
        else:
            head.append((sha, when, subject, body))

    if head:
        groups.insert(0, ("Unreleased", None, head))

    lines = [
        "# Changelog",
        "",
        "Generated from git history by `tools/gen-changelog.py`.",
        "Hand-written prose under a version heading is preserved; the bullets",
        "beneath it are appended automatically. Do not edit the bullet lists by",
        "hand - they will be overwritten.",
        "",
        "Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),",
        "and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).",
        "",
    ]

    for tag, when, items in groups:
        if tag == "Unreleased":
            lines += ["## Unreleased", "",
                      f"_{len(items)} commit(s) since the last tag_", ""]
        else:
            pretty = tag.lstrip("v")
            heading = f"## [{tag}] - {when}" if when else f"## [{tag}]"
            lines += [heading, ""]

        buckets: dict[str, list[tuple[str, str]]] = {}
        for sha, _w, subject, body in items:
            cat, heading, text = classify(subject)
            buckets.setdefault(heading, []).append((sha, text))

        for cat, (heading, _) in CATEGORIES.items():
            rows = buckets.get(heading)
            if not rows:
                continue
            lines += [f"### {heading}", ""]
            for sha, text in rows:
                link = f"[`{sha}`]({REPO_URL}/commit/{sha})"
                lines.append(f"- {text} {link}")
            lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def merge_existing_prose(new: str, old: str) -> str:
    """Keep the human prose of any version heading the old file already had."""
    if not old:
        return new
    old_sections = dict(re.findall(r"(?m)^## \[?([^\]\n]+)\]?[^\n]*\n(.*?)(?=\n## |\Z)",
                                   old, re.S))
    for version, prose in old_sections.items():
        version = version.strip()
        if version.startswith("["):
            version = version.strip("[]")
        m = re.search(rf"(?m)^## \[?{re.escape(version)}\]?[^\n]*\n(.*?)(?=\n## |\Z)",
                      new, re.S)
        if not m:
            continue
        bullets = [ln for ln in prose.split("\n") if ln.strip().startswith(("- ", "* ", "|", "#", "_"))]
        if not bullets:
            continue
        block = m.group(1).rstrip() + "\n\n" + "\n".join(bullets) + "\n"
        new = new[:m.start(1)] + block + new[m.end(1):]
    return new


# ---------------------------------------------------------------------------
def build_readme_block(limit: int = 6) -> str:
    visible = []
    for sha, when, subject, body in log_entries():
        cat, heading, text = classify(subject)
        if not is_user_visible(cat):
            continue
        visible.append((when, sha, text))
        if len(visible) >= limit:
            break
    if not visible:
        return "_(no user-visible commits yet)_\n"

    out = [BEGIN, "", "## 📌 Recent changes", ""]
    out.append(f"_{len(visible)} most recent user-visible commits · full history in "
               f"[CHANGELOG.md](CHANGELOG.md)_\n")
    out.append("| When | Change | Commit |")
    out.append("|:--|:--|:--:|")
    for when, sha, text in visible:
        short = text if len(text) <= 78 else text[:75] + "…"
        short = short.replace("|", "\\|")
        out.append(f"| `{when}` | {short} | [`{sha}`]({REPO_URL}/commit/{sha}) |")
    out += ["", END]
    return "\n".join(out) + "\n"


def splice_readme(block: str) -> bool:
    if not README.exists():
        return False
    t = README.read_text(encoding="utf-8")
    if BEGIN not in t or END not in t:
        # insert after the first horizontal rule that follows the hero
        m = re.search(r"(?m)^---$", t)
        if not m:
            return False
        t = t[:m.end()] + "\n\n" + block + "\n" + t[m.end():]
    else:
        t = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), block.rstrip(), t, flags=re.S)
    README.write_text(t, encoding="utf-8", newline="\n")
    return True


# ---------------------------------------------------------------------------
def main() -> int:
    dry = "--dry-run" in sys.argv
    old = CHANGELOG.read_text(encoding="utf-8") if CHANGELOG.exists() else ""
    new = merge_existing_prose(build_changelog(), old)

    if not dry:
        CHANGELOG.write_text(new, encoding="utf-8", newline="\n")

    spliced = splice_readme(build_readme_block())
    if dry:
        print(new[:1500])
        print("...")
        print(f"\nREADME block spliced: {spliced}  (dry run, nothing written)")
    else:
        print(f"CHANGELOG.md: {len(new.splitlines())} lines")
        print(f"README recent-changes block: {'updated' if spliced else 'skipped (no insertion point)'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())