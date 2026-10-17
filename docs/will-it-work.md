# Will this actually work for someone else?

Asked directly, so the answer is direct: **yes for the workbench, no for the
toolchain, and no for anything licensed — until you run three commands.**

This page is the honest install contract. It is deliberately the least
flattering document in the repository, because the alternative is someone
cloning it, seeing a broken harness, and concluding the whole thing is vapor.

---

## What works from a fresh clone

```powershell
git clone https://github.com/gh0st4ace/opencode-workbench
cd opencode-workbench
.\install.ps1 -Profile full
```

That single command gives a working OpenCode shell:

| Component | Result |
| --- | --- |
| Config | `opencode.jsonc`, `opencode-mem.jsonc`, permission matrix |
| **MCP servers** | 6 installed, **277 tools** |
| **Skills** | 315 from ECC + 12 game-security + 93 hack + 3 REA + 5 authored = **428** |
| Commands | 103 from ECC + 6 operational defined here |
| Custom tools | 9 from ECC |
| Hooks, plugins | ECC surface plus the local v2 adaptations |
| Reference collections | 7, pinned to real commits (21.2 GiB, hours) |
| Agents | 4 authored |
| Knowledge | 50-game registry, driver evidence sheets |
| Scripts | 23, including both health checks |

Then:

```powershell
.\scripts\verify-setup.ps1     # toolchain: what is and is not present
py -3 .\scripts\doctor.py      # runtime health
```

---

## What does NOT work from a fresh clone

### 1. The 32 tools — not installed, installable

`-Profile full` does **not** fetch them. They are large, some are licensed, and
several are manual by design.

```powershell
.\scripts\install-all-tools.ps1 -What toolchain
```

That runs the six installers in the order that matters. It does not fix any of
the items below.

### 2. Four things have no installer at all

| Item | Why | What you do |
| --- | --- | --- |
| **Ghidra** | 865 MiB, separate project | Install from nsa.gov, set `GHIDRA_INSTALL_DIR` |
| **JDK 21** | 328 MiB, separate project | Install Temurin, set `JAVA_HOME` |
| **IDA Pro** | Commercial licence | You already have a licence or you do not |
| **x64dbg, dnSpy, dnlib** | Manual by design | See `config/tool-manifest.json` |

**Without Ghidra and a JDK, REA does nothing.** It is the default analysis
provider and 170 of the 277 MCP tools depend on it.

### 3. cheat-mcp needs a local build

It is a third-party C++ project, not an npm package, and the upstream omits
`#include <mstcpip.h>` in `src/network.cpp`, which breaks the `SIO_RCVALL` call.
That include is a **local patch** and will conflict on a fresh `git pull`.

`scripts/install-mcp-servers.ps1` prints the four-step recipe. Requires Visual
Studio, CMake, and the WDK.

72 of the 277 tools live behind this one binary.

### 4. Node, Python, and OpenCode itself are prerequisites

The installer **probes** them and warns. It does not install them.

```powershell
winget install OpenJS.NodeJS.LTS
winget install Python.Python.3.12
```

---

## Verified, and not verified

| Claim | Evidence |
| --- | --- |
| `-DryRun` writes nothing | Executed against a throwaway target; target absent afterwards |
| A real install produces a complete tree | Executed into a temp dir; 0 unsubstituted placeholders |
| `-Profile full` dry run reports every step | Executed |
| `install-all-tools.ps1 -DryRun` reports all 6 installers | Executed |
| MCP status detects all 6 servers present | Executed on this machine: all 6 `[ok]` |
| ECC clones itself if absent | Patched; **not** executed end-to-end (a 232 MiB clone) |
| 21.2 GiB of collections clone cleanly | **Not** executed from scratch — the clones pre-exist |
| The 32 tools install from empty | **Not** executed from scratch — they pre-exist |
| A second machine reproduces this exactly | **Not** tested. No second machine available |

That last block is the honest limit. Everything above the line was run; nothing
below it was. The claims below the line are reasonable inferences from the
scripts, not measurements.

---

## Time cost for a fresh machine

| Step | Time |
| --- | --- |
| `-Profile config` | seconds |
| `-Profile tools` | ~1 hour (toolchains, no collections) |
| `-Profile full` | hours — 21.2 GiB of collections dominates |
| `install-all-tools.ps1` | ~1 hour |
| Ghidra + JDK manual | your call |

---

## The likely first-run failure

**Running OpenCode from `C:\WINDOWS\system32`.**

Each MCP server is spawned per working directory. From `system32` the tool set
doubles: measured 368 tools instead of 184, with duplicates. Start from a normal
project directory.

Second most likely: **`-Profile config` instead of `-Profile full`**, which
installs the workbench but leaves the skill catalog empty. It looks broken
rather than partial, which is why the installer prints the skipped steps
explicitly instead of failing quietly.

---

## If something is missing

```powershell
.\scripts\verify-setup.ps1
```

Read the returned **text**, not the colour. Several checks print a green `OK`
while describing a failure state — a dropped junction reports as `'0/12'`. This
is documented in
[troubleshooting.md](troubleshooting.md#false-green-in-verify-setup) rather
than hidden.

```powershell
.\scripts\install-mcp-servers.ps1 -What status   # which servers are absent
py -3 tools\gen-tool-manifest.py                 # rescan what is installed
```

---

## Two channels, on purpose

| Channel | Carries | Use when |
| --- | --- | --- |
| **This repository** | 1 MB. Config, scripts, methodology, knowledge, manifests | Normal sharing. No licensing question. Reproduces everything from pinned sources. |
| **`export-portable-bundle.ps1`** | 0.13–3 GiB zips of actual binaries | A colleague needs it working offline, tomorrow |

```powershell
.\scripts\export-portable-bundle.ps1 -What triage -DryRun
```

The exporter excludes non-redistributable tooling unless `-IncludeUnsafe`, and
writes a README next to the archive saying compliance is then your
responsibility. If in doubt, share the repository.

---

## Why it is not 25 GiB

Measured on the authoring machine:

```
D:\opencode   22.36 GiB   21.24 GiB of it other people's repos
D:\Tools       8.32 GiB   the tools (4.67 GiB of it VM media)
repository     0.95 MiB   what ships
```

GitHub's per-file limit is 100 MB against Ghidra at 865 MiB, hashcat 371,
Sysinternals 272, JDK 328, dnSpy 203. IDA Pro and the Windows SDK are
commercial or EULA. Repackaging a vendor's build is not sharing.

So the repository ships the **contract** — version, source, license, installer,
dependent skills, for all 32 — plus the installers, plus the exporter for the
cases where binaries genuinely must move. See [tools.md](tools.md).