# Installation

Windows 10/11, PowerShell 5.1+, and a working OpenCode install. The installer
checks everything else.

---

## Quick start

```powershell
git clone https://github.com/gh0st4ace/provenance
cd provenance

.\install.ps1 -DryRun     # print the plan, change nothing
.\install.ps1             # config only
.\install.ps1 -Profile full   # + toolchains, collections, MCP servers
```

Post-install verification:

```powershell
.\scripts\verify-setup.ps1     # toolchain + wiring, always exits 0
py -3 .\scripts\doctor.py      # runtime health, exits 0/1/2
```

---

## Prerequisites

| Requirement | Version | Why | Check |
| --- | --- | --- | --- |
| Windows | 10 / 11 | Scripts target Windows PowerShell 5.1 semantics | `$PSVersionTable` |
| PowerShell | 5.1+ | Encodings and `System.IO.Directory.Delete` differ across editions | bundled |
| Node.js | 20+ | Drives the MCP servers | `node -v` |
| OpenCode | current | The harness itself | `opencode --version` |
| Python | 3.11+ | `doctor.py`, triage and registry scripts | `py -3 -V` |
| Git | current | Collection updates | `git --version` |

**Do not run OpenCode from `C:\WINDOWS\system32`.** Each MCP server is spawned
per working directory, so the tool set doubles. Measured: 368 tools instead of
184.

---

## Profiles

| Profile | Installs | Time |
| --- | --- | --- |
| `-Profile config` (default) | Config templates, agents, commands, scripts | seconds |
| `-Profile full` | + reference collections, RE toolchains, MCP registration | hours (large downloads) |
| `-Profile tools` | + RE toolchains only, skip the 21 GiB collections | ~1 h |

```powershell
.\install.ps1 -Profile tools -DryRun    # see exactly what would be downloaded
```

---

## What the installer does

1. **Detects** existing installs and reports what it found rather than
   overwriting silently.
2. **Stages** into a temp directory, then swaps atomically. A failed install
   never leaves a half-written config.
3. **Parameterizes paths.** Nothing hardcodes `C:\Users\<you>`. The templates in
   `config/` use `${OPENCODE_CONFIG_DIR}` and friends.
4. **Backs up** anything it replaces into `~/.config/opencode/backups/`,
   timestamped.

### Flags

| Flag | Effect |
| --- | --- |
| `-DryRun` | Print every step, write nothing |
| `-Profile <name>` | `config`, `tools`, `full` |
| `-ConfigDir <path>` | Override the install target |
| `-Force` | Replace without backing up |
| `-SkipVerify` | Do not run `verify-setup.ps1` afterwards |

---

## Analysis engines

None are installed by the installer — they are licensed separately or are large
enough that you should choose. Register the ones you have.

### Ghidra (default provider, headless)

```powershell
$env:GHIDRA_INSTALL_DIR = "D:\Tools\ghidra_12.1.4_PUBLIC"
$env:JAVA_HOME           = "D:\Tools\jdk-21.0.12.1+1"
```

Headless, no GUI, no manual step. Requires a JDK. Without it, Ghidra cannot
start and REA will refuse to choose a provider.

### IDA Pro (attached provider)

```powershell
$env:REA_IDA_MCP_CONFIG = "D:\Tools\rea-ida-mcp.json"
```

Attached mode requires a **live IDA GUI with the MCP plugin started**. One
command does both — it opens the binary, sends the plugin hotkey, and waits for
the RPC port:

```powershell
.\scripts\start-ida-mcp.ps1 <path\to\binary>
rea decompile <path\to\binary> 0x140001300 --provider ida --format json
```

> [!WARNING]
> Do not open the IDA GUI unprompted. Nobody asked for a window on their
> desktop. Use Ghidra unless the task is specifically about an IDA database or a
> second opinion.

> [!TIP]
> Pass an **address**, not a bare function name. A bare name resolves for some
> REA tools and fails others with `unreadable_output`.

### Hopper

Not available on Windows — macOS and Linux only. REA's setup can offer to
install it, but it will not run here.

---

## RE toolchains

Opt-in; each is large and each is a real dependency of a skill.

```powershell
.\scripts\install-missing-tools.ps1    # pass 1 — highest-frequency gaps
.\scripts\install-missing-tools2.ps1   # pass 2 — second tier
.\scripts\install-missing-tools3.ps1   # pass 3 — repairs bugs pass 2 shipped
.\scripts\install-game-tools.ps1       # game/IL2CPP/.NET stack
.\scripts\install-triage-tools.ps1     # capa, FLOSS, LIEF, DIE
```

> [!IMPORTANT]
> The three `install-missing-tools` scripts are **sequential passes over one
> measured gap list, not three scopes**. Run them in order 1 → 2 → 3. Pass 3
> exists specifically to repair four bugs pass 2 shipped — including a `httpx`
> shim that matched by filename and captured an unrelated Python client. Pass 3
> wins where they overlap.

Full detail in [scripts.md](scripts.md#installers).

---

## MCP servers

Six are active. Copy the block you want from `config/opencode.jsonc.template`
into your own `mcp.servers`.

| Server | Tools | Needs |
| --- | ---: | --- |
| `rea` | 170 | Ghidra (headless) or the IDA bridge |
| `cheat-mcp` | 72 | Built from source; elevation for most operations |
| `js-reverse` | 24 | Node |
| `jshook` | 8 | Node |
| `context7` | 2 | Node |
| `renderdoc` | — | A `.rdc` capture |

**Total live: 277 tools.** That is already a lot of context per step. A separate
catalogued set of 34 candidates lives in [mcp-servers.md](mcp-servers.md) — it is
a **menu, not a config**. Nothing in it is running.

> [!NOTE]
> `cheat-mcp` reports `is_admin: false` by default and has its own
> `elevate` / `run_elevated` tools. Prefer the non-elevated path; do not trigger
> a UAC prompt unless the operator asked for it.

---

## Skill roots

Five. Three are configured explicitly, two are discovered by default.

```jsonc
// config/opencode.jsonc.template
"skills": [
  "${CONFIG_DIR}/gameskills",
  "${CONFIG_DIR}/hackskills",
  "${CONFIG_DIR}/reaskills"
]
```

The junction-creating scripts populate them:

```powershell
.\scripts\sync-awgs-skills.ps1        # 12 game-security junctions
.\scripts\update-hack-skills.ps1      # 93 hack-skill junctions, prunes stale
```

Verify with:

```powershell
(Get-ChildItem "$env:USERPROFILE\.config\opencode\gameskills").Count   # 12
(Get-ChildItem "$env:USERPROFILE\.config\opencode\hackskills").Count   # 93
(Get-ChildItem "$env:USERPROFILE\.config\opencode\reaskills").Count    # 3
```

---

## Post-install checklist

```powershell
.\scripts\verify-setup.ps1
```

Expect green on: config JSON parses, 12/93/3 junctions, 7 collections present,
Ghidra + JDK reachable, REA provider selectable, memory store present, all CLI
tools executing, all Python libraries importing.

Anything red is explained in [troubleshooting.md](troubleshooting.md).

---

## Uninstall

```powershell
.\install.ps1 -Uninstall -DryRun
.\install.ps1 -Uninstall
```

Restores from `~/.config/opencode/backups/`. Does **not** delete reference
collections — pass `-PurgeCollections` for that, after confirming you want the
21 GiB gone.
