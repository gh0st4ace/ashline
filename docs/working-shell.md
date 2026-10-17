# The working shell

One page describing everything this repository captures. Every number here is
read from disk or generated from a manifest, not typed by hand.

---

## Shape

| Layer | Count | Where it lives | Vendored? |
| --- | ---: | --- | --- |
| **Tools** | 32 · 2.99 GiB | `D:\Tools` | no — manifest + installers |
| **Skills** | 174 | 5 discovery roots | partly — 5 authored here |
| **Commands** | 103 + 6 own | `~/.config/opencode` + config | 6 yes, 103 via ECC |
| **Reference collections** | 7 · 21.2 GiB | `D:\opencode` | no — pinned clones |
| **MCP servers** | 6 active · 34 catalogued | `opencode.jsonc` | no |
| **Live MCP tools** | 277 | — | — |
| **Agents** | 4 authored | `agents/` | **yes** |
| **Scripts** | 21 | `scripts/` | **yes** |
| **Knowledge workspaces** | 2 | `knowledge/` | **yes** |

**Total measured footprint: ~24 GiB across two roots, reproduced from a 1 MB
repository.** That ratio is the design, not a compromise — see
[tools.md](tools.md#why-299-gib-is-not-in-the-repository).

---

## 1. Tools — 32

Full table with versions, sources, licenses, and which installer provides each:
**[docs/tools.md](tools.md)**. Machine-readable:
[`config/tool-manifest.json`](../config/tool-manifest.json).

```powershell
.\scripts\install-all-tools.ps1 -What toolchain -DryRun   # plan
.\scripts\install-all-tools.ps1 -What toolchain           # install
```

Order matters — passes 1→2→3 are one gap list, and pass 3 repairs four bugs
pass 2 shipped. Full explanation in [tools.md](tools.md#order-is-load-bearing).

---

## 2. Skills — 174

Five discovery roots. Counting only the three configured ones undercounts by a
third; that error is documented in
[architecture.md](architecture.md#the-counting-bug).

| Root | Count | Loaded via | Source |
| --- | ---: | --- | --- |
| `gameskills/` | 12 | `skills:` | gmh5225/awesome-game-security |
| `hackskills/` | 93 | `skills:` | yaklang/hack-skills |
| `reaskills/` | 3 | `skills:` | REA contributors |
| `~/.agents/skills` | 64 | default | mixed upstream |
| `~/.config/opencode/skills` | 2 | default | local |
| **`.agents/skills` in this repo** | **5** | — | **authored here** |

The 5 authored: `game-engine-detection`, `game-memory-lab`, `game-modding-lab`,
`anti-cheat-architecture`, `game-research-tool-discovery`.

**Loading is a protocol, not a keyword match.** Load `overview` only for
collection questions, then exactly one domain skill — two only when two
boundaries genuinely dominate. Ten `hack-skills` routers are deliberately
off-catalog because their catch-all descriptions win the match on nearly every
task and then apply their own gate. See
[skills-catalog.md](skills-catalog.md).

---

## 3. Commands — 103 + 6

ECC supplies 103. The **6 operational ones are defined in
`config/opencode.jsonc.template`** instead, so they survive an ECC update:

| Command | Does |
| --- | --- |
| `/verify` | Whole-stack health check. **Changes nothing before you see the output** |
| `/doctor` | Runtime health, tri-state. The only non-zero-exit instrument, so the only CI-usable one |
| `/stack` | One-screen status of skills, collections, engines, memory, what is broken |
| `/refresh` | Runs the three updaters in order, then `verify-setup.ps1` |
| `/re <path> [addr]` | REA. Requires an **address**, not a bare function name |
| `/state` | Project summary without reading a multi-thousand-line handoff |

---

## 4. Reference collections — 7 · 21.2 GiB

| Alias | Size | Fetch method |
| --- | ---: | --- |
| `awesome-game-security` | 3.05 GiB | blobless sparse partial clone |
| `game-security-archive` | 18.19 GiB | **tarball, not git** — lazy-blob stalls at this size |
| `hack-skills` | 0.01 GiB | clone |
| `cyber-skills` | 0.04 GiB | clone (818 skills, 291 MITRE techniques) |
| `game-hacking-refs` | <0.01 GiB | clone |
| `hacking-online-games` | 0.06 GiB | clone |
| `rea` | 0.01 GiB | clone |

Pinned to real commits in [`collections.lock.json`](../collections.lock.json).
Every one is `edit: deny` in the permission matrix — the deny is the
load-bearing half. Full detail: [collections.md](collections.md).

---

## 5. MCP servers — 6 active · 34 catalogued · 277 tools

| Server | Tools | Needs |
| --- | ---: | --- |
| `rea` | 170 | Ghidra headless, or the IDA bridge |
| `cheat-mcp` | 72 | built from source; elevation for most ops |
| `js-reverse` | 24 | Node |
| `jshook` | 8 | Node |
| `context7` | 2 | Node |
| `renderdoc` | — | a `.rdc` capture |

The 34-server catalog in `config/mcp-servers.json.template` is a **menu, not a
config** — Claude Code's schema, all credentials placeholder, nothing running.
Full detail: [mcp-servers.md](mcp-servers.md).

Every version pinned. `@latest` re-resolves on every load and left 746 MB of
staging debris.

---

## 6. Third-party catalog — ECC

`config/ecc-surface.json` is a generated manifest:

| Surface | Count | Vendored |
| --- | ---: | --- |
| Skills | 315 | no — via `scripts/update-ecc.ps1` |
| Commands | 103 | no — same |
| Custom tools | 9 | no |
| Plugins | 2 | `ecc-v2-shim/` holds the v2 adaptations |
| Hook definitions | 4 + 2 subdirs | no |

`install.ps1` fetches this on `-Profile tools`/`full`, because without it a
fresh install **looks broken**: config layer present, skill catalog empty.
That is the most likely first-run failure.

---

## 7. Agents — 4 authored

| Agent | Role |
| --- | --- |
| `spacebunnyjb` | Default operator agent; reasoning-effort discipline |
| `gamesec` | Game-security research; reads real sources before answering |
| `kernel-driver-analyst` | Windows drivers / BYOVD; static, passive-first, VM-only dynamic |
| `ksec-validator` | Independent falsification — restates the claim, then tries to break it |

The validator exists because shared context produces correlated error. Two
agents that agree are close to worthless. Full detail: [agents.md](agents.md).

---

## 8. Scripts — 21

| Group | Scripts |
| --- | --- |
| Health | `verify-setup.ps1`, `doctor.py`, `maintain.ps1` |
| Installers | `install-missing-tools.ps1` / `2` / `3`, `install-game-tools.ps1`, `install-triage-tools.ps1` |
| Toolchain | `install-all-tools.ps1` (orchestrator), `export-portable-bundle.ps1` |
| Updaters | `update-awgs.ps1`, `update-awgs-archive.ps1`, `update-hack-skills.ps1`, `sync-awgs-skills.ps1`, `update-ecc.ps1` |
| Launchers | `run-awgs-update.cmd`, `run-awgs-archive.cmd` |
| Fixers | `fix-ida-shadow.ps1`, `fix-ghost-sessions.ps1` |
| Environment | `start-ida-mcp.ps1`, `vmhelper.ps1`, `devshell.cmd` |

`doctor.py` is the only script returning non-zero, which makes it the only one
usable as a CI gate. Full detail: [scripts.md](scripts.md).

---

## 9. Knowledge workspaces — 2

| Workspace | Holds | Admission rule |
| --- | --- | --- |
| `game-lab` | 50-game registry (22 fields, confidence-tagged, validator-enforced), engine fingerprint, discovery sheet, self-built MSVC bench | `unknown` beats a plausible guess |
| `kernel-sec` | Evidence sheets, passive `driver_triage.py`, 702-driver feed query | source + date + versions + confidence + **falsifier** |

Full detail: [knowledge-workspaces.md](knowledge-workspaces.md).

---

## Reproduce the shell

```powershell
git clone https://github.com/gh0st4ace/ashline
cd ashline

.\install.ps1 -DryRun              # the plan, writes nothing
.\install.ps1 -Profile full        # config + ECC + collections + skill links
.\scripts\install-all-tools.ps1    # the 32 tools, in the order that matters

.\scripts\verify-setup.ps1         # prove the toolchain
py -3 .\scripts\doctor.py          # prove the runtime
```

Start OpenCode from a normal project directory. **Not**
`C:\WINDOWS\system32` — each MCP server is spawned per working directory and
the tool set doubles there (measured: 368 instead of 184).

---

## Integrity

```powershell
npm run rebuild     # sanitize -> neutralize-assets -> fix-ps1-encoding -> gate
```

| Gate | Catches |
| --- | --- |
| Secrets and identity | credentials, absolute user paths, operator name |
| JSON validity | malformed manifests |
| PowerShell parse | syntax breakage from path substitution |
| Python compile | syntax breakage |
| PowerShell encoding | non-ASCII without a BOM (PS 5.1 reads ANSI and a mangled byte can end a string literal) |
| PowerShell runtime | sigil-less variables, which parse fine and fail only when executed |
| Internal links | dead relative links, and VitePress routes with no page |
| Required files | a missing manifest or orchestrator |
| Repository size | anything that would exceed GitHub's 100 MB limit |

Current: **10/10 pass, 21 `.ps1` parse, 12 `.py` compile, all links resolve.**