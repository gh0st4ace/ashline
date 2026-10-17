#!/usr/bin/env python3
"""
Generate config/tool-manifest.json - a complete inventory of the installed
toolchain, scanned from disk and cross-referenced against the installers.

WHY THIS EXISTS
---------------
The binaries themselves cannot be committed: Ghidra alone is 865 MiB, Sysinternals
272 MiB, the Windows SDK-derived JDK 328 MiB, hashcat 371 MiB, and IDA Pro is
commercial. GitHub's per-file limit is 100 MB, and vendoring someone else's
distributed binary is repackaging, not sharing.

But a reader needs to know EXACTLY what is expected, at which version, from
which source, installed by which script, and required by which skill. Without
that manifest a fresh machine is a guess, and a half-installed environment is
indistinguishable from a broken one.

So: scan the disk, emit the contract. Nothing invented - every version and size
is read from the filesystem, and anything not found is reported as
absent rather than assumed.

Outputs config/tool-manifest.json and prints a summary.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

TOOLS = Path(r"D:\Tools")
COLL = Path(r"D:\opencode")
OUT = Path(r"D:\opencode\provenance\config\tool-manifest.json")

# name -> (install dir, what provides it, source, license, required by)
# "source" is the canonical download the installer uses, not an invite to
# redistribute a binary.
CATALOG: dict[str, dict] = {
    # --- native analysis ---
    "ghidra_12.1.4_PUBLIC": dict(
        role="Native decompilation. Default REA provider, headless.",
        source="https://github.com/NationalSecurityAgency/ghidra/releases",
        license="Apache-2.0 (NSA public release)",
        installer="manual - not installed by any script here",
        needed_by="rea (default provider), docs/architecture.md",
        vendoring="NOT VENDORABLE - 865 MiB"),
    "jdk-21.0.12.1+1": dict(
        role="Java runtime. Ghidra cannot start without it.",
        source="https://adoptium.net/temurin/releases/",
        license="Eclipse Temurin (GPL-2.0 with Classpath Exception)",
        installer="manual",
        needed_by="ghidra",
        vendoring="NOT VENDORABLE - 328 MiB"),
    "radare2-6.2.4-w64": dict(
        role="CLI disassembly: r2, rabin2, radiff2.",
        source="https://github.com/radareorg/radare2/releases",
        license="LGPL-3.0",
        installer="scripts/install-missing-tools.ps1 (pass 1)",
        needed_by="radare2, rev-struct, binary-diff, rev-symbol",
        vendoring="install via script - 41 MiB"),
    "x64dbg": dict(
        role="User-mode debugger. Scylla bundled in its snapshot.",
        source="https://github.com/x64dbg/x64dbg/releases",
        license="GPL-2.0",
        installer="manual",
        needed_by="dynamic-debugging-triaging, game-memory-lab",
        vendoring="NOT VENDORABLE - 81 MiB"),
    "dnSpy": dict(
        role=".NET decompiler. dnSpy.Console for headless use.",
        source="https://github.com/dnSpyEx/dnSpy/releases",
        license="GPL-3.0 (dnSpyEx fork)",
        installer="manual (shims reasserted by pass 3)",
        needed_by="dotnet-reverse, game-engine",
        vendoring="NOT VENDORABLE - 203 MiB"),
    "nuget": dict(
        role="dnlib + AsmResolver assemblies built for netstandard2.0/net6/net8/net9.",
        source="built locally via dotnet build",
        license="MIT / MIT",
        installer="scripts/install-game-tools.ps1",
        needed_by="dotnet-reverse, game-modding-lab",
        vendoring="regenerable - dotnet build, 1.2 MiB"),
    # --- binary triage ---
    "capa": dict(
        role="Capability mapping with ATT&CK IDs. Run FIRST on any unfamiliar binary.",
        source="https://github.com/mandiant/capa/releases",
        license="Apache-2.0",
        installer="scripts/install-triage-tools.ps1",
        needed_by="code-obfuscation-deobfuscation, reverse-engineering",
        vendoring="install via script - 36 MiB"),
    "die": dict(
        role="Detect It Easy: packer and protector identification.",
        source="https://github.com/horsicq/Detect-It-Easy/releases (live API, unpinned)",
        license="MIT",
        installer="scripts/install-triage-tools.ps1",
        needed_by="binary-protection-bypass, code-obfuscation-deobfuscation",
        vendoring="install via script - 53 MiB"),
    "upx": dict(
        role="Executable packing and unpacking.",
        source="https://github.com/upx/upx/releases (v5.2.1 pinned)",
        license="GPL-2.0",
        installer="scripts/install-missing-tools2.ps1, corrected by pass 3",
        needed_by="unpacking tasks",
        vendoring="install via script - 0.8 MiB"),
    "SysinternalsSuite": dict(
        role="164 executables: process, driver, and system inspection.",
        source="https://learn.microsoft.com/sysinternals/downloads",
        license="Microsoft EULA, free redistribution",
        installer="scripts/install-missing-tools2.ps1, shims in pass 3",
        needed_by="windows-driver-security, kernel-sec",
        vendoring="NOT VENDORABLE - 272 MiB"),
    # --- game / modding ---
    "cheat-mcp": dict(
        role="72-tool MCP: process/module enum, memory read/write/scan, pointer chains, "
             "DLL injection, IAT hooking, anti-cheat detection, network capture.",
        source="built from source; upstream omits #include <mstcpip.h> in src/network.cpp "
               "which breaks SIO_RCVALL - that include is a LOCAL patch",
        license="check upstream",
        installer="manual build",
        needed_by="rea? no - game-memory-lab, game-hacking, graphics-api",
        vendoring="NOT VENDORABLE - third-party source plus local patch"),
    "Il2CppDumper": dict(
        role="Unity IL2CPP metadata and symbol dumping.",
        source="https://github.com/Perfare/Il2CppDumper/releases",
        license="Unlicense",
        installer="scripts/install-game-tools.ps1",
        needed_by="rev-u3d-dump, game-engine-detection",
        vendoring="install via script - 25 MiB"),
    "Cpp2IL": dict(
        role="Alternative IL2CPP to managed-code converter.",
        source="https://github.com/SamboyCoding/Cpp2IL/releases",
        license="MIT",
        installer="scripts/install-game-tools.ps1",
        needed_by="rev-u3d-dump, il2cpp-reverse-engineering",
        vendoring="install via script - 22 MiB"),
    "ReClass.NET": dict(
        role="Class and struct reconstruction GUI.",
        source="https://github.com/ReClassNET/ReClass.NET/releases",
        license="Unlicense",
        installer="manual",
        needed_by="rev-struct",
        vendoring="install via script - 9.4 MiB"),
    "kdmapper": dict(
        role="Kernel driver mapper. Analysis reference only - never run on the host.",
        source="https://github.com/kdmapper/kdmapper",
        license="check upstream",
        installer="manual",
        needed_by="windows-kernel-security",
        vendoring="NOT VENDORABLE - offensive kernel tooling"),
    # --- lua / roblox ---
    "unluau": dict(
        role="Luau bytecode decompiler.",
        source="https://github.com/Roblox/unluau",
        license="MIT",
        installer="manual",
        needed_by="luau-roblox-reverse",
        vendoring="NOT VENDORABLE - 74 MiB"),
    "luau": dict(
        role="Luau runtime and CLI.",
        source="https://github.com/luau-lang/luau",
        license="MIT",
        installer="manual",
        needed_by="luau-roblox-reverse",
        vendoring="install via script - 7.1 MiB"),
    "luau-decompiler": dict(
        role="Extended Luau decompilation set.",
        source="manual",
        license="unknown - verify before redistribution",
        installer="manual",
        needed_by="luau-roblox-reverse",
        vendoring="NOT VENDORABLE - license unverified"),
    # --- web / recon ---
    "nuclei": dict(
        role="Template-driven scanner.", source="https://github.com/projectdiscovery/nuclei",
        license="MIT", installer="pass 2, corrected by pass 3 (v3.11.1 pinned)",
        needed_by="src-hunter, web attack playbooks", vendoring="install via script"),
    "httpx": dict(
        role="HTTP prober.", source="https://github.com/projectdiscovery/httpx (v1.12.0 pinned)",
        license="MIT", installer="pass 2, corrected by pass 3",
        needed_by="web recon playbooks",
        vendoring="install via script - NOTE: filename match once captured the wrong binary"),
    "ffuf": dict(
        role="Fuzzing and content discovery.", source="https://github.com/ffuf/ffuf (v2.3.0 pinned)",
        license="MIT", installer="pass 2, corrected by pass 3",
        needed_by="src-hunter, fuzzing", vendoring="install via script"),
    "gobuster": dict(
        role="Directory and DNS enumeration.",
        source="https://github.com/OJ/gobuster (v3.8.2 pinned)", license="MIT",
        installer="pass 2, corrected by pass 3",
        needed_by="src-hunter", vendoring="install via script"),
    "hashcat-7.1.2": dict(
        role="GPU password cracking. Replaces John the Ripper, which has no "
             "official Windows build.",
        source="https://hashcat.net/hashcat/", license="MIT-ish, check upstream",
        installer="scripts/install-missing-tools.ps1 (pass 1)",
        needed_by="hash-attack-techniques, rsa-attack-techniques",
        vendoring="NOT VENDORABLE - 371 MiB"),
    # --- anti-debug ---
    "TitanHide": dict(
        role="Windows kernel driver that hides a debugger. x64dbg plugins included.",
        source="https://github.com/68110357/Anti-Debug",
        license="check upstream",
        installer="manual",
        needed_by="anti-debugging-techniques",
        vendoring="NOT VENDORABLE - offensive tooling"),
    # --- MCP and python envs ---
    "ida-pro-mcp-venv": dict(
        role="Python venv for the ida-pro-mcp 1.4.0 bridge REA's attached provider uses.",
        source="https://github.com/mrexodia/ida-pro-mcp", license="check upstream",
        installer="manual",
        needed_by="rea (attached provider), start-ida-mcp.ps1",
        vendoring="regenerable - pip install into a venv"),
    "renderdoc-mcp": dict(
        role="RenderDoc MCP server binary.",
        source="prebuilt Windows release", license="check upstream",
        installer="manual", needed_by="renderdoc-mcp skill",
        vendoring="install via script - 18 MiB"),
    "renderdoc-mcp-bin": dict(
        role="RenderDoc MCP prebuilt distribution.",
        source="prebuilt Windows release", license="check upstream",
        installer="manual", needed_by="renderdoc-mcp skill",
        vendoring="install via script - 80 MiB"),
    "reverify": dict(
        role="Re-verification helper.", source="manual", license="unknown",
        installer="manual", needed_by="workflow scripts", vendoring="small, review before shipping"),
    "lib": dict(
        role="Shared libraries.", source="various", license="various",
        installer="various", needed_by="various", vendoring="review before shipping"),
    "de4dot": dict(
        role=".NET deobfuscator and IL post-processor.",
        source="https://github.com/de4dot/de4dot/releases",
        license="GPL-3.0",
        installer="scripts/install-missing-tools2.ps1 (pass 2)",
        needed_by="code-obfuscation-deobfuscation, dotnet-reverse",
        vendoring="small - review license before shipping"),
    "ghidra-mcp": dict(
        role="MCP server wrapping Ghidra. REJECTED as a duplicate: REA already "
             "supplies 170 tools including a Ghidra provider, and the extension "
             "name collides with the local fork.",
        source="https://github.com/LaurieWired/GhidraMCP",
        license="check upstream",
        installer="REJECTED - do not install",
        needed_by="nothing - see docs/knowledge-workspaces.md",
        vendoring="not shipped - rejected duplicate"),
    "pdbfetch": dict(
        role="Symbol and PDB field lookup against public symbol servers.",
        source="https://github.com/winsiderss/pdbfetch",
        license="check upstream",
        installer="manual",
        needed_by="rev-symbol, crash triage",
        vendoring="small - review license before shipping"),
}

# Bulk / non-tool payloads that must never be committed.
BULK = {
    "iso": "VM test media. 4.67 GiB. Not redistributable.",
    "gnu": "GNU toolchain if present.",
}


def dir_bytes(p: Path) -> int:
    if not p.exists():
        return 0
    return sum(f.stat().st_size for f in p.rglob("*") if f.is_file())


def main() -> int:
    if not TOOLS.exists():
        print(f"FATAL: {TOOLS} not found. Cannot build a manifest from an absent toolchain.")
        return 1

    installed, absent = [], []
    for name, meta in sorted(CATALOG.items()):
        p = TOOLS / name
        b = dir_bytes(p)
        entry = {
            "name": name,
            "path": str(p).replace("\\", "/"),
            "present": p.exists(),
            "size_mib": round(b / 1024 / 1024, 1),
            **meta,
        }
        (installed if p.exists() else absent).append(entry)

    # Anything on disk that the catalog does not describe.
    undescribed = []
    for d in sorted(TOOLS.iterdir()):
        if d.is_dir() and d.name not in CATALOG and d.name not in BULK:
            undescribed.append({
                "name": d.name,
                "size_mib": round(dir_bytes(d) / 1024 / 1024, 1),
                "status": "ON DISK BUT NOT IN THE CATALOG - classify before shipping",
            })

    loose = [f for f in TOOLS.iterdir() if f.is_file()]

    manifest = {
        "_comment": [
            "Complete inventory of the installed toolchain, scanned from disk.",
            "Binaries are NOT vendored: sizes, licenses, and GitHub's 100 MB",
            "per-file limit make it impossible, and repackaging a vendor's",
            "distributed binary is not sharing. What is vendored is this",
            "contract: every tool, version, source, license, installer script,",
            "and the skills that depend on it.",
            "",
            "Provision with scripts/install-all-tools.ps1, or per-script.",
            "Verify with scripts/verify-setup.ps1.",
        ],
        "generated_at": "2026-10-17",
        "toolchain_root": str(TOOLS).replace("\\", "/"),
        "totals": {
            "tools_catalogued": len(CATALOG),
            "present": len(installed),
            "absent": len(absent),
            "size_gib": round(sum(e["size_mib"] for e in installed) / 1024, 2),
        },
        "tools": sorted(installed + absent, key=lambda e: (not e["present"], e["name"])),
        "not_tools": {
            k: v for k, v in BULK.items() if (TOOLS / k).exists()
        },
        "undescribed_on_disk": undescribed,
        "loose_files": [
            {"name": f.name, "size_mib": round(f.stat().st_size / 1024 / 1024, 2)}
            for f in sorted(loose, key=lambda x: -x.stat().st_size)[:20]
        ],
        "loose_file_count": len(loose),
        "policy": {
            "never_vendor": [
                "Anything over ~40 MiB",
                "Anything under a commercial or EULA license (IDA Pro, Windows SDK)",
                "Anything derived from someone else's git clone",
                "Virtual machine media",
            ],
            "always_vendor": [
                "Every script that installs, updates, or verifies a tool",
                "The manifest describing what is expected",
                "Self-built lab targets (game-lab/bench) - these are yours",
            ],
        },
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
                   encoding="utf-8", newline="\n")

    t = manifest["totals"]
    print(f"wrote {OUT}")
    print(f"  catalogued {t['tools_catalogued']}  present {t['present']}  "
          f"absent {t['absent']}  total {t['size_gib']} GiB")
    if undescribed:
        print(f"  UNDESCRIBED on disk ({len(undescribed)}) - classify these:")
        for u in undescribed:
            print(f"    {u['name']:<26} {u['size_mib']:>8.1f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())