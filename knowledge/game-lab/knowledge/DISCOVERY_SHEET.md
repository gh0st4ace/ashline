# DISCOVERY SHEET — game RE / modding open tooling
Мaintained by the `game-research-tool-discovery` skill. One row = one decision.
Statuses: INSTALLED+VERIFIED (runs/registered) | CANDIDATE (evaluated, not installed) | REJECTED (with reason).

## Verified 15.10.2026 (category B/C, from discovery agents)

| Project | Role | License | Status | Verdict |
| ------- | ---- | ------- | ------ | ------- |
| dariushoule/x64dbg-automate (+pyclient) | native x64dbg plugin (ZMQ+RPC) + python/мcp-клиент ~40 tools | MIT | active 2026-07 | **CANDIDATE-ưu tiên_install next session** — the only LIVE agent-breakpoint path into x64dbg |
| dariushoule/x64dbg-skills + REMnux fork | SKILL.md routines over automate (state-snapshot/diff, /decompile angr, yara-sigs) | MIT | active | **CANDIDATE** — take the OpenCode fork |
| svnscha/mcp-windbg | MCP wrapper over cdb.exe/kd.exe (crash dump + kernel -k) | MIT | active 2026-10 | **CANDIDATE** for kernel-side automation; lighter than full Store WinDbg MCP |
| microsoft/win-dev-skills (Diagnostician) | official 5-phase root-cause diagnostic method | n/d | active 2026-10 | **CANDIDATE** — portable methodology reference |
| wbenny/pdbex | export kernel structs out of PDB to C headers | n/d | active 2025-06 | **CANDIDATE** for driver struct offsets |
| LukeFZ/Il2CppInspectorRedux | next-gen IL2CPP metadata dumper (Unity 6.x, metadata v31+) | GPL-3.0 | active 2026-08 | **CANDIDATE** once a Unity 6 target appears |
| Encryqed/Dumper-7 | UE4/UE5 SDK generator | n/d | active 2026-09 | **CANDIDATE**; run inside ac-test VM |
| miscusi-peek/cheatengine-mcp-bridge | Lua CE bridge + FastMCP (auto-assemble/DBVM) | n/d | active 2026-08 | **CANDIDATE** only for CE-specific injection pipeline/DBVM |
| chengyixu/cheat-engine-cli (cecli) | agent JSON-first bridge over ceserver protocol | n/d | active 2026-08 | **INSTALLED (clone)** `external\cheat-engine-cli`; works with ceserver-session in VM |
| guided-hacking/GH-Offset-Dumper | sig/netvar → offset headers + CHEAT-TABLE + ReClass DP | verify on use | 2025-05 | **INSTALLED (clone)** |
| guided-hacking/D3D11TestEnvironment | dummy D3D11 app for hook benches | verify | active-ish | **INSTALLED (clone)** |
| GH_AntiDebug_Bypass_Practice_Tool | guided-hacking repo — was NOT FOUND (name mismatch) | — | — | REJECTED-with-name-glitch (see agent report) |
| bethington/ghidra-mcp (v6.0.0) | Ghidra MCP with 267 tools; LOCAL install already exists D:\Tools\ghidra-mcp, compiled for Ghidra 12.1.2 | n/d | active 2026-10 | **ALREADY INSTALLED** (local preview); collides by extension name with LaurieWired — keep ONE |
| LaurieWired/GhidraMCP v2.0 | first-party Ghidra MCP, supports 12.1.4 headless | Apache-2.0 | active 2026-10 | REJECTED-as-duplicate (REA has 170 tools incl full Ghidra; plus ext-name collision with local fork) |
| microsoft/WinDbg-MCP (Store 1.2610.1001.0+) | official; officially VS Code/Copilot CLI only | proprietary | 2026-10 | REJECTED for now — best-effort mode asks to disable prompt-injection protection; revisit only if Store WinDbg gets here |
| pykd / DbgShell / x64dbgpy | historical automation paths | — | dead | REJECTED (dead/phantom) |
| Perfare/Il2CppDumper | old pipeline; Unity 5.3–2022.2 | GPL-3.0 | frozen 2024 | KEEP for old titles (installed) |
| SamboyCoding/Cpp2IL | new pipeline; Unity 6 works | MIT | active 2026-09 | KEEP INSTALLED; update on demand |
| Il2CppInspectorPro | moved to URKit, archived | — | dead | REJECTED |
| memflow/memflow v0.2.4 | Rust/C-ABI VM introspection (qemu/kvm/native connectors) | MIT | active 04.2026 | **CANDIDATE** for snapshot-based (no-injection) bench introspection |
| halby24/JiaboLi/Linkingooo RenderDoc-MCPs | GPU-frame MCPs | n/d | active 2026-01+ | REJECTED-as-duplicate (renderdoc-mcp skill installed) |
| rajkumar-rangaraj/PDB-Downloader, willglynn/pdb | PDB source | — | varies | REJECTED-as-duplicate (pdbfetch + dia2dump sample already in stack) |
| Perfare's DBVM Lua bridge | niche | — | — | see cheatengine-mcp-bridge row |
| microsoft/flare-vm | fresh-VM RE installer | Apache-2.0 | active | REJECTED:维护 overhead vs installed curated stack; only useful as -customConfig on a NEW clean VM |
| LING71671/open-reverselab | brand-new (pushed 2026-10-15) AI RE agent platform | n/d | 2026-10-15 | OBSERVE — no quality data yet |

## Installed & verified 15.10.2026 (category A)

| Project | Role | Version | License | Source | Verified how |
| ------- | ---- | ------- | ------- | ------ | ------------ |
| rehan-remade/universal-modder | mod-development skills (auth: opencode.json native support) | git @2026-10 (shallow) | MIT | github.com/rehan-remade/universal-modder | 11 skills junctioned into ~/.agents/skills; catalog announced (`asset-pipeline…showcase-video`) — OpenCode picked them up in-session |
| nesaon03/XYREVERSE | RE skills pack: IL2CPP, Unreal dumping, Ghidra/IDA automation, frida, kernel-driver internals, dotnet-runtime, REA, x64dbg triage | git @2026-10 (shallow) | MIT | github.com/nesaon03/XYREVERSE | 9 skills junctioned; catalog announced in-session |
| ReClass.NET (official) | manual struct/memory class builder for native games | v1.2 release (2019-04; repo active: 249 commits after) | github.com/ReClassNET/ReClass.NET | release asset x64/x86 extracted to D:\Tools\ReClass.NET via tar; binaries present; NOT GUI-run yet (operator tool) |
| anthropics/skills | format reference for SKILL.md (agentskills.io) | — | (root LICENSE absent — used as spec reference only) | REPORTED-verified structure |
| microsoft/Windows-driver-samples | reference WDK IOCTL/IRP patterns for driver research (master §3.1 priority) | MIT | origin/main @ 2dc3fd3, 3680 files (git ls-files) | **INSTALLED (shallow clone)** 15.10.2026 → `D:\opencode\driver-samples`; verified: git status up-to-date + `git fetch` re-check in-sync (15.10.2026, ksec-validator subagent), audio\sysvad\sysvad.sln present; update manually via `git pull` |

## CANDIDATES (assessed, deferred until a task needs them)

| Project | Useful because | Why deferred |
| ------- | -------------- | ------------ |
| LaurieWired/GhidraMCP (11k★, Apache-2.0, active 2026-10) | agent-driven Ghidra ops | duplicate of REA MCP (170 tools, ghidra 12.1.4 verified) — nothing it offers that REA lacks for our flow |
| whory/mcp-gamehacking (MIT, 2026-10) | 4100 structures KB + specialized agents | adoption requires running a new MCP server + reviewing its tool surface; adopt on first concrete game task that needs the KB |
| obra/superpowers (299k★, MIT) | generic engineering skills (TDD/debug/verify) | overlaps our own verification discipline; may cherry-pick later |
| VoltAgent/awesome-agent-skills (35k★, MIT) | 1000+ skill directory/router | reference index for future searches, not an install |
| NoorQureshi/security-skills (206, MIT), mukul975/… (34k★) | broad security skill packs | our catalog already carries the overlapping domain skills (installed mirrors) |

## REJECTED (with reason)

| Project | Reason |
| ------- | ------ |
| mrexodia/ida-pro-mcp | upstream README points to newer official HexRaysSA/ida-mcp; our IDA path is REA attached provider (verified) — no gap |
| binwalk (pip 2.1.0, PyPI) | sdist lacks `binwalk.core` → ModuleNotFoundError at import; reproduced via `pip install --no-cache-dir --force-reinstall`; Windows path needs libmagic anyway; Rust rewrite v3.1.0 has NO prebuilt Windows release assets and host has no Rust toolchain. REMOVED 15.10.2026 (pip pkg + shim). Fallbacks: r2/rizin string/signature work, 7z, DIE; firmware tasks use firmware-pentest skill (EMBA/unblob are its primary tools). binwalk3-via-Rust = CANDIDATE only if Rust lands on host. |
| SEO-spam cheat repos (myth-of-empires-helper-system, valheim-helper-2026, Persona-5-Royal-2026) | malware-bait patterns, no skills |
| ComposioHQ/awesome-claude-skills & other license-less aggregators | no LICENSE at root — distribution unclear |
| flare-vm as an install path | we already maintain a curated manual toolchain; FLARE-VM is a VM image installer for a fresh environment, not additive here |

## Environment additions this day (kernel layer, still active)
LOLDrivers API feed cached (702) + `kernel-sec` scripts — see kernel-sec\knowledge\README.md.

## Search hygiene notes
- GitHub REST anonymous rate limit is easy to exhaust; releases pages still readable via
  webfetch `releases/expanded_assets/<tag>`.
- Skill-name collisions across discovery roots silently skip — junction step checks
  `~/.agents/skills` content first (measured: universal-modder's `reverse-engineering` skipped).
