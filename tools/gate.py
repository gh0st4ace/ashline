#!/usr/bin/env python3
"""
Release gate for Ashline.

Runs every check that must pass before this repository is published or updated.
Read-only apart from regenerating the sanitized scripts.

Usage:  py -3 tools/gate.py [--fix]
"""
from __future__ import annotations

import ast
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES: list[str] = []
PASSES: list[str] = []


def ok(msg: str) -> None:
    PASSES.append(msg)
    print(f"  PASS  {msg}")


def bad(msg: str) -> None:
    FAILURES.append(msg)
    print(f"  FAIL  {msg}")


def section(title: str) -> None:
    print(f"\n--- {title} " + "-" * max(0, 58 - len(title)))


# ---------------------------------------------------------------------------
def gate_secrets() -> None:
    section("secrets and identity")
    # Patterns that must never appear in a public repository.
    # Do NOT add a negative lookahead for the operator's name here. An earlier
    # revision had `(?!rezer\b)` to avoid self-flagging, which meant the gate
    # could never catch `C:\Users\<operator>\...` in a shipped file - a
    # false-green on exactly the leak it exists to prevent. The `tools/`
    # exclusion below is the correct mechanism: the generators must contain the
    # literals they search for, and they are the only place that is true.
    patterns = {
        "absolute user path": r"[Cc]:[\\/]+Users[\\/]+[A-Za-z0-9_.-]+",
        "hardcoded password field": r'"password"\s*:\s*"[A-Za-z0-9_\-]{16,}"',
        "aws key": r"AKIA[0-9A-Z]{16}",
        "github token": r"gh[pousr]_[A-Za-z0-9]{20,}",
        "openai-style key": r"\bsk-[A-Za-z0-9]{20,}\b",
        "bearer token": r"[Bb]earer\s+[A-Za-z0-9_\-]{24,}",
        "operator name": r"\brezer\b",
    }
    skip_dirs = {".git", "node_modules", "tools"}
    scan_ext = {".ps1", ".cmd", ".py", ".md", ".json", ".jsonc", ".sh", ".ts", ".yml", ".yaml", ".html", ".txt"}
    for f in ROOT.rglob("*"):
        if not f.is_file() or f.suffix.lower() not in scan_ext:
            continue
        if any(p in f.parts for p in skip_dirs):
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        rel = f.relative_to(ROOT)
        for name, pat in patterns.items():
            for m in re.finditer(pat, text):
                line = text[: m.start()].count("\n") + 1
                bad(f"{rel}:{line}  {name}: {m.group(0)[:60]}")
    if not FAILURES:
        ok("no secrets, no absolute user paths, no operator name")


def gate_json() -> None:
    section("JSON validity")
    for name in ("package.json", "collections.lock.json"):
        p = ROOT / name
        try:
            json.loads(p.read_text(encoding="utf-8"))
            ok(f"{name} parses")
        except Exception as e:
            bad(f"{name}: {e}")


def gate_powershell() -> None:
    section("PowerShell parse (no execution)")
    scripts = sorted((ROOT / "scripts").glob("*.ps1")) + [ROOT / "install.ps1"]
    scripts += sorted(ROOT.glob("knowledge/*/selfcheck.ps1"))
    script = (
        "$f=@();"
        + "".join(
            f"$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile('{s}',[ref]$null,[ref]$e);"
            f"if($e -and $e.Count){{$f+='{s.name}: '+(($e|Select-Object -First 2|%{{$_.Extent.StartLineNumber}}) -join ',')}};"
            for s in scripts
        )
        + "$f"
    )
    r = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script],
                       capture_output=True, text=True, timeout=180)
    fails = [ln for ln in r.stdout.splitlines() if ln.strip()]
    if fails:
        for f in fails:
            bad(f"PowerShell: {f}")
    else:
        ok(f"all {len(scripts)} .ps1 parse cleanly")


def gate_python() -> None:
    section("Python compile")
    pys = sorted(ROOT.rglob("*.py"))
    pys = [p for p in pys if ".git" not in p.parts]
    errs = 0
    for p in pys:
        try:
            ast.parse(p.read_text(encoding="utf-8"))
        except SyntaxError as e:
            bad(f"{p.relative_to(ROOT)}: {e}")
            errs += 1
    if not errs:
        ok(f"all {len(pys)} .py compile")


def gate_powershell_encoding() -> None:
    section("PowerShell encoding (PS 5.1 picks UTF-8 vs ANSI by BOM)")
    # The rule is NOT "all .ps1 must be ASCII". Windows PowerShell 5.1 reads a
    # BOM-less file as ANSI, so non-ASCII is mojibake without a BOM - and a
    # mangled byte can land on a quote and break parsing outright. So:
    #   non-ASCII present -> MUST have a UTF-8 BOM
    #   pure ASCII        -> MUST NOT have one
    # An earlier version of this gate asserted ASCII unconditionally and was
    # wrong; scripts/update-ecc.ps1 has Russian throw strings and is correct.
    bom = b"\xef\xbb\xbf"
    for p in list((ROOT / "scripts").glob("*.ps1")) + [ROOT / "install.ps1"] \
            + sorted(ROOT.glob("knowledge/*/selfcheck.ps1")):
        raw = p.read_bytes()
        has_bom = raw.startswith(bom)
        body = raw[len(bom):] if has_bom else raw
        non_ascii = any(b > 127 for b in body)
        rel = p.relative_to(ROOT)
        if non_ascii and not has_bom:
            try:
                body.decode("utf-8")
            except UnicodeDecodeError:
                bad(f"{rel}: non-ASCII and no BOM - PS 5.1 reads this as ANSI; "
                    f"bytes are not even valid UTF-8")
            else:
                bad(f"{rel}: non-ASCII without a UTF-8 BOM - PS 5.1 will read it "
                    f"as ANSI and a mangled byte may break string parsing")
        elif not non_ascii and has_bom:
            bad(f"{rel}: pure ASCII but carries a UTF-8 BOM - unnecessary, and a "
                f"BOM breaks YAML frontmatter in some readers")
    ok("all .ps1 correctly encoded for PowerShell 5.1")


def gate_links() -> None:
    section("internal links")
    md = sorted(ROOT.glob("*.md")) + sorted((ROOT / "docs").rglob("*.md"))
    md = [m for m in md if ".git" not in m.parts]
    # docs/index.md is the VitePress home page. Its links are site routes
    # ("/methodology"), resolved by the site generator rather than the
    # filesystem. Verify each names a real doc rather than skipping it - a site
    # route that silently 404s is worse than a broken file link.
    site_routes: dict[str, str] = {}
    index = ROOT / "docs" / "index.md"
    if index.exists():
        text = index.read_text(encoding="utf-8", errors="replace")
        # Routes appear both as frontmatter `link: /x` and as markdown
        # `](/x)` in the reading table. Harvest both.
        for pat in (r"link:\s*/([a-z0-9-]+)", r"\]\(/(?:docs/)?([a-z0-9-]+)\)"):
            for m in re.finditer(pat, text):
                site_routes[m.group(1)] = f"docs/{m.group(1)}.md"

    bad_links = 0
    for f in md:
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"\[[^\]]*\]\((?!https?://|#|mailto:)([^)\s]+)\)", text):
            target = m.group(1).split("#")[0]
            if not target:
                continue
            if target.startswith("/"):
                route = target.lstrip("/")
                if route in site_routes:
                    if not (ROOT / site_routes[route]).exists():
                        bad(f"{f.relative_to(ROOT)}: site route /{route} -> {site_routes[route]} missing")
                        bad_links += 1
                else:
                    bad(f"{f.relative_to(ROOT)}: unknown site route -> {target}")
                    bad_links += 1
                continue
            if not (f.parent / target).resolve().exists():
                bad(f"{f.relative_to(ROOT)}: broken link -> {target}")
                bad_links += 1
    if not bad_links:
        ok(f"all internal links in {len(md)} markdown files resolve "
           f"({len(site_routes)} site routes verified against real docs)")


def gate_powershell_runtime() -> None:
    section("PowerShell runtime smoke (sigils, undefined names)")
    # A script can PARSE and still fail at runtime. The recurring shape here:
    # `PROFILES = @{...}` instead of `$PROFILES = @{...}`. PowerShell parses
    # that as a command invocation and fails only when the line executes, so a
    # parse-only gate waves it through - and `verify-setup.ps1` only notices on
    # the one code path that touches it.
    #
    # Run every script with -DryRun (or -? where supported) in a child process
    # and treat any non-zero exit or a CommandNotFoundException as a failure.
    # Nothing is installed: every one of these supports a preview mode.
    scripts = sorted((ROOT / "scripts").glob("*.ps1"))
    failures = []
    for s in scripts:
        if s.name in {"fix-ida-shadow.ps1", "fix-ghost-sessions.ps1"}:
            continue  # these take real action by design; not safe to smoke-test
        args = ["powershell", "-NoProfile", "-NonInteractive",
                "-ExecutionPolicy", "Bypass", "-File", str(s), "-DryRun"]
        try:
            r = subprocess.run(args, capture_output=True, text=True, timeout=90)
        except subprocess.TimeoutExpired:
            failures.append(f"{s.name}: timed out under -DryRun")
            continue
        blob = (r.stdout or "") + (r.stderr or "")
        if "CommandNotFoundException" in blob or "CommandNotFound" in blob:
            first = next((ln for ln in blob.splitlines()
                          if "CommandNotFound" in ln), "")
            failures.append(f"{s.name}: CommandNotFoundException - "
                            f"likely a sigil-less variable. {first.strip()[:90]}")
    if failures:
        for f in failures:
            bad(f)
    else:
        ok(f"all {len(scripts) - 2} preview-capable .ps1 run clean under -DryRun")


def gate_required_files() -> None:
    section("required files")
    required = [
        "README.md", "README.ru.md", "AGENTS.md", "LICENSE", "SECURITY.md",
        "CONTRIBUTING.md", "DISCLAIMER.md", "THIRD_PARTY_NOTICES.md",
        "CHANGELOG.md", "install.ps1", "package.json", "collections.lock.json",
        ".gitignore", "docs/index.md", "docs/methodology.md",
        "config/opencode.jsonc.template", "config/opencode-mem.jsonc.template",
        "config/tool-manifest.json", "config/ecc-surface.json",
        "scripts/install-all-tools.ps1", "scripts/export-portable-bundle.ps1",
        "scripts/install-mcp-servers.ps1", "docs/will-it-work.md",
        "docs/working-shell.md", "docs/tools.md",
    ]
    missing = [r for r in required if not (ROOT / r).exists()]
    if missing:
        for m in missing:
            bad(f"missing required file: {m}")
    else:
        ok(f"all {len(required)} required files present")


def gate_repo_size() -> None:
    section("repository size")
    total = 0
    big = []
    for f in ROOT.rglob("*"):
        if f.is_file() and ".git" not in f.parts:
            sz = f.stat().st_size
            total += sz
            if sz > 50 * 1024 * 1024:
                big.append((f, sz))
    for f, sz in big:
        bad(f"{f.relative_to(ROOT)}: {sz/1024/1024:.1f} MB exceeds GitHub's 100 MB limit")
    if not big:
        ok(f"repo is {total/1024/1024:.2f} MB, no file over 50 MB")


def main() -> int:
    print("ashline release gate")
    gate_required_files()
    gate_secrets()
    gate_json()
    gate_powershell()
    gate_python()
    gate_powershell_encoding()
    gate_powershell_runtime()
    gate_links()
    gate_repo_size()

    print("\n" + "=" * 64)
    print(f"  {len(PASSES)} passed, {len(FAILURES)} failed")
    if FAILURES:
        print("\n  Failures:")
        for f in FAILURES:
            print(f"    - {f}")
        print("\n  NOT READY TO PUBLISH")
        return 1
    print("\n  READY")
    return 0


if __name__ == "__main__":
    sys.exit(main())
