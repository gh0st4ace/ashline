# MCP servers

**6 active, 34 catalogued. Total live tools: 277.**

The distinction matters: the catalogued 34 are a **menu of candidates**, not a
config, and nothing in them is running.

---

## Active

| Server | Tools | Transport | Needs | Purpose |
| --- | ---: | --- | --- | --- |
| `rea` | 170 | local | Ghidra headless, or the IDA bridge | Reverse engineering across binaries, JS/Electron apps, .NET, Android, firmware, wasm, EVM, PCAP |
| `cheat-mcp` | 72 | local | Built from source; elevation for most ops | Process/module enumeration, memory read/write/scan, pointer chains, DLL injection, IAT hooking, AC detection, network capture |
| `js-reverse` | 24 | local | Node | JS signature-chain location, page observation, runtime sampling, local environment reproduction |
| `jshook` | 8 | local | Node | JS hook and tool-coverage instrumentation |
| `context7` | 2 | local | Node | Live library documentation |
| `renderdoc` | — | local | A `.rdc` capture | GPU frame analysis |

> [!IMPORTANT]
> 277 tools is a lot of context on every step. The catalogued 34 below are
> deliberately **not** activated wholesale — the ECC catalog's own guidance is
> to keep under 10 MCPs enabled.

---

## `rea`

The single largest capability. 170 tools.

**Provider selection.** Ghidra headless is the default: no GUI, no manual step.
IDA is attached mode and requires a live GUI with the MCP plugin started.

```powershell
.\scripts\start-ida-mcp.ps1 <binary>
rea decompile <binary> 0x140001300 --provider ida --format json
```

Pass an **address**, not a bare function name. A bare name resolves for some
tools and fails others with `unreadable_output`. Start with `list_procedures` to
learn the address space.

Without `REA_ANALYSIS_PROVIDER` set, REA refuses to choose at all and reports
`Multiple analysis providers support this target` — it counts a provider as
available by registration rather than by a live bridge.

**Do not open the IDA GUI unprompted.** Nobody asked for a window on their
desktop.

---

## `cheat-mcp`

72 tools. Built from source — the upstream repository omits
`#include <mstcpip.h>` in `src/network.cpp`, which breaks the `SIO_RCVALL` call.
That include is a local fix and **will conflict on a fresh `git pull`**.

Reports `is_admin: false` by default and has its own `elevate` /
`run_elevated` tools. **Prefer the non-elevated path.** Do not trigger a UAC
prompt unless the operator asked for it.

Useful surface: `memory_read`, `memory_write`, `scan_value`, `scan_aob`,
`scan_load`, `pointer_scan`, `pointer_read`, `module_base`, `module_resolve`,
`inject_dll`, `inject_shellcode`, `iat_hook`, `ac_detect`, `ac_kernel_drivers`,
`ac_check_debug`, `process_candidates`.

---

## The catalogued 34

`config/mcp-servers.json.template` is a **curated reference catalog**, not a
live config. Five independent reasons:

1. It self-declares: *"Copy the servers you need to your `~/.claude.json`
   mcpServers section"*.
2. Its schema is Claude Code's (`mcpServers` with `command`+`args`), not
   OpenCode's (`mcp.servers` with array `command`). It would not parse as an
   OpenCode config.
3. Every credential is a placeholder — 14 `YOUR_*_HERE` env vars, 2 header
   values, 3 placeholder path args.
4. It is byte-identical to its ECC upstream source (SHA256 match, same mtime).
   It is a vendor-shipped artifact, not authored here.
5. The live config defines a **disjoint** set of 6 servers. Only `context7`
   overlaps by name, and even there the live entry launches a locally installed
   absolute path rather than `npx -y`.

### What is in it, by category

| Category | Servers |
| --- | --- |
| Cost, privacy, context | `nexus`, `token-optimizer` |
| Memory and session recall | `memory`, `omega-memory`, `longhand`, `ecc-memory-vault`, `memxus` |
| Reasoning | `sequential-thinking` |
| Documentation and catalogs | `context7`, `cloudflare-docs`, `laraplugins`, `magic` |
| Web search and scraping | `exa-web-search`, `parallel-search`, `firecrawl` |
| Browser automation | `playwright`, `browserbase`, `browser-use` |
| Hosting, deploy, data | `vercel`, `railway`, `supabase`, `clickhouse`, 3× Cloudflare Workers |
| Work trackers | `github`, `jira`, `confluence` |
| Orchestration and compute | `devfleet`, `ito-compute` |
| Evaluation and code health | `evalview`, `codescene` |
| Media and filesystem | `fal-ai`, `filesystem` |

Transport: **23 stdio, 11 http, 0 sse.**

### Three distinct memory designs

Worth understanding before picking one:

- **`memory`** — the official reference server. Basic.
- **`omega-memory`** — semantic search plus knowledge graphs.
- **`longhand`** — **verbatim** capture. Indexes raw tool calls, file edits, and
  thinking blocks from `~/.claude/projects/*.jsonl` into SQLite + ChromaDB
  *before* the harness rotates them. Complements the other two, which store
  synthesized memory. Claude-Code-specific.

---

## Install notes for the catalog

Several entries are not portable as written:

| Server | Issue |
| --- | --- |
| `ito-compute` | **Unpublished package.** Must be built from `Ito-Markets/ito-cloud-runtime/cli/ito-compute-cli`. Arg is a placeholder absolute path. Non-functional as shipped |
| `evalview` | Launches via `python3`, which is not a default Windows shim. Use `py -3` |
| `filesystem` | Placeholder path `/path/to/your/projects` — Unix-style; Windows needs escaping |
| `longhand` | Install is prose-only: `pip install longhand && longhand setup`. Needs pre-existing `~/.claude/projects/*.jsonl` |
| `nexus`, `ecc-memory-vault` | Bare binaries with no installer line |
| `devfleet` | Local daemon on `http://localhost:18801/mcp` must already be running |
| `supabase`, `context7`, `magic` | Float `@latest` — **pin these** |
| `jira` | Only entry that is pinned (`mcp-atlassian==0.21.0`) |

### Floating versions

Three entries use `@latest`, which re-resolves on every load. Pin them. This is
the same rule that applies to the `plugins:` array — it left 746 MB of
`.staging-*` debris before it was pinned.

### Windows portability, unremarked in the file

`npx`, `uvx`, `python3` launchers; two `http://` rather than `https://`
endpoints (`devfleet` only); slash-style `/path/` args. All need adjustment on
Windows.

---

## Security-relevant descriptions worth carrying forward

These are in the catalog's own text and should survive into any copy:

| Server | Note |
| --- | --- |
| `memxus` | Warns to review stored memories before use in production agents — memory-poisoning prompt injection |
| `ecc-memory-vault` | Writes are create-only and **always unreviewed** |
| `nexus` | Masks secrets and PII before egress |
| `codescene` | Read `skills/codehealth-mcp/SKILL.md` for data boundaries |
| `filesystem`, `devfleet` | Broad local filesystem and agent-dispatch blast radius |

A memory server that writes unreviewed content into an agent's context is a
prompt-injection surface. See [agentic-security.md](agentic-security.md#memory).

---

## Adding a server

1. Copy the entry from `config/mcp-servers.json.template`.
2. **Convert the schema.** `mcpServers` → `mcp.servers`; `command` + `args`
   → array `command`; `type: "http"` → `type: "local" | "remote"`.
3. **Pin every version.** No `@latest`.
4. Put credentials in environment variables, never inline.
5. Add `read` + `external_directory` permissions for anything outside the config
   directory.
6. Re-run `.\scripts\verify-setup.ps1` and confirm the server shows `✓`.
7. Count your tools. Every server costs context on every step.
