# Troubleshooting

The failure modes that actually occurred here, with the fix. If yours is not
listed, run both health checks and read their output before changing anything.

---

## Triage order

```powershell
.\scripts\verify-setup.ps1     # toolchain + wiring, always exits 0
py -3 .\scripts\doctor.py      # runtime health, exits 0/1/2
```

They do not overlap. Pick by symptom:

| Symptom | Instrument |
| --- | --- |
| A tool is not found, or found but wrong | `verify-setup.ps1` |
| A session will not start, or "Session not found" | `doctor.py` |
| OpenCode is slow, or the plugin cache is huge | `doctor.py` |
| A collection is missing a skill | `verify-setup.ps1` |
| REA will not pick a provider | `verify-setup.ps1` |
| Requests rejected / context exhausted | `doctor.py` |

---

## False green in `verify-setup`

`Check()` treats any non-empty, non-`MISSING` return as `[ OK ]`. So these print
green while describing a failure:

| Check | Prints OK as |
| --- | --- |
| `ida PATH shadow` | `'SHADOWED: bare ida -> 9.3; run fix-ida-shadow.ps1 elevated'` |
| `gameskills junctions` | `'0/12'` |
| `hackskills junctions` | `'0/93'` |
| `mem web UI` | `'not listening'` |

**Read the returned text, not the colour.** A dropped junction reads as OK.

This is documented rather than hidden — see
[methodology §2](methodology.md#2-a-check-that-cannot-distinguish-is-not-a-check).
A check that always passes is as useless as one that always fails.

---

## REA: `Multiple analysis providers support this target`

REA counts a provider as available by *registration*, not by a live bridge, and
refuses to guess.

```powershell
$env:REA_ANALYSIS_PROVIDER = "ghidra"   # persisted at User scope
```

Also confirm:

- `GHIDRA_INSTALL_DIR` points at a real Ghidra with `ghidraRun.bat`.
- `JAVA_HOME` is set and `java -version` works. **Without a JDK, Ghidra headless
  cannot start.**

```powershell
rea-agents doctor
```

---

## REA: `unreadable_output` on a function name

You passed a bare function name. Pass an **address**.

```powershell
rea decompile <binary> 0x140001300 --format json
```

A bare name resolves for some REA tools and fails others. Start with
`list_procedures` to learn the address space.

---

## `ida` launches the wrong version

`D:\Programs\` is on the machine `PATH` ahead of every user entry and holds a
loose IDA 9.3 that shadows the real 9.4. Bare `ida` launches 9.3, which has no
plugins — so the MCP bridge never appears.

```powershell
# elevated, once
.\scripts\fix-ida-shadow.ps1
```

Reversible: the file is renamed to `.9.3-orphan.bak`, not deleted.

---

## "Session not found" popups

Ghost sessions: `ses_*` keys in `drafts.sqlite` whose ids are absent from
`opencode.db`.

```powershell
py -3 .\scripts\doctor.py        # reports them
.\scripts\fix-ghost-sessions.ps1 # renames state dirs; does NOT touch sessions
```

No admin needed. The state folders are **renamed**, never deleted, with a
timestamped backup. Sessions in `opencode.db` are untouched.

---

## Requests rejected with `invalid_request_error`

The session grew past what the provider accepts. `doctor.py` looks for sessions
with **> 400 messages and zero completed compactions**.

A *failed* compaction counts as none — `status == 'completed'` only — because a
failed compaction compresses nothing.

Fix: compact, or start a new session. Prevention is the habits in
[architecture.md](architecture.md#keep-the-context-window-affordable): bounded
reads, delegated breadth, one skill per problem.

---

## Plugin cache is enormous

```powershell
py -3 .\scripts\doctor.py        # reports size and staging dirs
.\scripts\maintain.ps1           # deletes them
```

`maintain.ps1` deletes `.staging-*` dirs, cache dirs under 1 KiB, and versions
not referenced by `opencode.jsonc` — but **only when another referenced copy of
the same package exists**. That guard is load-bearing.

Prevention: pin plugin versions. `@latest` re-resolves on every load and leaves
staging debris. 746 MB were reclaimed this way.

---

## Every new session fails with 429

You reintroduced `default_agent` pinned to a free model. When the quota is
exhausted, **every** new session gets `FreeUsageLimitError`.

Remove the line. The agent is chosen in the UI and remembered per session.

---

## A skill resolves but does not load

Junction broken, or the skill moved into a different discovery root.

```powershell
(Get-ChildItem "$env:USERPROFILE\.config\opencode\gameskills").Count   # 12
(Get-ChildItem "$env:USERPROFILE\.config\opencode\hackskills").Count   # 93
(Get-ChildItem "$env:USERPROFILE\.config\opencode\reaskills").Count    # 3
.\scripts\sync-awgs-skills.ps1
.\scripts\update-hack-skills.ps1
```

> [!WARNING]
> Never delete a skill junction with `Remove-Item -Recurse`. It follows the
> junction and **deletes the real directory in the upstream repo**. Use
> `[System.IO.Directory]::Delete($link, $false)`.

---

## A skill has a garbled or invalid frontmatter

BOM. `Set-Content -Encoding utf8` in PowerShell 5.1 emits a BOM, which breaks
YAML frontmatter in some readers.

Write UTF-8 **without** BOM. `sync-awgs-skills.ps1` does this for the one skill
it installs as a renamed copy.

---

## Tool count doubled unexpectedly

You are working from `C:\WINDOWS\system32`. Each MCP server is spawned per
working directory.

Measured: **368 tools instead of 184**. Move to a normal project directory.

---

## `git pull` fails with dubious ownership

The repo was cloned by one account and the script runs under another (Task
Scheduler). Pass `-c safe.directory=<repo>` per command rather than mutating
global git config:

```powershell
git -c safe.directory="D:/opencode/awesome-game-security" pull --ff-only
```

Known inconsistency: `sync-awgs-skills.ps1:43` calls a bare `git -C $Repo pull`.
Harmless today because `update-awgs.ps1` always passes `-SkipPull`, but it
would fail under the scheduler account if run standalone.

---

## An installer wrote an HTML page instead of a binary

`releases/latest/download/<asset>` is invalid where the asset lives under a
tag-specific path. The 404 page gets written to disk as if it were the tool.

Guards added in `install-missing-tools3.ps1`:

- `Get-Tool` refuses an on-disk directory unless the expected executable is
  genuinely inside it.
- Any download under 100 KB is rejected as a probable error page.

Use the tag-pinned URLs.

---

## `httpx` resolves to the wrong binary

It matched by filename and captured the Python `httpx` client inside
`ida-pro-mcp-venv`.

```powershell
.\scripts\install-missing-tools3.ps1    # the repair pass
```

This is why the three `install-missing-tools` scripts run in order **1 → 2 → 3**.
Pass 3 exists specifically to repair bugs pass 2 shipped, and it wins where they
overlap.

---

## `pwntools` will not install

Its `unicorn` pin (`>=2.0.1, !=2.1.3, !=2.1.4`) makes pip backtrack to the
unicorn 2.1.2 **source tarball**, which has no Windows wheel and fails to build.

Install with `--no-deps`, then add the deps by hand:

```powershell
pip install --no-deps pwntools
pip install pysocks beautifulsoup4 coloredlogs hexdump paramiko python-dateutil pyserial
```

The unicorn 2.1.4 wheel is already present and works. Verify:

```python
from pwn import *; print(context.arch)
```

---

## An importable-looking Python package fails

`verify-setup.ps1` imports each module **and uses it** — `from pwn import *`,
`import impacket.smb3` — because a package can install and still fail to load.

Version comes from `importlib.metadata.version()`, not module attributes:
impacket has no `__version__`, and importing `smbclient` through the package
name fails.

---

## Ghidra headless: `FileNotFoundException`

The **project directory must exist before** `analyzeHeadless`. Create it first.

---

## The NVD API times out

Needs **≥ 100 s** from this network. 45 s failed; 100 s succeeded.

---

## A Blue Screen after a driver test

Expected, and the reason `vmhelper.ps1` exists.

```powershell
.\scripts\vmhelper.ps1 rollback
```

Snapshot before, always:

```powershell
.\scripts\vmhelper.ps1 snap pre-driver-test
```

> [!WARNING]
> Never load a kernel anti-cheat or a vulnerable driver on the host. Snapshot,
> test in `ac-test`, roll back.

---

## When nothing matches

1. Run **both** health checks and read the output before changing anything.
2. `.\scripts\verify-setup.ps1` and `py -3 .\scripts\doctor.py` together cover
   most of the space.
3. Read the failing check's **returned text**, not just its colour — see
   [false green](#false-green-in-verify-setup).
4. Name two or three alternative readings, then go get the observation that
   distinguishes them. See [methodology](methodology.md).
