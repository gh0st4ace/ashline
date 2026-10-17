# Tools

The complete inventory of the working shell: 32 tools, 2.99 GiB, every one
installed, none of it vendored.

Generated contract: [`config/tool-manifest.json`](../config/tool-manifest.json) —
scanned from disk, not hand-maintained. Regenerate with
`py -3 tools/gen-tool-manifest.py`.

---

## Why 2.99 GiB is not in the repository

| Reason | Detail |
| --- | --- |
| **GitHub's limit** | 100 MB per file. Ghidra is 865 MiB, hashcat 371 MiB, Sysinternals 272 MiB, JDK 328 MiB, dnSpy 203 MiB. Not close. |
| **License** | IDA Pro is commercial. The Windows SDK and Sysinternals are under EULA. Redistributing a vendor's binary is repackaging, not sharing. |
| **Ashline** | Most of it is a vendor's distributed build, not your source. Committing it adds nothing the vendor's release page does not already provide. |
| **Staleness** | A committed binary never updates. The pinned installer always can. |

What ships instead is the **contract**: every tool, its role, source, license,
which installer provides it, and which skills depend on it. Plus the installers
themselves, and a portable exporter for offline transport.

---

## Provisioning

```powershell
# everything, in the order that matters
.\scripts\install-all-tools.ps1 -What toolchain

# subsets
.\scripts\install-all-tools.ps1 -What triage      # capa, DIE, upx, radare2
.\scripts\install-all-tools.ps1 -What game        # IL2CPP / .NET / game
.\scripts\install-all-tools.ps1 -What python      # passes 1-3 only

# see the plan, install nothing
.\scripts\install-all-tools.ps1 -DryRun
```

### Order is load-bearing

The three `install-missing-tools` scripts are **sequential passes over one
measured gap list, not three scopes**:

| Pass | Provides | Known defect |
| --- | --- | --- |
| 1 | nmap, rizin, jadx, radare2, hashcat, apktool; sqlmap, frida-tools, binwalk, capstone, uncompyle6, volatility3 | none |
| 2 | impacket, objection, pwntools; nuclei, httpx, ffuf, gobuster; upx, john, Sysinternals, de4dot | **four bugs, repaired by pass 3** |
| 3 | repairs pass 2 | the actual fix |

Pass 3 is not optional. Its header names what pass 2 shipped:

1. `httpx` matched by **filename** and captured the Python `httpx` client inside
   `ida-pro-mcp-venv`
2. `releases/latest/download/<asset>` is invalid where the asset sits under a
   tag-specific path — a 404 HTML page was written to disk as if it were a tool
3. Sysinternals extracted 164 files with **zero** shims
4. impacket ships `.py` entry points, not `.exe`, on this Python install

It deletes the bad shim first, then re-fetches with tag-pinned URLs (nuclei
v3.11.1, httpx v1.12.0, ffuf v2.3.0, gobuster v3.8.2, upx v5.2.1) and adds 16
Sysinternals + 12 impacket shims. **Pass 3 overlaps pass 2 and wins.**

---

## Native analysis

| Tool | Version | Role | Provided by | Vendoring |
| --- | --- | --- | --- | --- |
| **Ghidra** | 12.1.4 | Native decompilation. **Default REA provider**, headless | manual | no — 865 MiB |
| **JDK** | Temurin 21.0.12 | Ghidra cannot start without it | manual | no — 328 MiB |
| **radare2** | 6.2.4 | `r2`, `rabin2`, `radiff2` | pass 1 | via script — 41 MiB |
| **x64dbg** | — | User-mode debugger; Scylla in its snapshot | manual | no — 81 MiB |
| **dnSpy** | — | .NET decompiler; `dnSpy.Console` headless | manual, shims in pass 3 | no — 203 MiB |
| **dnlib + AsmResolver** | — | Assembly read/write, netstandard2.0/net6/net8/net9 | `install-game-tools.ps1` (**built** via `dotnet`) | regenerable — 1.2 MiB |
| **WinDbg** | SDK | Kernel debugging: `windbg`, `cdb`, `kd` | Windows SDK | no — EULA |

> **Provider note.** `REA_ANALYSIS_PROVIDER=ghidra` is persisted. Without it REA
> refuses to choose and reports `Multiple analysis providers support this
> target` — it counts a provider available by *registration*, not by a live
> bridge. IDA is attached mode and needs `start-ida-mcp.ps1` first.

---

## Binary triage

**Run capa first on anything unfamiliar.** It maps capability in minutes what
manual reading takes hours.

| Tool | Version | Role | Provided by |
| --- | --- | --- | --- |
| **capa** | 9.4.0 | Capability map with ATT&CK IDs | `install-triage-tools.ps1` |
| **DIE** | 3.10 | Packer / protector / compiler ID | same (live API — **unpinned**) |
| **FLOSS** | 3.1.1 | Stack-built, base64, obfuscated strings | same (pip `flare-floss`) |
| **LIEF** | 1.0.0 | PE/ELF/Mach-O scripting and editing | same (pip) |
| **upx** | 5.2.1 | Packing and unpacking | pass 2, fixed by pass 3 |
| **de4dot** | — | .NET deobfuscation | pass 2 |
| **Sysinternals** | 164 exe | Process, driver, system inspection | pass 2, shims in pass 3 |

---

## Game / modding / .NET

| Tool | Role | Provided by |
| --- | --- | --- |
| **Cheat Engine 7.7** | Memory editor; `ceserver` for scripted access | `install-game-tools.ps1` |
| **Il2CppDumper** 6.7.46 | Unity IL2CPP metadata and symbols | same |
| **Cpp2IL** | Alternative IL2CPP → managed converter | same |
| **ReClass.NET** | Class and struct reconstruction | manual |
| **cheat-mcp** | 72-tool MCP: memory read/write/scan, pointer chains, DLL injection, IAT hooking, AC detection | manual build |

### cheat-mcp is built from source, and carries a local patch

Upstream omits `#include <mstcpip.h>` in `src/network.cpp`, which breaks the
`SIO_RCVALL` call. That include is **a local fix and will conflict on a fresh
`git pull`**. Not redistributed here.

Reports `is_admin: false` by default and exposes `elevate` / `run_elevated`
separately. Prefer the non-elevated path; do not trigger UAC unprompted.

---

## Web and recon

| Tool | Version | Role | Provided by |
| --- | --- | --- | --- |
| **nuclei** | 3.11.1 | Template-driven scanning | pass 2, fixed by pass 3 |
| **httpx** | 1.12.0 | HTTP prober | pass 2, fixed by pass 3 |
| **ffuf** | 2.3.0 | Fuzzing, content discovery | pass 2, fixed by pass 3 |
| **gobuster** | 3.8.2 | Directory and DNS enumeration | pass 2, fixed by pass 3 |
| **hashcat** | 7.1.2 | GPU password cracking | pass 1 |
| **nmap** | — | Network recon | pass 1 (winget) |
| **sqlmap** | — | SQL injection tooling | pass 1 (pip) |

> **John the Ripper is deliberately absent.** Openwall publishes Unix source
> only; there is no official Windows build, and the site points Windows users
> elsewhere. hashcat covers it. No third-party mirror is used.

---

## Reverse-engineering platform support

| Tool | Role | Provided by |
| --- | --- | --- |
| **unluau** | Luau bytecode decompiler | manual |
| **luau** | Luau runtime and CLI | manual |
| **ghidra-mcp** | **REJECTED** — REA already supplies 170 tools including a Ghidra provider, and the extension name collides with the local fork | do not install |
| **pdbfetch** | PDB and symbol field lookup | manual |

---

## MCP servers and Python environments

| Component | Size | Role | Vendoring |
| --- | --- | --- | --- |
| **ida-pro-mcp-venv** | 69 MiB | venv for the ida-pro-mcp 1.4.0 bridge REA's attached provider needs | regenerable via `pip install` into a venv |
| **renderdoc-mcp** | 18 MiB | RenderDoc MCP server | via script |
| **renderdoc-mcp-bin** | 80 MiB | RenderDoc MCP prebuilt distribution | via script |
| **luau-decompiler** | 231 MiB | Extended Luau decompilation | **not shipped — license unverified** |

---

## Not tools

| Payload | Size | Note |
| --- | --- | --- |
| `D:\Tools\iso` | 4.67 GiB | VM test media. Not redistributable, and not in any bundle profile |

---

## Offline transport

Git cannot carry this, but a colleague's machine can get it. This is the other
channel, deliberately separate from the repository:

```powershell
.\scripts\export-portable-bundle.ps1 -What triage -DryRun   # plan
.\scripts\export-portable-bundle.ps1 -What triage           # write the zip
.\scripts\export-portable-bundle.ps1 -What all              # ~3 GiB
```

| Profile | Contents | Size |
| --- | --- | ---: |
| `triage` | capa, DIE, upx, radare2, dnlib, de4dot | ~0.13 GiB |
| `re` | decompilers and debuggers | ~1.8 GiB |
| `game` | IL2CPP / .NET / game tooling | ~0.25 GiB |
| `all` | everything except VM media | ~3 GiB |

Excluded by default as not redistributable without review: `TitanHide`,
`kdmapper`, `cheat-mcp`, `luau-decompiler`, `reverify`, `lib`,
`ida-pro-mcp-venv`. `-IncludeUnsafe` overrides, and **then compliance is on
you** — the script says so in the accompanying README it writes next to the zip.

> If in doubt, share the **repository**, not the archive. 1 MB reproduces the
> toolchain from pinned sources and carries no licensing question.

---

## Environment variables

Every installer resolves its own paths, so the toolchain relocates without
editing scripts:

```powershell
$env:WB_TOOLS_DIR       = 'D:\Tools'      # default
$env:WB_COLLECTIONS_DIR = 'D:\opencode'  # default
$env:WB_CONFIG_DIR      = "$env:USERPROFILE\.config\opencode"
$env:WB_GAME_CLIENT     = 'H:\SteamLibrary\steamapps\common\DayZ\DayZ_x64.exe'
```

The `.cmd` launchers additionally read `%WB_*%`, because Task Scheduler runs
under SYSTEM where `%USERPROFILE%` is the system profile — which is exactly why
they use absolute paths rather than `%USERPROFILE%`. `install.ps1` writes
`scripts/paths.cmd` with the resolved values.

---

## Verify

```powershell
.\scripts\verify-setup.ps1
```

Covers ~30 CLIs (**executed**, not resolved), 6 Python libraries (imported
**and used**), 7 GUI tools, shim integrity, MCP registration, Ghidra/JDK/IDA,
the WDK, VirtualBox, and the five user environment variables. Always exits 0 —
read the returned **text**, not the colour.