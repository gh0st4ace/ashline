# Scripts

20 maintenance scripts. All PowerShell 5.1-compatible, all read-only unless
stated, and all idempotent.

---

## The two health checks

These do not overlap. Understanding which one answers your question is the
difference between a five-second fix and an afternoon.

| | `verify-setup.ps1` | `doctor.py` |
| --- | --- | --- |
| **Question** | Is the toolchain and wiring intact? | Is the running OpenCode installation healthy? |
| **Exit code** | always `0` | `0` / `1` / `2` |
| **CI-usable** | no | **yes** |
| **Scope** | 11 check categories | 8 sections |
| **Writes** | nothing | nothing |

`doctor.py` is the only instrument here that returns non-zero, which makes it the
only one usable as a gate.

---

## `verify-setup.ps1`

Read-only. Recomposes `$env:Path` from Machine + User + `opencode-shims`
internally, so it does not depend on how it was invoked.

### What it actually checks

| Category | Checks | Failure modes found |
| --- | --- | --- |
| Configuration | `opencode.jsonc` + `opencode-mem.jsonc` parse; compaction state; backup count; `AGENTS.md` present | Malformed JSONC, lost backups |
| Skill wiring | 12/93/3 junctions; `reverse-engineer-anything` under `~/.agents/skills`; local `game-security-reverse-engineering` | Junctions broken after a repo restructure; a skill moved into default discovery |
| Reference collections | 7 `Test-Path` | Collection unmounted or renamed |
| REA engines | Ghidra + `java -version`; IDA path; **IDA PATH shadow**; `mcp-plugin.py`; `REA_IDA_MCP_CONFIG`; `rea setup` | The documented 9.3 shadow; missing JDK; REA refusing to pick a provider |
| opencode-mem | store path; TCP listener on 4747 | Web UI down, store moved |
| CLI tools | ~30 tools **executed**, first output line printed | Resolves-but-broken; wrong-binary shims |
| Python libraries | 6 modules imported **and used**, version via `importlib.metadata` | Installs but cannot import; `pwntools` broken by its `unicorn` pin |
| GUI tools | 7 resolved by `Get-Command` | Missing x64dbg, dnSpy, Cheat Engine |
| Shim integrity | count; regex for unexpanded `%target\|%t\|%path\|%src`; shape check | The literal-`"%target"` bug |
| MCP servers | `opencode mcp list` for the 5 expected names + `✓` | Not registered vs. registered-but-disconnected |
| Dev env | `devshell.cmd`, `vcvarsall`, `signtool`, WDK `km\wdm.h`, VirtualBox, dnlib/AsmResolver, 5 env vars | Missing kernel headers blocks driver work |

### False-reading handling

This is the part that matters, and it exists because of specific failures:

- **Resolution ≠ working.** Three shims resolved cleanly and were broken —
  `install-missing-tools.ps1` emitted the literal string `"%target"` because the
  variable reference was missing its sigil. Every CLI probe is therefore
  *executed*.
- **Traceback-as-banner.** `binwalk 2.1.0` shipped a working-looking failure
  whose first line was `Traceback (most recent call last):`. Both loops regex for
  tracebacks *before* accepting a banner.
- **Probes that hang or misfire.** `hashcat -v` is VERBOSE mode and starts a
  cracking run that never returns → use `--version`. `windbg -?` opens the GUI →
  probed with no arguments. `frida-ps` blocks on an unattached USB device → never
  executed. GUI-only binaries are listed and never launched.
- **Quoting.** PowerShell strips double quotes from a `python -c` snippet,
  turning `print("impacket")` into `print(impacket)` → `TypeError`. The snippet
  is written to a temp file and run instead.
- **Version source.** `importlib.metadata.version()`, not module attributes —
  impacket has no `__version__` and `import smbclient` through the package name
  fails. Each module is then actually *used*.
- **Output buffers.** `$t.Substring(0, [Math]::Min(48, $t.Length))` everywhere, so
  a short banner cannot throw and misreport the whole check.

### Known weaknesses

Documented rather than inherited:

1. `Check()` treats any non-empty, non-`MISSING` return as `[ OK ]`, so
   `ida PATH shadow` → `'SHADOWED: …'` and `gameskills junctions` → `'0/12'`
   both print green. See [troubleshooting](troubleshooting.md#false-green-in-verify-setup).
2. Junction counts hardcode 12/93/3 and never compare against disk. Correct
   today, not self-updating.
3. `ReadJsonc` strips only full-line `//`. Inline comments would surface as a
   false FAIL. Latent, not active.
4. MCP detection matches a substring on the first line containing the name;
   `rea` also appears inside `crea…`, so the first match is not guaranteed to be
   the right row.
5. The dnlib/AsmResolver check takes the first recursive hit with no TFM or
   version filter, unlike the installer which filters
   `netstandard2.0|net6.0|net8.0|net9.0`.

---

## `doctor.py`

Runtime health. Exit `2` for bad, `1` for warn, `0` clean.

| Section | Detects |
| --- | --- |
| Version sync | npm CLI vs. desktop-service desync — this killed sessions |
| Ghost sessions | `ses_*` in `drafts.sqlite` absent from `opencode.db` → "Session not found" popups |
| Plugin cache | Orphaned `.staging-*` dirs; cache > 4 GiB |
| Uncompressed sessions | > 400 messages with **zero completed** compactions → `invalid_request_error` |
| Config | `opencode.jsonc` presence |
| Log census | > 40 `ERROR` lines in the last 4000 lines |
| Project state | OBSIDIAN git / handoff / `sig_table` TDS |
| **Client identity** | PE `TimeDateStamp` + `SizeOfImage` of the game client vs. hardcoded expected |

> [!IMPORTANT]
> The identity check is the anti-stale-offset guard. A client update invalidates
> every offset derived yesterday, silently. The script prints
> "все смещения использовать нельзя" when it mismatches. Do not skip it.

A **failed** compaction counts as none — `status == 'completed'` only — because a
failed compaction compresses nothing.

Both sqlite handles open `mode=ro` with `uri=True`.

> [!WARNING]
> One line liveness-probes the desktop service with `os.kill(pid, 0)`. On
> Windows, CPython maps signals other than `CTRL_C_EVENT`/`CTRL_BREAK_EVENT` to
> `TerminateProcess`, so this may **kill the process it is measuring** rather
> than probe it. Not confirmed on this host. Treat that line as suspect and check
> it before trusting it.

---

## Installers

Sequential passes over **one measured gap list**, not three scopes. Run 1 → 2 → 3.

| Script | Contents |
| --- | --- |
| `install-missing-tools.ps1` | Pass 1 — nmap, rizin, jadx (winget); radare2, hashcat, apktool; pip: sqlmap, frida-tools, binwalk, capstone, uncompyle6, volatility3 |
| `install-missing-tools2.ps1` | Pass 2 — impacket, objection, pwntools (`--no-deps`); Go binaries nuclei/httpx/ffuf/gobuster; upx, john, Sysinternals, de4dot |
| `install-missing-tools3.ps1` | **Repair pass** — see below |
| `install-game-tools.ps1` | Cheat Engine, Il2CppDumper, Cpp2IL, dnlib + AsmResolver via `dotnet build`, Scylla |
| `install-triage-tools.ps1` | capa 9.4.0 + rules, FLOSS, LIEF, DIE |

### Why pass 3 exists

Its header names the four bugs pass 2 shipped:

1. `httpx` matched by **filename** and captured the Python `httpx` client living
   inside `ida-pro-mcp-venv`.
2. `releases/latest/download/<asset>` is invalid where the asset lives under a
   tag-specific path.
3. Sysinternals extracted 164 files with **zero** shims.
4. impacket ships `.py` entry points, not `.exe`, on this Python install.

It deletes the bad shim first, then re-fetches with tag-pinned URLs
(nuclei v3.11.1, httpx v1.12.0, ffuf v2.3.0, gobuster v3.8.2, upx v5.2.1) and
generalizes the lesson into two guards that now apply everywhere:

- `Get-Tool` refuses an on-disk directory unless the expected executable is
  genuinely inside it.
- Any download under 100 KB is rejected as a probable HTML error page.

Pass 3 overlaps pass 2 for nuclei/httpx/ffuf/gobuster/upx and **wins**.

### The shim pattern

Every CLI gets an ASCII shim in `%LOCALAPPDATA%\opencode-shims`:

```batch
@echo off
"D:\Tools\radare2\bin\rabin2.exe" %*
```

`verify-setup.ps1` checks these separately from execution, because the
`"%target"` bug produced shims that resolved and did nothing.

### Interpreter path inconsistency

`install-missing-tools2.ps1` derives the scripts dir via
`sysconfig.get_path('scripts')`, while passes 3 and the triage installer
**hardcode** an absolute Python path. A Python version change silently drops the
floss and impacket shims. Worth fixing if you touch these.

---

## Updaters

| Script | Does | Notable |
| --- | --- | --- |
| `update-awgs.ps1` | Sparse pull + re-link | `reset --hard` + `clean -fd` so upstream renames apply; `-c safe.directory`; log rotated at 2 MB; always exits 0 |
| `update-awgs-archive.ps1` | 18 GiB mirror from tarball | curl with `--retry 20`, throughput-aware abort (`--speed-limit 20000 --speed-time 120`); atomic dir swap; 7-day cache gate, `-Force` to bypass |
| `update-hack-skills.ps1` | Pull + re-link + **prune** | Excludes the 10 routers; prunes junctions whose upstream dir is gone |
| `sync-awgs-skills.ps1` | Links 12 skills + installs the renamed copy | The only script that throws; writes UTF-8 **without** BOM |

`update-awgs.ps1` documents a `-ArchiveOnly` parameter that does not exist. The
real switch is the separate launcher. That stale comment is deliberate — see
[methodology §4](methodology.md#4-superseded-claims-stay-visible).

---

## Fixers

| Script | Purpose |
| --- | --- |
| `fix-ida-shadow.ps1` | Renames the loose IDA 9.3 at `D:\Programs\ida.exe` so bare `ida` stops shadowing 9.4. **Needs elevation.** Reversible (`.9.3-orphan.bak`) |
| `fix-ghost-sessions.ps1` | Clears "Session not found" popups. **Renames, never deletes**, the two `ai.opencode.desktop` state folders. Sessions in `opencode.db` untouched. No admin needed |

---

## IDA bridge

```powershell
.\scripts\start-ida-mcp.ps1 <binary> [-SettleSeconds 12] [-NoRaise]
```

Kills any running IDA, launches `ida.exe -A`, waits up to 60 s for a main
window, sends the plugin hotkey (`Ctrl+Alt+M`), then polls port **13337** for up
to 30 s.

Requires an **interactive desktop session** — it uses
`System.Windows.Forms.SendKeys`. `-NoRaise` reuses an existing bridge.

---

## VM discipline

```powershell
.\scripts\vmhelper.ps1 -Action status|start|shutdown|snap|rollback|snapshots|discard [-Name pre-test]
```

Wraps `VBoxManage` for the `ac-test` VM: Windows 10 Enterprise LTSC Evaluation
(build 19041.1288), 4 vCPU, 8 GB RAM, 80 GB dynamic SATA, audio and USB
disabled, clipboard and drag-drop disabled.

Eval needs no activation, which is what a test VM wants — no licence to manage,
no expiry mid-test.

```powershell
.\scripts\vmhelper.ps1 snap pre-driver-test
# ... the risky thing ...
.\scripts\vmhelper.ps1 rollback
```

This is the only cheap way back from a wedged driver. **Snapshot before anything
risky.**

---

## Build environment

```powershell
.\scripts\devshell.cmd                          # interactive x64 cmd
.\scripts\devshell.cmd x64 cmd /c "cl /?"       # one-shot
.\scripts\devshell.cmd arm64
```

Calls `vcvarsall.bat` and prepends the Windows SDK bin dir so `cl.exe`,
`link.exe`, `signtool.exe`, and `msbuild.exe` resolve.

Contains a documented fix: `shift` does not affect `%*`, so it rebuilds the tail
from `%1..%9` explicitly.

---

## Slash commands

| Command | Does |
| --- | --- |
| `/verify` | Runs `verify-setup.ps1`, summarizes failures, **changes nothing before you see the output** |
| `/doctor` | Runs `doctor.py`, explains every `[BAD]` and `[warn]` with consequence and remedy |
| `/stack` | One-screen status: skills, collections, engines, memory, what is broken |
| `/refresh` | Runs the three updaters in order, then `verify-setup.ps1` |
| `/re <path> [addr]` | REA; loads the skill, requires an address, Ghidra default |
| `/state` | Project summary without reading a 4213-line handoff |

---

## Not installed, and why

| Tool | Reason |
| --- | --- |
| John the Ripper | Openwall publishes Unix source only. No official Windows build. hashcat covers it. No third-party mirrors. |
| metasploit, burpsuite, zap | Multi-GB GUI installers, low return |
| frida-server | Only useful against a real Android device |
| pentestMCP | Requires Docker, absent |

`pwntools` is installed with `--no-deps` **on purpose**: its `unicorn` pin
(`>=2.0.1, !=2.1.3, !=2.1.4`) makes pip backtrack to the unicorn 2.1.2 source
tarball, which has no Windows wheel and fails to build. The unicorn 2.1.4 wheel
is already present and works. Adding `pysocks`, `beautifulsoup4`, `coloredlogs`,
`hexdump`, `paramiko`, `python-dateutil`, `pyserial` by hand gives a working
pwntools — verified by `process(['cmd'])` spawning and reporting a pid.
