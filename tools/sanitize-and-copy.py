#!/usr/bin/env python3
"""
Copy authored artifacts into the provenance repo, parameterizing absolute paths.

LESSON (recorded deliberately): a blind text substitution of an absolute path
into `${env:VAR}` looks correct and silently breaks every SINGLE-QUOTED string
it lands in, because PowerShell does not interpolate inside '...'. 28
occurrences broke that way on the first pass. The replacement here is therefore
two-phase and quote-aware:

  phase 1  convert  '<path>${env:VAR}\\x'  ->  "<path>$Var\\x"   (quote fix)
  phase 2  replace   ${env:VAR}            ->  $Var              (now safe)
  phase 3  inject a resolution block so $Var actually exists

Only `.ps1` gets the PowerShell treatment. `.cmd` uses %VAR% and `.py` uses
os.environ, and both are handled separately because neither understands
PowerShell syntax.

Anything it cannot transform safely is left ALONE and reported.
"""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

SRC = Path(r"C:\Users\rezer\.config\opencode")
DST = Path(r"D:\opencode\provenance")

SECRETS = ["60vETVdSLPUqfNccBsqi2kPV891HXw1kZzrT_PxFF1I"]

PS_VARS: list[tuple[str, str]] = [
    # (absolute-path regex, PowerShell variable name)
    (r"C:\\Users\\rezer\\\.config\\opencode", "$ConfigDir"),
    (r"C:\\Users\\rezer", "$UserProfile"),
    (r"D:\\Tools", "$ToolsDir"),
    (r"D:\\opencode", "$CollectionsDir"),
]

# ASCII ONLY. Windows PowerShell 5.1 reads a BOM-less file as ANSI, so any
# non-ASCII character in a .ps1 becomes mojibake. The originals here were pure
# ASCII; this block must not change that.
PS_RESOLUTION_BLOCK = r"""
# -- Path resolution ---------------------------------------------------------
# Overridable via environment. Defaults match the machine this was authored on;
# set WB_TOOLS_DIR / WB_COLLECTIONS_DIR / WB_CONFIG_DIR to relocate without
# editing this file.
if (-not $ToolsDir)       { $ToolsDir       = if ($env:WB_TOOLS_DIR)      { $env:WB_TOOLS_DIR }      else { 'D:\Tools' } }
if (-not $CollectionsDir) { $CollectionsDir = if ($env:WB_COLLECTIONS_DIR) { $env:WB_COLLECTIONS_DIR } else { 'D:\opencode' } }
if (-not $UserProfile)    { $UserProfile    = $env:USERPROFILE }
if (-not $ConfigDir)      { $ConfigDir      = if ($env:WB_CONFIG_DIR)     { $env:WB_CONFIG_DIR }     else { Join-Path $UserProfile '.config\opencode' } }
# ---------------------------------------------------------------------------
"""

CMD_VARS: list[tuple[str, str]] = [
    (r"C:\\Users\\rezer\\\.config\\opencode", "%WB_CONFIG_DIR%"),
    (r"C:\\Users\\rezer", "%USERPROFILE%"),
    (r"D:\\Tools", "%WB_TOOLS_DIR%"),
    (r"D:\\opencode", "%WB_COLLECTIONS_DIR%"),
]

CMD_RESOLUTION_BLOCK = r"""@rem -- Path resolution ---------------------------------------------------------
@rem These launchers run under Task Scheduler, where %USERPROFILE% points at
@rem the SYSTEM profile rather than the interactive user. That is exactly WHY
@rem the original used an absolute path rather than %USERPROFILE%, so do not
@rem "simplify" it back. install.ps1 writes scripts\paths.cmd with the resolved
@rem values; without it these fall back to the defaults below.
if not defined WB_CONFIG_DIR      set "WB_CONFIG_DIR=D:\opencode-config"
if not defined WB_COLLECTIONS_DIR set "WB_COLLECTIONS_DIR=D:\opencode"
if not defined WB_TOOLS_DIR       set "WB_TOOLS_DIR=D:\Tools"
@rem --------------------------------------------------------------------------
"""

PY_VARS: list[tuple[str, str]] = [
    (r"C:/Users/rezer/\.config/opencode", 'os.environ.get("WB_CONFIG_DIR")'),
    (r"C:/Users/rezer", 'os.environ.get("USERPROFILE")'),
    (r"D:/Tools", 'os.environ.get("WB_TOOLS_DIR")'),
    (r"D:/opencode", 'os.environ.get("WB_COLLECTIONS_DIR")'),
]


def strip_secrets(text: str) -> tuple[str, bool]:
    hit = False
    for s in SECRETS:
        if s in text:
            text = text.replace(s, "<REDACTED>")
            hit = True
    return text, hit


def do_ps(text: str, report: list[str]) -> str:
    # Phase 1 - quote fix. '${env:TOOLS_DIR}\x'  ->  "$ToolsDir\x"
    def qfix(m: re.Match) -> str:
        inner = m.group(1)
        for abs_re, var in PS_VARS:
            inner = re.sub(abs_re, var, inner)
        report.append(f"quote-fixed: {m.group(0)[:60]}")
        return '"' + inner + '"'

    text = re.sub(r"'([^'\n]*\\[A-Za-z][^'\n]*)'", lambda m: qfix(m) if _has_abs(m.group(1)) else m.group(0), text)
    text = re.sub(r"'([^'\n]*)'", lambda m: qfix(m) if _has_abs(m.group(1)) else m.group(0), text)

    # Phase 2 - bare (unquoted or already double-quoted) occurrences
    for abs_re, var in PS_VARS:
        def rp(m: re.Match, r=var) -> str:
            report.append(f"replaced -> {r}")
            return r
        text = re.sub(abs_re, rp, text)

    # Phase 3 - make the variables exist.
    #
    # Placement matters and got this wrong twice:
    #   * inside the param() declaration  -> param stops being a param block
    #   * before [CmdletBinding()]       -> "unexpected token CmdletBinding",
    #                                        because the attribute must be the
    #                                        first statement in a script
    # So: find the param block line-wise, then its closing ')' at column 0, and
    # insert immediately after that line.
    lines = text.split("\n")
    start = None
    for idx, ln in enumerate(lines):
        if re.match(r"^\s*(\[\s*CmdletBinding\(\)\s*\]\s*)?param\b", ln):
            start = idx
            break

    if start is not None:
        # `param()` on one line is already balanced; otherwise walk to the
        # closing paren, which by convention sits at column 0.
        if lines[start].count("(") == lines[start].count(")"):
            end = start
        else:
            end = start
            for j in range(start + 1, len(lines)):
                if lines[j].strip().startswith(")"):
                    end = j
                    break
            else:
                end = start
        lines.insert(end + 1, PS_RESOLUTION_BLOCK.rstrip("\n"))
    else:
        lines.insert(0, PS_RESOLUTION_BLOCK.rstrip("\n"))
    return "\n".join(lines)


def _has_abs(s: str) -> bool:
    return bool(re.search(r"C:\\Users\\rezer|D:\\Tools|D:\\opencode", s))


def do_cmd(text: str, report: list[str]) -> str:
    for abs_re, var in CMD_VARS:
        def rp(m: re.Match, r=var) -> str:
            report.append(f"cmd -> {r}")
            return r
        text = re.sub(abs_re, rp, text)
    lines = text.split("\n")
    out: list[str] = []
    placed = False
    for ln in lines:
        if not placed and ln.lower().startswith("@echo off"):
            out.append(ln)
            out.append(CMD_RESOLUTION_BLOCK)
            placed = True
        else:
            out.append(ln)
    return "\n".join(out) if placed else CMD_RESOLUTION_BLOCK + text


def do_py(text: str, report: list[str]) -> str:
    for abs_re, expr in PY_VARS:
        def rp(m: re.Match, r=expr) -> str:
            report.append("py -> os.environ")
            return r
        text = re.sub(abs_re, rp, text)
    return text


def main() -> int:
    targets = [
        ("verify-setup.ps1", "scripts/verify-setup.ps1"),
        ("doctor.py", "scripts/doctor.py"),
        ("maintain.ps1", "scripts/maintain.ps1"),
        ("fix-ida-shadow.ps1", "scripts/fix-ida-shadow.ps1"),
        ("fix-ghost-sessions.ps1", "scripts/fix-ghost-sessions.ps1"),
        ("install-game-tools.ps1", "scripts/install-game-tools.ps1"),
        ("install-missing-tools.ps1", "scripts/install-missing-tools.ps1"),
        ("install-missing-tools2.ps1", "scripts/install-missing-tools2.ps1"),
        ("install-missing-tools3.ps1", "scripts/install-missing-tools3.ps1"),
        ("install-triage-tools.ps1", "scripts/install-triage-tools.ps1"),
        ("update-awgs.ps1", "scripts/update-awgs.ps1"),
        ("update-awgs-archive.ps1", "scripts/update-awgs-archive.ps1"),
        ("update-hack-skills.ps1", "scripts/update-hack-skills.ps1"),
        ("sync-awgs-skills.ps1", "scripts/sync-awgs-skills.ps1"),
        ("start-ida-mcp.ps1", "scripts/start-ida-mcp.ps1"),
        ("vmhelper.ps1", "scripts/vmhelper.ps1"),
        # sourced from D:\opencode, not the config root
        ("D:/opencode/update-ecc.ps1", "scripts/update-ecc.ps1"),
        ("devshell.cmd", "scripts/devshell.cmd"),
        ("run-awgs-update.cmd", "scripts/run-awgs-update.cmd"),
        ("run-awgs-archive.cmd", "scripts/run-awgs-archive.cmd"),
        ("the-security-guide.md", "docs/agentic-security.source.md"),
        # --- authored content missed on the first pass ---------------------
        ("REFERENCE-INDEX.md", "REFERENCE-INDEX.md"),
        ("MIGRATION.md", "docs/migration-from-claude-code.md"),
        ("cli.json", "config/cli.json"),
        ("dcp.jsonc", "config/dcp.jsonc"),
        ("magic-context.jsonc", "config/magic-context.jsonc"),
        ("tui-preferences.jsonc", "config/tui-preferences.jsonc"),
        ("index.ts", "config/plugins.index.ts"),
        ("hooks/README.md", "config/hooks.README.md"),
        ("hooks/memory-persistence/README.md", "config/memory-persistence.README.md"),
        ("hooks/hooks.metadata.json", "config/hooks.metadata.json"),
        ("agents/kernel-driver-analyst.md", "agents/kernel-driver-analyst.md"),
        ("agents/ksec-validator.md", "agents/ksec-validator.md"),
        ("agents/gamesec.md", "agents/gamesec.md"),
        ("agents/spacebunnyjb.md", "agents/spacebunnyjb.md"),
    ]

    copied = 0
    for rel_src, rel_dst in targets:
        s = Path(rel_src) if ":" in rel_src else (SRC / rel_src)
        d = DST / rel_dst
        if not s.exists():
            print(f"MISSING  {rel_src}")
            continue
        report: list[str] = []
        text = s.read_text(encoding="utf-8", errors="replace")
        text, redacted = strip_secrets(text)
        # "not at rezer's" -> "not at the operator's". A stale operator identity
        # in a comment is exactly what a public repo must not ship.
        text = text.replace("not at rezer's", "not at the operator's")
        # A game-client path is not an identity leak but is machine-specific.
        # Parameterize it so the script is useful to the next operator.
        m = re.search(r'([A-Z_]+)\s*=\s*r"([A-Z]:\\[^"]*DayZ[^"]*)"', text)
        if m:
            text = text.replace(
                m.group(0),
                f'{m.group(1)} = os.environ.get("WB_GAME_CLIENT") or r"{m.group(2)}"',
            )
            report.append("game client path -> WB_GAME_CLIENT")
        if redacted:
            report.append("SECRET REDACTED")
        if d.suffix == ".ps1":
            text = do_ps(text, report)
        elif d.suffix == ".cmd":
            text = do_cmd(text, report)
        elif d.suffix == ".py":
            text = do_py(text, report)
        else:
            for a, b in [(r"C:\\Users\\rezer\\\.config\\opencode", "~/.config/opencode"),
                         (r"C:/Users/rezer/\.config/opencode", "~/.config/opencode"),
                         (r"C:\\Users\\rezer", "~"),
                         (r"C:/Users/rezer", "~"),
                         (r"D:/opencode/", "{COLLECTIONS}/"),
                         (r"D:\\opencode\\", "{COLLECTIONS}\\")]:
                text = re.sub(a, lambda _m, r=b: r, text)
        d.parent.mkdir(parents=True, exist_ok=True)
        d.write_bytes(text.replace("\r\n", "\n").encode("utf-8"))
        copied += 1
        if report:
            print(f"  {rel_dst}: {len(report)} change(s)")

    # Hard gate: prove no absolute user path survived anywhere.
    # tools/ is excluded - the sanitizer must itself contain the literals it
    # searches for, so it always trips its own gate.
    bad = []
    for f in DST.rglob("*"):
        if not f.is_file() or "tools" in f.parts:
            continue
        if f.suffix in {".ps1", ".cmd", ".py", ".md", ".json", ".jsonc"}:
            t = f.read_text(encoding="utf-8", errors="replace")
            if "C:\\Users\\rezer" in t or "C:/Users/rezer" in t:
                bad.append(str(f.relative_to(DST)))
            for s in SECRETS:
                if s in t:
                    bad.append(f"{f.relative_to(DST)}  SECRET")
    # A .ps1 containing non-ASCII must carry a UTF-8 BOM: PS 5.1 reads a
    # BOM-less file as ANSI, and a mangled byte can terminate a string literal
    # and turn a valid script into a parse error. See tools/fix-ps1-encoding.py.
    fixed = 0
    for ps1 in sorted((DST / "scripts").glob("*.ps1")):
        raw = ps1.read_bytes()
        bom = b"\xef\xbb\xbf"
        has = raw.startswith(bom)
        body = raw[len(bom):] if has else raw
        if any(b > 127 for b in body) and not has:
            ps1.write_bytes(bom + body)
            print(f"  {ps1.name}: added UTF-8 BOM (contains non-ASCII)")
            fixed += 1
    if fixed:
        print(f"  -> run tools/fix-ps1-encoding.py to confirm; {fixed} file(s) adjusted")

    print(f"\ncopied {copied}/{len(targets)}")
    if bad:
        print("GATE FAILED - residual absolute paths or secrets:")
        for b in bad:
            print(f"  {b}")
        return 1
    print("GATE PASSED - no residual absolute user paths, no secrets")

    # Gate 2: the sanitized PowerShell must still PARSE. A path substitution
    # that lands in a single-quoted string, inside a param() declaration, or
    # before [CmdletBinding()] will parse-fail. Proved all three happened.
    parse_fail = check_ps_parses(DST / "scripts")
    if parse_fail:
        print("GATE FAILED - sanitized PowerShell does not parse:")
        for f in parse_fail:
            print(f"  {f}")
        return 1
    print(f"GATE PASSED - all .ps1 parse cleanly")

    # Gate 3: the sanitized Python must still compile.
    for pyf in sorted((DST / "scripts").glob("*.py")):
        try:
            compile(pyf.read_text(encoding="utf-8"), str(pyf), "exec")
        except SyntaxError as e:
            print(f"GATE FAILED - {pyf.name} does not compile: {e}")
            return 1
    print("GATE PASSED - all .py compile")

    # Gate 4: no stale operator identity left in comments.
    stale = []
    for f in (DST / "scripts").glob("*"):
        if f.is_file() and f.suffix in {".ps1", ".cmd", ".py"}:
            if "rezer" in f.read_text(encoding="utf-8", errors="replace").lower():
                stale.append(f.name)
    if stale:
        print(f"GATE FAILED - stale operator name in: {', '.join(stale)}")
        return 1
    print("GATE PASSED - no stale operator identity")
    return 0


def check_ps_parses(scripts_dir: Path) -> list[str]:
    """Parse each .ps1 with the PowerShell parser. No execution, no side effects."""
    ps = (
        "$ErrorActionPreference='Stop';"
        "$fail=@();"
        "Get-ChildItem -LiteralPath $args[0] -Filter *.ps1 | ForEach-Object {"
        "  $e=$null;"
        "  [void][System.Management.Automation.Language.Parser]::ParseFile("
        "    $_.FullName,[ref]$null,[ref]$e);"
        "  if($e -and $e.Count){ $fail += ('{0}: {1}' -f $_.Name,"
        "    (($e | Select-Object -First 2 | ForEach-Object {"
        "      'L{0} {1}' -f $_.Extent.StartLineNumber, $_.Extent.Text }) -join ' | ')) }"
        "};"
        "if($fail){ $fail | ForEach-Object { $PSItem } }"
    )
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps, str(scripts_dir)],
            capture_output=True, text=True, timeout=120,
        )
    except Exception as e:  # pragma: no cover
        return [f"<could not run PowerShell parser: {e}>"]
    return [ln for ln in proc.stdout.splitlines() if ln.strip()]


if __name__ == "__main__":
    sys.exit(main())
