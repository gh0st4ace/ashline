# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-17

First public release. Consolidated a working OpenCode environment into a
documented, installable repository.

### Added

**Methodology and documentation**

- `AGENTS.md` — the operating contract. Evidence labelling, instrument-before-
  theorize, routing protocol, kernel-test discipline, context economy.
- `docs/methodology.md` — four failure modes that cost hours each, and the rules
  they produced. The core of the repository.
- `docs/architecture.md` — how the pieces fit, and the six config decisions each
  made against a specific failure.
- `docs/installation.md`, `docs/troubleshooting.md`, `docs/scripts.md`,
  `docs/skills-catalog.md`, `docs/mcp-servers.md`, `docs/collections.md`,
  `docs/agents.md`, `docs/knowledge-workspaces.md`, `docs/agentic-security.md`,
  `docs/index.md`.
- `README.md` (English) and `README.ru.md` (Russian), plus a Russian docs index.

**Installer**

- `install.ps1` — `-DryRun` by default behaviour, atomic staging, timestamped
  backups, three profiles (`config` / `tools` / `full`), `-Uninstall`.
- `config/opencode.jsonc.template` — with a header block documenting all six
  deliberate omissions and the failure each one prevents.
- `config/opencode-mem.jsonc.template` — including the two settings that must
  not be reverted without re-indexing.

**Scripts** (19, sanitized and parameterized)

- Health: `verify-setup.ps1` (11 check categories), `doctor.py` (8 sections,
  the only instrument returning non-zero), `maintain.ps1`.
- Installers: `install-missing-tools.ps1` / `2` / `3`, `install-game-tools.ps1`,
  `install-triage-tools.ps1`.
- Updaters: `update-awgs.ps1`, `update-awgs-archive.ps1`,
  `update-hack-skills.ps1`, `sync-awgs-skills.ps1`, and two Task Scheduler
  launchers.
- Fixers: `fix-ida-shadow.ps1`, `fix-ghost-sessions.ps1`.
- Environment: `start-ida-mcp.ps1`, `vmhelper.ps1`, `devshell.cmd`.

**Knowledge workspaces**

- `knowledge/game-lab/` — 50-game registry (22 fields, confidence-tagged,
  validator-enforced), engine fingerprint script, discovery sheet.
- `knowledge/kernel-sec/` — evidence sheets with the falsifier convention,
  passive `driver_triage.py`, `feed_query.py`.
- The 33 MB LOLDrivers cache is **not** committed; it is a dependency with a
  documented refresh command.

**Skills** (5 authored)

`game-engine-detection`, `game-memory-lab`, `game-modding-lab`,
`anti-cheat-architecture`, `game-research-tool-discovery`.

**Agents** (4 authored)

`spacebunnyjb`, `gamesec`, `kernel-driver-analyst`, `ksec-validator`.

**Governance**

- `SECURITY.md`, `CONTRIBUTING.md`, `DISCLAIMER.md`, `THIRD_PARTY_NOTICES.md`.
- `collections.lock.json` — 7 collections plus 3 supporting repos pinned to real
  commits, with fetch methods and the excluded router list.
- `tools/sanitize-and-copy.py` — the path-sanitizer, with four self-verifying
  gates.

### Excluded, deliberately

Recorded here so the omissions are visible rather than looking like oversights:

- **21.2 GiB of third-party collections.** Declared as pinned dependencies.
  Vendoring would republish other people's MIT work, break on every upstream
  commit, and exceed GitHub's 100 MB per-file limit.
- **ECC's 315 skills, 103 commands, 9 tools, hooks, plugins.** Installed via
  ECC's own installer; declared as a dependency with its commit pinned.
- **LLM-jailbreak prompt agents.** Not workbench methodology.
- **Operator-local scope-override directives.** An instruction to the assistant,
  not a reusable practice, and not something a public repository should carry.
- **A live-format password** that existed in the source config's `service.json`.
  Never copied; the sanitizer asserts its absence.
- **Separate private projects** (a DayZ kernel-driver project and others) that
  live in their own repositories.

### Known limitations

- `verify-setup.ps1` prints a green `OK` for several checks that describe a
  failure state, including a dropped junction (`'0/12'`). Documented in
  `docs/troubleshooting.md#false-green-in-verify-setup` rather than hidden.
- `doctor.py` liveness-probes a process with `os.kill(pid, 0)`, which on Windows
  may terminate the process rather than probe it. Flagged in
  `docs/scripts.md`; not confirmed on this host.
- `install-missing-tools2.ps1` derives its scripts directory from
  `sysconfig`, while passes 3 and the triage installer hardcode an absolute
  Python path. A Python version change would silently drop the floss and
  impacket shims.
- Junction counts in `verify-setup.ps1` are hardcoded at 12/93/3 and do not
  compare against disk. Correct today, not self-updating.
- `sync-awgs-skills.ps1` calls `git -C $Repo pull` without
  `-c safe.directory=`, unlike every other updater. Harmless while it is always
  invoked with `-SkipPull`; would fail standalone under the scheduler account.

[0.1.0]: https://github.com/gh0st4ace/opencode-workbench/releases/tag/v0.1.0
