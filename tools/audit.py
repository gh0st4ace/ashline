#!/usr/bin/env python3
"""
Deep audit: everything the release gate does not check.

The gate answers "is this publishable". This answers "is anything wrong".

TWO LESSONS BAKED IN, both learned from this audit reporting things that were
fine:

  1. Pipe counting must be escape-aware. Five tables were flagged as ragged
     because their cells contain an ESCAPED PIPE inside a code span, and a
     naive count of the pipe character sees six columns where there are three.
  2. Some paths are SUPPOSED to be absent. A tool that reports those forever
     gets ignored, and then it reports nothing at all. So absent-by-design is
     declared explicitly below rather than argued about each run.
"""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(r"D:\opencode\ashline")
FINDINGS: list[tuple[str, str]] = []

# Paths that must NOT exist, each for a stated reason.
ABSENT_BY_DESIGN = {
    "knowledge/kernel-sec/knowledge/lol_drivers.json":
        "33 MB feed cache. A dependency, refreshed by the documented curl. "
        "gitignored on purpose.",
    "scripts/paths.cmd":
        "Written by install.ps1 with resolved absolute paths. Correctly not shipped.",
    "docs/HANDOFF.md":
        "Lives in a different project. Cited in AGENTS.md as an example of a "
        "file too large to read, not as a repo path.",
}

# Files copied verbatim from upstream; their links resolve there, not here.
UPSTREAM_COPIES = {
    "config/hooks.README.md",
    "config/memory-persistence.README.md",
    "config/hooks.metadata.json",
    "config/plugins.index.ts",
    "config/cli.json",
    "config/dcp.jsonc",
    "config/magic-context.jsonc",
    "config/tui-preferences.jsonc",
    "config/mcp-servers.json.template",
}


def note(kind: str, msg: str) -> None:
    FINDINGS.append((kind, msg))


def read(p: Path) -> str:
    raw = p.read_bytes()
    return raw[3:].decode("utf-8") if raw.startswith(b"\xef\xbb\xbf") else raw.decode("utf-8")


def cells(line: str) -> int:
    """Count table cells, honouring backslash-escaped pipes."""
    return len(re.findall(r"(?<!\\)\|", line)) - 1


def md_files() -> list[Path]:
    return sorted(p for p in ROOT.rglob("*.md") if ".git" not in p.parts)


# ---------------------------------------------------------------------------
def check_links() -> None:
    for f in md_files():
        rel_f = str(f.relative_to(ROOT)).replace("\\", "/")
        # Files copied verbatim from upstream point at paths inside THEIR
        # repository. Checking those here only produces noise, so they are
        # skipped whole - the banner added to each says why.
        if rel_f in UPSTREAM_COPIES:
            continue
        text = read(f)
        for m in re.finditer(r"\[[^\]]*\]\((?!https?://|#|mailto:)([^)\s]+)\)", text):
            target = m.group(1).split("#")[0]
            if not target:
                continue
            if target.startswith("/"):
                route = target.lstrip("/")
                if not (ROOT / "docs" / f"{route}.md").exists():
                    note("link", f"{rel_f} -> site route /{route} has no page")
                continue
            if not (f.parent / target).resolve().exists():
                note("link", f"{rel_f} -> {target} does not exist")

    for f in md_files():
        rel_f = str(f.relative_to(ROOT)).replace("\\", "/")
        if rel_f in UPSTREAM_COPIES:
            continue
        text = read(f)
        for m in re.finditer(r"`((?:scripts|docs|config|tools|knowledge|agents|examples)/[A-Za-z0-9_.\-/]+)`", text):
            p = m.group(1)
            if (ROOT / p).exists() or p in ABSENT_BY_DESIGN:
                continue
            note("path", f"{rel_f} references `{p}` which is absent and is not declared absent-by-design")


def check_tables() -> None:
    for f in md_files():
        rel_f = str(f.relative_to(ROOT)).replace("\\", "/")
        lines = read(f).split("\n")
        i = 0
        while i < len(lines):
            if lines[i].strip().startswith("|") and i + 1 < len(lines) and \
               re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
                header = cells(lines[i])
                j = i + 2
                while j < len(lines) and lines[j].strip().startswith("|"):
                    if cells(lines[j]) != header:
                        note("table", f"{rel_f}:{j+1} has {cells(lines[j])} cells, header has {header}")
                    j += 1
                i = j
            else:
                i += 1


def check_html() -> None:
    for f in md_files():
        text = read(f)
        o = Counter(re.findall(r"<(\w+)[^>]*?>", text))
        c = Counter(re.findall(r"</(\w+)>", text))
        for tag in ("div", "p", "details", "summary", "table", "tr", "td", "a"):
            if o[tag] != c[tag]:
                note("html", f"{f.relative_to(ROOT)}: <{tag}> opens {o[tag]}, closes {c[tag]}")


def check_anchors() -> None:
    for f in md_files():
        text = read(f)
        slugs = []
        for m in re.finditer(r"(?m)^#{1,6}\s+(.+)$", text):
            s = re.sub(r"[^\w\s-]", "", m.group(1).lower())
            slugs.append(re.sub(r"[\s_]+", "-", s).strip("-"))
        for s, n in Counter(slugs).items():
            if n > 1:
                note("anchor", f"{f.relative_to(ROOT)}: heading '{s}' appears {n} times")


def check_lossy() -> None:
    """Characters that a failed encoding round-trip leaves behind."""
    for f in ROOT.rglob("*"):
        if not f.is_file() or ".git" in f.parts:
            continue
        if f.suffix.lower() not in {".md", ".json", ".jsonc", ".ps1", ".py",
                                    ".cmd", ".template", ".txt", ".html", ".c", ".bat"}:
            continue
        raw = f.read_bytes()
        try:
            t = raw[3:].decode("utf-8") if raw.startswith(b"\xef\xbb\xbf") else raw.decode("utf-8")
        except UnicodeDecodeError as e:
            note("encoding", f"{f.relative_to(ROOT)}: does not decode as UTF-8 - {e}")
            continue
        rel = str(f.relative_to(ROOT)).replace("\\", "/")
        # tools/scan-control-chars.py and audit.py contain the replacement char
        # DELIBERATELY, as a pattern to search for.
        if rel in {"tools/scan-control-chars.py", "tools/find-lost-chars.py", "tools/audit.py"}:
            t = t.replace("\ufffd", "")
        if "\ufffd" in t:
            note("lossy", f"{rel}: contains U+FFFD - a character was lost to an encoding round-trip")
        for m in re.finditer(r"(?i)\w*�\w*", t):
            pass
    # explicit mojibake signatures
    SIG = re.compile(r"(?:Ã[\x80-\xbf]|â€[\x80-\xbf]|Ð[\x80-\xbf]{1}|Ñ[\x80-\xbf])")
    for f in md_files():
        t = read(f)
        for m in SIG.finditer(t):
            line = t[: m.start()].count("\n") + 1
            note("mojibake", f"{f.relative_to(ROOT)}:{line}  {m.group()!r}")


def check_numbers() -> None:
    scripts = (len(list((ROOT / "scripts").glob("*.ps1")))
               + len(list((ROOT / "scripts").glob("*.py")))
               + len(list((ROOT / "scripts").glob("*.cmd"))))
    print(f"  scripts on disk: {scripts}")
    # claims that unambiguously mean "the shipped scripts"
    claims: dict[str, list[str]] = {}
    for f in md_files():
        rel = str(f.relative_to(ROOT)).replace("\\", "/")
        t = read(f)
        for m in re.finditer(r"\|\s*\*\*[^*]*scripts\*\*\s*\|\s*(\d+)", t, re.I):
            claims.setdefault(m.group(1), []).append(rel)
        for m in re.finditer(r"\| \*\*Scripts\*\* \| (\d+)", t):
            claims.setdefault(m.group(1), []).append(rel)
    if len(claims) > 1:
        note("number", f"the shipped-script count is stated as {sorted(claims)} "
                       f"but the filesystem has {scripts}")
    for n, where in sorted(claims.items()):
        print(f"    claimed {n:<4} in {', '.join(sorted(set(where)))}")


def check_templates() -> None:
    for f in sorted((ROOT / "config").glob("*.template")):
        stripped = re.sub(r"^\s*//.*$", "", read(f), flags=re.M)
        try:
            json.loads(stripped)
        except Exception as e:
            note("template", f"{f.name} does not parse as JSONC: {e}")


def main() -> int:
    print("ashline deep audit\n")
    check_numbers()
    print()
    for fn in (check_links, check_tables, check_html, check_anchors,
               check_lossy, check_templates):
        fn()

    if not FINDINGS:
        print("no findings")
        return 0
    print(f"\n{len(FINDINGS)} finding(s):")
    for kind, msg in FINDINGS:
        print(f"  [{kind}] {msg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())