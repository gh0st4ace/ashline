# Security Policy

## Reporting a vulnerability

Report privately via GitHub Security Advisories on this repository
(**Security → Report a vulnerability**). Do not open a public issue.

Please include:

- What the vulnerability allows (not just what you found)
- Reproduction steps, ideally minimal
- Which component: installer, script, config template, agent, or doc
- Your Windows version, PowerShell version, and OpenCode version
- Whether the issue is already mitigated by design

You can expect an acknowledgement within 72 hours and a substantive response
within 14 days. Fixes ship as a patch release; see [CHANGELOG.md](CHANGELOG.md).

## Scope

**In scope** — anything in this repository that runs on a user's machine:

- `install.ps1`, `scripts/*.ps1`, `scripts/*.py`, `scripts/*.cmd`
- `config/*.jsonc` templates
- `agents/*.md`, `.agents/skills/*`
- The installer writing into `~/.config/opencode`

**Out of scope** — third-party code this repo does not ship:

- Upstream collections cloned at install time (see
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)). Report those to their
  maintainers.
- MCP servers, including the 6 configured here. Report to their projects.
- Analysis engines (Ghidra, IDA, WinDbg) and RE toolchains.

**Always out of scope**, by design: the legitimate research this workbench
enables against systems the operator does not own. See
[DISCLAIMER.md](DISCLAIMER.md).

---

## Threat model for this repository

An agent harness is an attack surface. This repo's own review is
[docs/agentic-security.md](docs/agentic-security.md); the three classes:

| Class | Mitigation here |
| --- | --- |
| **Supply chain** | Every plugin and MCP version pinned. No `@latest`. Collections pinned to a commit. **No third-party source vendored.** |
| **Context poisoning** | Untrusted content is data, not instruction. Memory auto-capture is **disabled** — nothing enters context without a human writing it |
| **Blast radius** | `edit: deny` on every third-party path. Kernel tests in a snapshot-able VM, never the host. Agent work runs unelevated by default |

---

## Installer security properties

`install.ps1` is designed so a failed run cannot leave a broken config:

| Property | How |
| --- | --- |
| **Preview first** | `-DryRun` prints every step and writes nothing |
| **Atomic swap** | Stages to a temp directory, then swaps |
| **Backed up** | Everything replaced lands in `~/.config/opencode/backups/` timestamped |
| **No secrets written** | Credentials go in environment variables. The templates contain **no** real credentials |
| **Deny by default** | `edit: deny` on all 7 collections, in order, after the grants |
| **Idempotent** | Re-running converges rather than accumulating |

### If you find a secret in this repository

It is a defect. Report it privately and it will be removed and rotated
immediately.

**Before you push anything from your own config directory**, check for these —
all were present in the source material this repo was built from:

- [ ] `service.json` — contained a live-format password value
- [ ] Absolute user paths (`C:\Users\<your-name>\…`)
- [ ] API keys in `mcp-configs/mcp-servers.json` (this repo's copy has
      placeholders only)
- [ ] `*.bak` backup files, which retain old config contents
- [ ] `ecc-install-state.json` — records every installed path
- [ ] Log files under `logs/` — may contain command output

The templates in `config/` use `${VAR}` placeholders for this reason.

---

## Reporting scope for dual-use content

This workbench documents security research tooling, including offensive
capability. Reports about the *documentation* of such capability are handled as
normal security reports. Reports demanding removal of dual-use tooling are not
security issues and will be declined — see [DISCLAIMER.md](DISCLAIMER.md) for
the intended scope.

Content that is **excluded on purpose** and should not appear in a fork:

- Model-jailbreak prompt files
- Operator-local scope-override directives
- Any real credential
