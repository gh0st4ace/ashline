<div align="center">

# ‹› Ashline ‹›

### One hardened OpenCode setup for reverse engineering, game security, and driver research.

**A field-tested environment you install instead of rebuilding.**

<br/>

[![Skills](https://img.shields.io/badge/skills-174-5c4ee5?style=for-the-badge)](docs/skills-catalog.md)
[![MCP tools](https://img.shields.io/badge/live_MCP_tools-277-3b82f6?style=for-the-badge)](docs/mcp-servers.md)
[![Tools](https://img.shields.io/badge/tools-32-8250df?style=for-the-badge)](docs/tools.md)
[![Collections](https://img.shields.io/badge/collections-7·21.2_GiB-d73a4a?style=for-the-badge)](docs/collections.md)
[![Scripts](https://img.shields.io/badge/scripts-23-bfd4f2?style=for-the-badge)](docs/scripts.md)
[![Gates](https://img.shields.io/badge/release_gates-11/11-4c1_3b82f6?style=for-the-badge)](tools/gate.py)

[![Windows](https://img.shields.io/badge/platform-Windows_10/11-0078d4?style=for-the-badge&logo=windows&logoColor=white)](docs/installation.md)
[![License](https://img.shields.io/badge/license-MIT-f4c430?style=for-the-badge)](LICENSE)
[![Third party](https://img.shields.io/badge/third_party-none_vendored-6f42c1?style=for-the-badge)](THIRD_PARTY_NOTICES.md)

<br/>

**English** · **[Русский](README.ru.md)**

<br/>

```powershell
git clone https://github.com/gh0st4ace/ashline
cd ashline
.\install.ps1 -DryRun     # print the plan — writes nothing
```

<br/>

[⚡ Quick start](#quick-start) &nbsp;·&nbsp; [📦 What is in the box](#what-is-in-the-box) &nbsp;·&nbsp; [🧭 Why it is built this way](#why-it-is-built-this-way) &nbsp;·&nbsp; [🔬 The instruments](#the-instruments) &nbsp;·&nbsp; [📚 Documentation](#documentation)

</div>

---

> [!IMPORTANT]
> **This repository ships the contract, not the gigabytes.** ~24 GiB of toolchain
> and reference collections are described down to the version, source URL,
> license, installing script and dependent skill — then fetched by script. The
> repository itself is **under 1 MB** and reproduces the whole thing.
> Nothing third-party is vendored. See [why](#why-not-vendor-the-gigabytes).

---

## ⚡ Quick start

```powershell
# 1 · preview — prints every step, writes nothing
.\install.ps1 -DryRun

# 2 · install the full environment
.\install.ps1 -Profile full

# 3 · the 32 tools, in the order that matters
.\scripts\install-all-tools.ps1 -What toolchain

# 4 · prove it
.\scripts\verify-setup.ps1     # toolchain:  always exits 0
py -3  .\scripts\doctor.py     # runtime:    exits 0 / 1 / 2
```

`verify-setup.ps1` and `doctor.py` do not overlap — the first checks the
**toolchain**, the second the **running install**. Only `doctor.py` returns
non-zero, which makes it the only one usable as a CI gate.

<div align="center">

| | |
|:---|:---|
| ⏱️ `-Profile config` | seconds |
| ⏱️ `-Profile tools` | ~1 hour, no collections |
| ⏱️ `-Profile full` | hours — 21.2 GiB of collections dominates |

</div>

> [!WARNING]
> Start OpenCode from a **normal project directory**. Never from
> `C:\WINDOWS\system32` — each MCP server is spawned per working directory, so
> the tool set doubles there. Measured: **368 tools instead of 184**.

---

## 📦 What is in the box

<div align="center">

| Layer | Count | Vendored? |
|:--|--:|:--:|
| 🧰 **Tools** | 32 · 2.99 GiB | manifest + installers |
| 🧠 **Skills** | 174 across 5 roots | 5 authored here |
| 🔌 **MCP servers** | 6 live · 277 tools | config only |
| 📚 **Reference collections** | 7 · 21.2 GiB | pinned clones |
| 📝 **Commands** | 103 + 6 own | 6 here |
| 🤖 **Agents** | 4 authored | ✅ all |
| ⚙️ **Scripts** | 23 | ✅ all |
| 📖 **Documentation** | 15 guides | ✅ all |
| 🗄️ **Knowledge bases** | 2 | ✅ all |

</div>

### 🔬 The environments it reproduces

```
D:\opencode   22.36 GiB   21.24 GiB of it other people's repos
D:\Tools       8.32 GiB   the tools (4.67 GiB of it VM media)
repository     0.99 MiB   what ships
```

**24 GiB, from under 1 MB.** The ratio is the design.

<details>
<summary><b>📂 The reference collections — 7 · 21.2 GiB</b></summary>

| Collection | Size | What it holds |
|---|---:|---|
| `awesome-game-security` | 3.05 GiB | ~40,871 project summaries, 4,105 wiki pages, 13 domain skills |
| **`game-security-archive`** | **18.19 GiB** | **4,086 flat `<owner>/<repo>.txt` files** — one per indexed project, containing its source tree *and* file contents. Fetched as a **tarball, not git**: lazy-blob fetching stalls at this size. Atomic directory swap, 7-day cache gate |
| `hack-skills` | 0.01 GiB | 103 practical security skills |
| `cyber-skills` | 0.04 GiB | 818 skills, 291 MITRE techniques |
| `game-hacking-refs` | <0.01 GiB | curated game-RE tutorials |
| `hacking-online-games` | 0.06 GiB | GameGuard, server-side emulation, pointer scanning, 8 PDFs |
| `rea` | 0.01 GiB | 170-tool MCP server; provider and platform guides |

Every one is pinned to a real commit in
[`collections.lock.json`](collections.lock.json), granted `read` and
**`edit: deny`**, and fetched by script.
Full detail → [docs/collections.md](docs/collections.md)

</details>

<details>
<summary><b>🧠 Skill roots — 174 across five, not three</b></summary>

OpenCode loads from three *configured* roots plus two it discovers by default.
Counting only the configured three **undercounts the catalog by a third** — a
bug this repository documents rather than repeats.

| Root | Count | Loaded via |
|---|---:|---|
| `gameskills/` | 12 | `skills:` in `opencode.jsonc` |
| `hackskills/` | 93 | `skills:` in `opencode.jsonc` |
| `reaskills/` | 3 | `skills:` in `opencode.jsonc` |
| `~/.agents/skills` | 64 | default discovery |
| `~/.config/opencode/skills` | 2 | default discovery |

Verified **zero name collisions** across all five.

Routing is a **protocol, not a keyword match**: load exactly one domain skill,
two only when two boundaries genuinely dominate. Ten `hack-skills` routers are
deliberately off-catalog because their catch-all descriptions win the match on
nearly every task and then apply their own gate.
→ [docs/skills-catalog.md](docs/skills-catalog.md)

</details>

<details>
<summary><b>🔌 MCP servers — 6 live · 277 tools</b></summary>

| Server | Tools | Needs |
|---|---:|---|
| `rea` | 170 | Ghidra headless, or the IDA bridge |
| `cheat-mcp` | 72 | built from source; elevation for most operations |
| `js-reverse` | 24 | Node |
| `jshook` | 8 | Node |
| `context7` | 2 | Node |
| `renderdoc` | — | a `.rdc` capture |

A further 34 candidates are **catalogued, not configured** — that file is a
menu with placeholder credentials and Claude Code's schema, so nothing in it is
running. Every version pinned: `@latest` re-resolves on each load and left
746 MB of staging debris behind.
→ [docs/mcp-servers.md](docs/mcp-servers.md)

</details>

<details>
<summary><b>🗄️ Knowledge workspaces — 2</b></summary>

| Workspace | Holds | Admission rule |
|---|---|---|
| `game-lab` | 50-game registry (22 fields, confidence-tagged, validator-enforced), engine fingerprinting, a self-built MSVC bench | `unknown` beats a plausible guess |
| `kernel-sec` | Evidence sheets, passive `driver_triage.py`, a 702-driver feed | source + date + versions + confidence + **falsifier** |

→ [docs/knowledge-workspaces.md](docs/knowledge-workspaces.md)

</details>

---

## 🧭 Why it is built this way

Four decisions carry everything else. Each was made against a **failure**, not a
preference — and each is reversible if you disagree.

### 1️⃣ Evidence labels are mandatory

Every claim is **verified**, **reported**, or **inferred**. Membership in a
collection is not proof of capability; a summary claiming something and source
code showing it are different facts and are written differently.

Enforced structurally: the `kernel-sec` evidence sheets refuse a claim arriving
without *a source, a date, affected versions, a confidence, and a falsifier* —
the observation that would disprove it.

> The falsifier is **operational**, not decorative: finding a `dbutil_2_3.sys`
> on disk is **not** evidence of CVE-2021-21551, and the sheet tells you the
> exact check that would settle it.

### 2️⃣ Instruments must be instrumented

The most expensive lesson here: **a confident tool produced a wrong answer, and
the wrong answer was believed.** A module list was read at the wrong alignment
and trusted at a count that did not fit the buffer. A decompiler rendering a
driver as `return;` was used to support a conclusion it could not distinguish.

So `verify-setup.ps1` **executes** every tool and prints its banner rather than
resolving its path, rejects `Traceback (most recent call last):` as success, and
bounds every substring.

> A tool resolving on `PATH` proves nothing. Resolution ≠ working.

### 3️⃣ Collections are dependencies, never vendored

21.2 GiB across 7 collections. Cloned, pinned, re-linked by script. Vendoring
would republish other people's MIT work, break on every upstream commit, and
exceed GitHub's 100 MB per-file limit outright.

#### 🗄️ Why not vendor the gigabytes

| Barrier | Detail |
|---|---|
| **GitHub's limit** | 100 MB per file. Ghidra is 865 MiB, hashcat 371, JDK 328, Sysinternals 272, dnSpy 203 |
| **License** | IDA Pro is commercial. The Windows SDK and Sysinternals are under EULA |
| **Provenance** | Most of it is a vendor's distributed build, not your source. Repackaging is not sharing |
| **Staleness** | A committed binary never updates. The pinned installer always can |

So the repository ships the **contract** — every tool, version, source, license,
installing script, and dependent skill — plus the installers, plus
`export-portable-bundle.ps1` for the cases where binaries genuinely must move.

### 4️⃣ Kernel tests happen in a snapshot-able VM, always

Not a scope limit — **a rollback discipline**. A malformed `.sys` blue-screens
the machine, and a snapshot is the only cheap way back. `vmhelper.ps1` provides
`snap` / `rollback`; every driver test runs inside `ac-test`, a disposable
Windows 10 LTSC VM on VirtualBox.

---

## 🔬 The instruments

### 🩺 Health

| Instrument | Answers | Exit |
|---|---|---|
| `verify-setup.ps1` | Is the toolchain and wiring intact? | always `0` |
| `doctor.py` | Is the running OpenCode install healthy? | `0` / `1` / `2` |
| `maintain.ps1` | What can be reclaimed, what is stale? | `0` |
| `selfcheck.ps1` | Is this knowledge base consistent? | `0` / `1` |

`doctor.py` catches the failures that **actually stopped work here**: engine
version desync, ghost sessions, a bloated plugin cache, sessions past 400
messages with zero *completed* compactions, and **client identity drift** — a PE
`TimeDateStamp` mismatch that silently invalidates every offset you derived
yesterday.

### 🔧 Analysis engines

| Need | Tool |
|---|---|
| Native decompilation | **Ghidra 12.1.4** headless — default provider, no GUI, no manual step |
| Second opinion | **IDA Pro 9.4** attached via `start-ida-mcp.ps1` |
| Kernel debugging | **WinDbg** · user mode via x64dbg |
| What can this binary do | **capa 9.4.0** — run it *first* on anything unfamiliar |
| Which strings does it hide | **FLOSS 3.1.1** — stack-built, base64, obfuscated |
| What is protecting it | **DIE 3.10** — packer / protector identification |

> [!TIP]
> Pass REA an **address**, not a bare function name. A bare name resolves for
> some tools and fails others with `unreadable_output`. Start with
> `list_procedures`.

### 🚫 Not installed, and why

| Tool | Reason |
|---|---|
| John the Ripper | Openwall publishes Unix source only — no official Windows build. `hashcat` covers it. No third-party mirrors. |
| metasploit · burpsuite · zap | Multi-GB GUI installers, low return against this catalog |
| frida-server | Only useful against a real Android device |
| pentestMCP | Requires Docker, which is absent |

---

## 📚 Documentation

| Guide | Read it when |
|---|---|
| [🟢 Will it work for me?](docs/will-it-work.md) | **Start here** — what works, what does not, and what is *unverified* |
| [📥 Installation](docs/installation.md) | Setting up — prerequisites, engines, MCP registration |
| [🏗️ Architecture](docs/architecture.md) | How the pieces fit and why |
| [🔬 Methodology](docs/methodology.md) | Adopting the discipline — **the core of this repo** |
| [📋 The working shell](docs/working-shell.md) | The entire environment on one page |
| [🧰 Tools](docs/tools.md) | The 32-tool toolchain: versions, sources, licensing, provisioning |
| [📚 Skills catalog](docs/skills-catalog.md) | Choosing a skill — routing tables and all 174 |
| [🔌 MCP servers](docs/mcp-servers.md) | Wiring servers — 6 active, 34 catalogued |
| [📂 Collections](docs/collections.md) | Dependencies — 7 collections, pinned |
| [🤖 Agents](docs/agents.md) | Writing or using a domain agent |
| [⚙️ Scripts](docs/scripts.md) | Operating the environment — all 23, with flags |
| [🗄️ Knowledge workspaces](docs/knowledge-workspaces.md) | Extending `game-lab` or `kernel-sec` |
| [🛡️ Agentic security](docs/agentic-security.md) | Reviewing your own agent setup for attack surface |
| [🩹 Troubleshooting](docs/troubleshooting.md) | Something broke — the measured failure modes |
| [📖 Worked example](examples/worked-example.md) | One problem, from symptom to written finding |

---

## 🛡️ Release gates

`npm run rebuild` — sanitize → neutralize assets → fix encodings → gate. The
gates fail the build, and each one exists because of a real defect:

| Gate | Catches |
|---|---|
| Secrets and identity | credentials, absolute user paths, operator names |
| Stray control characters | BEL and zero-width injected by a failed encoding round-trip |
| JSON validity | malformed manifests |
| PowerShell parse | syntax breakage from path substitution |
| Python compile | syntax breakage |
| PowerShell encoding | non-ASCII without a BOM — PS 5.1 reads ANSI, and a mangled byte can end a string literal |
| PowerShell runtime | sigil-less variables, which parse cleanly and fail only when executed |
| Internal links | dead relative links, and site routes with no page |
| Required files | a missing manifest or orchestrator |
| Repository size | anything exceeding GitHub's 100 MB limit |

Each gate was **verified by a negative control** — a planted defect must make it
fail. A gate never shown failing is not a gate.

---

## 📄 License

**MIT** — see [LICENSE](LICENSE).

This project bundles **no third-party source**. It declares upstream
collections as dependencies; their licenses are reproduced in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

> Collection *membership* is not endorsement, and is never presented as
> evidence of capability.

Scope → [DISCLAIMER.md](DISCLAIMER.md) · Disclosure → [SECURITY.md](SECURITY.md) · Contributing → [CONTRIBUTING.md](CONTRIBUTING.md)

<div align="center">

---

**Made for people who would rather measure twice than publish once.**

</div>