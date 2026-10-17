<div align="center">

**English** · [Русский](README.ru.md)

# OpenCode Workbench

### One hardened OpenCode setup for security research, reverse engineering, and game internals.

**A field-tested configuration you can install instead of rebuilding.**

[![Skills](https://img.shields.io/badge/skills-174-5c4ee5?style=flat-square)](docs/skills-catalog.md)
[![MCP tools](https://img.shields.io/badge/live_MCP_tools-277-339933?style=flat-square)](docs/mcp-servers.md)
[![Reference collections](https://img.shields.io/badge/reference_collections-7-8250df?style=flat-square)](docs/collections.md)
[![Windows](https://img.shields.io/badge/platform-Windows-0078d4?style=flat-square&logo=windows&logoColor=white)](docs/installation.md)
[![MIT license](https://img.shields.io/badge/license-MIT-f4c430?style=flat-square)](LICENSE)

[Quick start](#quick-start) · [What is in the box](#what-is-in-the-box) · [Why it is built this way](#why-it-is-built-this-way) · [The instruments](#the-instruments) · [Documentation](#documentation) · [Contributing](#contributing)

```powershell
git clone https://github.com/gh0st4ace/opencode-workbench
cd opencode-workbench
.\install.ps1 -DryRun
```

> [!IMPORTANT]
> This repository ships the **configuration, methodology, scripts, and knowledge
> bases** — not the third-party tools it drives. 21 GiB of upstream collections
> are declared as dependencies in [docs/collections.md](docs/collections.md) and
> fetched by the installer. Nothing here is vendored.

<br />

## Quick start

### 1. Prerequisites

Windows 10/11, PowerShell 5.1+, and a working OpenCode install. The installer
checks everything else and tells you what is missing rather than failing
silently.

### 2. Preview the plan

```powershell
.\install.ps1 -DryRun
```

Every step is printed before it runs. Nothing is written until you drop the flag.

### 3. Install

```powershell
.\install.ps1                 # config only, into ~/.config/opencode
.\install.ps1 -Profile full   # + toolchains, reference collections, MCP servers
```

### 4. Prove the install

```powershell
.\scripts\verify-setup.ps1     # whole-stack health check, always exits 0
py -3 .\scripts\doctor.py      # runtime health, exits 0 / 1 / 2
```

`verify-setup.ps1` and `doctor.py` do not overlap. The first checks the
**toolchain and wiring**; the second checks the **running installation**. See
[docs/scripts.md](docs/scripts.md#the-two-health-checks).

### 5. Ask

```text
/verify    health check the whole stack
/stack     one-screen status of skills, collections, engines, memory
/refresh   pull every upstream collection and re-link skills
/re        reverse-engineer a binary with REA
```

## What is in the box

| Component | Count | What it is | Where |
| --- | ---: | --- | --- |
| **Skills** | 174 across 5 discovery roots | Routed by a mandatory protocol, not by keyword | [docs/skills-catalog.md](docs/skills-catalog.md) |
| **Reference collections** | 7 | Searchable, never loaded wholesale | [docs/collections.md](docs/collections.md) |
| **Live MCP tools** | 277 | 6 servers; REA alone supplies 170 | [docs/mcp-servers.md](docs/mcp-servers.md) |
| **Agents** | 4 authored | Domain specialists, not generalists | [docs/agents.md](docs/agents.md) |
| **Slash commands** | 6 | Operational, not ceremonial | [docs/scripts.md](docs/scripts.md) |
| **Maintenance scripts** | 20 | Installers, health checks, updaters, VM discipline | [docs/scripts.md](docs/scripts.md) |
| **Knowledge workspaces** | 2 | `game-lab` (50-game registry), `kernel-sec` (702-driver feed) | [docs/knowledge-workspaces.md](docs/knowledge-workspaces.md) |
| **Analysis engines** | 3 | Ghidra headless, IDA attached, WinDbg | [docs/installation.md](#analysis-engines) |
| **Tools** | 32 · 2.99 GiB | Manifested, installed by script, never vendored | [docs/tools.md](docs/tools.md) |

### Skill roots

OpenCode loads skills from three *configured* roots plus two it discovers by
default. Counting only the configured roots undercounts the catalog by a third —
that bug is documented in [docs/architecture.md](docs/architecture.md#the-counting-bug).

| Root | Count | Loaded via | Source |
| --- | ---: | --- | --- |
| `gameskills/` | 12 | `skills:` in `opencode.jsonc` | [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) |
| `hackskills/` | 93 | `skills:` in `opencode.jsonc` | [yaklang/hack-skills](https://github.com/yaklang/hack-skills) |
| `reaskills/` | 3 | `skills:` in `opencode.jsonc` | REA contributors |
| `~/.agents/skills` | 64 | default discovery | rev-*, ghidra, radare2, pwn-chain, pentest-tools |
| `~/.config/opencode/skills` | 2 | default discovery | `game-security-reverse-engineering`, `luau-roblox-reverse` |

Verified: **zero name collisions** across the five roots, so nothing shadows
anything else.

## Why it is built this way

Four decisions carry the rest. Each one was made against a failure, not a
preference, and each is reversible if you disagree.

### 1. Evidence labels are mandatory, not optional

Every claim is one of **verified**, **reported**, or **inferred**. A repository
membership is not proof of capability. A summary claiming something and source
code showing it are different facts and are written differently.

This is enforced structurally: the `kernel-sec` evidence sheets refuse a claim
that arrives without *a source, a date, affected versions, a confidence, and a
falsifier* — what observation would disprove it. The
[falsifier is operational, not decorative](docs/knowledge-workspaces.md#the-falsifier-convention):
finding a `dbutil_2_3.sys` on disk is **not** evidence of CVE-2021-21551, and the
sheet tells you the exact check that would settle it.

### 2. Instruments must be instrumented

The most expensive lesson in this workspace: **a confident tool produced a wrong
answer and the wrong answer was believed.** The module list was read at the wrong
alignment and trusted at a count that did not fit the buffer. A decompiler
rendering a driver as `return;` was used to conclude a conclusion it could not
distinguish.

So `verify-setup.ps1` executes every tool and prints its banner rather than
resolving its path, rejects `Traceback (most recent call last):` as a success
banner, and bounds every substring. A tool resolving on `PATH` proves nothing.

### 3. Collections are dependencies, never vendored

21.2 GiB across 7 collections. They are cloned, pinned, and re-linked by script.
Vendoring would mean republishing other people's MIT work, would break every
time an upstream moved, and would make the repo unusable.

### 4. Kernel tests happen in a snapshot-able VM, always

Not a scope limit — a rollback discipline. A malformed `.sys` blue-screens the
box. `vmhelper.ps1` provides `snap` / `rollback`, and every driver test runs
inside `ac-test`, a disposable Windows 10 LTSC VM on VirtualBox.

## The instruments

### Health

| Instrument | Answers | Exit code |
| --- | --- | --- |
| `verify-setup.ps1` | Is the toolchain and wiring intact? | always `0` |
| `doctor.py` | Is the running OpenCode installation healthy? | `0` / `1` / `2` |
| `maintain.ps1` | What can be reclaimed, what is stale? | `0` |
| `selfcheck.ps1` (per workspace) | Is this knowledge base consistent? | `0` / `1` |

`doctor.py` is the only one usable as a CI gate — it is the only one that
returns non-zero. It catches the failures that actually stopped work here:
engine version desync, ghost sessions, a bloated plugin cache, sessions that
exceeded 400 messages with zero *completed* compactions, and **client identity
drift** — a PE `TimeDateStamp` mismatch that silently invalidates every offset
you derived yesterday.

### Analysis engines

| Need | Tool | Notes |
| --- | --- | --- |
| Native decompilation | **Ghidra 12.1.4** headless | Default provider, no GUI, no manual step |
| Second opinion | **IDA Pro 9.4** attached | `start-ida-mcp.ps1` opens the binary and starts the bridge |
| Kernel debugging | **WinDbg** | User mode via x64dbg, kernel mode via `windbg`/`cdb`/`kd` |
| What can this binary do | **capa 9.4.0** | Capability map with ATT&CK IDs — run it first on anything unfamiliar |
| Which strings does it hide | **FLOSS 3.1.1** | Stack-built, base64, obfuscated |
| What is protecting it | **DIE 3.10** | Packer / protector identification |
| Strings and imports | **radare2 6.2.4** | `r2`, `rabin2`, `radiff2` |

> [!NOTE]
> Pass an **address** to REA, not a bare function name. A bare name resolves for
> some tools and fails others with `unreadable_output`. `list_procedures` first
> to learn the address space.

### Not installed, and why

| Tool | Reason |
| --- | --- |
| John the Ripper | Openwall publishes Unix source only; no official Windows build. `hashcat` covers it. No third-party mirrors. |
| metasploit, burpsuite, zap | Multi-GB GUI installers, low return against this catalog. |
| frida-server | Only useful against a real Android device; none attached. |
| pentestMCP | Requires Docker, which is absent. |

## Documentation

| Guide | Read it when |
| --- | --- |
| [Installation](docs/installation.md) | Setting up. Full prerequisites, engines, MCP registration. |
| [Architecture](docs/architecture.md) | Understanding how the pieces fit and why. |
| [Methodology](docs/methodology.md) | Adopting the evidence discipline. The core of this repo. |
| [Skills catalog](docs/skills-catalog.md) | Choosing a skill. Routing table and the 174 skills. |
| [Agents](docs/agents.md) | Writing or using a domain agent. |
| [Scripts](docs/scripts.md) | Operating the workbench. All 20, with flags. |
| [MCP servers](docs/mcp-servers.md) | Wiring servers. Active 6, catalogued 34. |
| [Collections](docs/collections.md) | Understanding dependencies. 7 collections, pinned. |
| [Knowledge workspaces](docs/knowledge-workspaces.md) | Extending `game-lab` or `kernel-sec`. |
| [Agentic security](docs/agentic-security.md) | Reviewing your own agent setup for attack surface. |
| [Tools](docs/tools.md) | The 32-tool toolchain: versions, sources, licensing, provisioning. |
| [The working shell](docs/working-shell.md) | One page describing the entire environment. |
| [Troubleshooting](docs/troubleshooting.md) | Something broke. The measured failure modes. |

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). The short version: the evidence
discipline is not negotiable, and a claim without a falsifier will be sent back.

## License

MIT — see [LICENSE](LICENSE).

This project bundles **no third-party source**. It declares upstream
collections as dependencies; their licenses are reproduced in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Collection *membership* is not
endorsement, and is never presented as evidence of capability.

See [DISCLAIMER.md](DISCLAIMER.md) for scope, and [SECURITY.md](SECURITY.md) for
responsible disclosure.
