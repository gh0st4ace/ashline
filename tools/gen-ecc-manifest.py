#!/usr/bin/env python3
"""Generate config/ecc-surface.json - a precise manifest of the ECC-provided surface.

ECC (affaan-m/ECC, MIT) supplies the bulk of the running catalog: 315 skills,
103 commands, 9 custom tools, 2 plugins, 4 hook definitions. None of it is
vendored. This manifest exists so none of it is invisible - a reader can see
exactly what comes from upstream, what is authored locally, and what was
excluded on purpose.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

CFG = Path(r"C:\Users\rezer\.config\opencode")
ECC = Path(r"D:\opencode\ecc")
OUT = Path(r"D:\opencode\opencode-workbench\config\ecc-surface.json")


def count(path: Path, pattern: str = "*") -> int:
    return len(list(path.glob(pattern))) if path.exists() else 0


def commit(repo: Path) -> str:
    try:
        return subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                              capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        return "unknown"


data = {
    "_comment": [
        "Manifest of the ECC-provided surface. Nothing here is vendored.",
        "Install with scripts/update-ecc.ps1. See THIRD_PARTY_NOTICES.md."
    ],
    "project": "affaan-m/ECC",
    "upstream": "https://github.com/affaan-m/ECC.git",
    "license": "MIT",
    "pinned_commit": commit(ECC),
    "role": "Supplies the bulk of the running skill and command catalog.",
    "surface": {
        "skills": {
            "count": count(CFG / "skills", "*"),
            "layout": "skills/<id>/SKILL.md",
            "installed_as": "copied by the ECC installer - real directories, not junctions",
            "note": (
                "Largest single component. Counting these plus the 5 authored skills "
                "in .agents/skills/ and the 64 under ~/.agents/skills gives the "
                "catalog. See docs/skills-catalog.md for routing."
            ),
        },
        "commands": {
            "count": count(CFG / "commands", "*.md"),
            "layout": "commands/<name>.md",
            "installed_as": "copied by the ECC installer",
            "note": (
                "ECC ships a large command set. The 6 operational slash commands "
                "this workbench depends on (/verify /doctor /stack /refresh /re "
                "/state) are defined in config/opencode.jsonc.template instead, so "
                "they survive an ECC update."
            ),
        },
        "agents": {
            "count": 4,
            "installed_as": "authored here, not from ECC",
            "names": ["spacebunnyjb", "gamesec", "kernel-driver-analyst", "ksec-validator"],
        },
        "tools": {
            "count": count(CFG / "tools", "*.ts"),
            "layout": "tools/*.ts",
            "names": ["run-tests", "check-coverage", "security-audit", "format-code",
                      "lint-check", "git-summary", "changed-files", "dependency-analyzer"],
            "note": "Registered as OpenCode custom tools.",
        },
        "plugins": {
            "files": ["ecc-hooks.ts", "index.ts"],
            "note": (
                "index.ts is intentionally INERT. OpenCode auto-loads every file "
                "in plugins/ AND the ./plugins config entry, so a barrel that "
                "registered hooks would initialise each hook twice. It must still "
                "be a valid v2 definition or the loader marks it failed and the "
                "TUI shows it red."
            ),
        },
        "hooks": {
            "files": ["hooks.json", "codex-hooks.json", "qoder-hooks.json",
                      "hooks.metadata.json"],
            "subdirs": ["hermes/", "memory-persistence/"],
            "note": (
                "hooks.json carries only keys the harness accepts. $schema, id and "
                "description live in hooks.metadata.json because Claude Code "
                "reports any other key as unknown at load time."
            ),
        },
    },
    "local_adaptations": {
        "ecc-v2-shim/ecc-hooks.ts":
            "Ported to the OpenCode v2 plugin shape. Re-applied after every pull "
            "with a timestamped backup.",
        "ecc-v2-shim/index.ts":
            "Inert v2 entry point. Re-applied after every pull.",
        "scripts/update-ecc.ps1":
            "pull -> npm install -> build -> install-apply --profile full "
            "--enable-hooks, then re-apply the two v2 files, strip the legacy "
            "\"plugin\": [\"./plugins\"] key, audit only {file:...} references, "
            "then run ecc.js doctor and opencode plugin list. "
            "opencode.jsonc is never touched.",
    },
    "excluded_from_this_repo": [
        "The 315 skills and 103 commands themselves - affaan-m/ECC content, MIT, "
        "reproduced by running the installer rather than copied.",
        "LLM-jailbreak prompt agents in agents/ (DeepSeek, GEMINI, GLM and Muse "
        "variants). Not workbench methodology.",
        "Operator-local scope-override directives.",
        "A live-format credential that was present in service.json.",
        "Two DayZ project handoff documents - that project has its own repository.",
    ],
}

OUT.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
               encoding="utf-8", newline="\n")
print(f"wrote {OUT}")
d = json.loads(OUT.read_text(encoding="utf-8"))
s = d["surface"]
print(f"  pinned_commit {d['pinned_commit'][:12]}")
print(f"  skills={s['skills']['count']}  commands={s['commands']['count']}  "
      f"tools={s['tools']['count']}  agents={s['agents']['count']}")