# Skills catalog

174 skills across 5 discovery roots. Read this when choosing one.

---

## Routing protocol

Skill selection is gated. Load in this order:

1. **`overview`** — only when the question is about what exists in a collection,
   which category something belongs to, or where a source should be placed.
2. **Exactly one domain skill** for the boundary that dominates. A second only
   when a second boundary genuinely dominates.
3. **Read the actual file** for every project named:
   `description/<owner>/<repo>/description_en.txt`, or `description_ru.txt` when
   replying in Russian. Never describe a project from memory. Always `Grep` with
   a specific owner, repo, or keyword — never glob or grep the whole tree.
4. **Primary sources** only when a summary cannot settle the question.
5. **`research-rigor`** for any consequential or disputed claim. State version,
   environment, limitations, and uncertainty.

Two at most, and only when two boundaries genuinely dominate.

---

## Roots

| Root | Count | Loaded via | Source |
| --- | ---: | --- | --- |
| `gameskills/` | 12 | `skills:` | gmh5225/awesome-game-security |
| `hackskills/` | 93 | `skills:` | yaklang/hack-skills |
| `reaskills/` | 3 | `skills:` | REA contributors |
| `~/.agents/skills` | 64 | default | mixed upstream |
| `~/.config/opencode/skills` | 2 | default | authored locally |

Verified **zero name collisions** across all five.

---

## Game-security routing table

| If the task centres on | Load |
| --- | --- |
| Layered anti-cheat, detection evidence, telemetry, enforcement tradeoffs | `anti-cheat` |
| PCIe/FPGA DMA reads, IOMMU, host-mediated memory acquisition | `dma-attack` |
| Unreal/Unity/Source/Godot internals, object models, SDK or asset extraction | `game-engine` |
| Cheat capability classification, injection, overlays, memory manipulation | `game-hacking` |
| Game binaries, anti-cheat components, protection binaries, dumps, traces | `game-security-reverse-engineering` |
| Multiplayer authority, RPC, session, replication, inventory, economy, replay | `game-server-security` |
| Build, launcher, update channel, distribution, mods, plugins, signing | `game-supply-chain-security` |
| D3D/DXGI/OpenGL/Vulkan, rendering, overlays, capture, frame measurement | `graphics-api` |
| Linux, SteamOS, Steam Deck, Wine, Proton, seccomp/LSM, ELF evidence | `linux-platform-security` |
| Android/iOS game trust boundaries, attestation, instrumentation, signing | `mobile-security` |
| Finding or classifying resources, repository maintenance, coverage gaps | `overview` |
| Verifying a consequential claim against primary sources | `research-rigor` |
| Windows driver trust, callbacks, IRQL, kernel memory, DSE, PatchGuard, HVCI | `windows-kernel` |

`game-security-reverse-engineering` covers game and anti-cheat binaries. For
non-game binaries use the general `reverse-engineering` skill.

Skills can be forced with `@<skill-id>`. Their `SKILL.md` files are routing
layers; topic catalogs live in `references/` and are read on demand.

---

## Reverse-engineering routing

| Situation | Load |
| --- | --- |
| Claim depends on a shipped artifact; need evidence not reading | `reverse-engineer-anything` (REA MCP) |
| General technique, no tool named | `reverse-engineering` |
| Game or anti-cheat binaries, protection components, dumps | `game-security-reverse-engineering` |
| Working inside IDA | `ida-reverse`; scripting `rev-idapython` |
| Working inside Ghidra | `ghidra-reverse` |
| Command-line Ghidra bridge / headless decompile | REA MCP with Ghidra provider |
| r2 / rizin from the shell | `radare2` |
| Binary Ninja | `binary-ninja-reverse` |
| Recover a struct or class layout | `rev-struct` |
| Recover function names and signatures | `rev-symbol` |
| APK / Android | `apk-reverse`, `rev-dex-dumper`, `mobile-ssl-pinning-bypass` |
| iOS / IPA | `mobile-reverse`, `rev-ios-dump` |
| Unity IL2CPP | `rev-u3d-dump` |
| Frida instrumentation | `rev-frida` |
| .NET / C# | `dotnet-reverse` |
| Go or Rust binaries | `go-rust-reverse` |
| JavaScript risk engines, anti-bot DSL/VM | `dsl-vm-reverse`, `js-reverse` |
| macOS / Mach-O | `macos-reverse` |
| Comparing two builds, symbol migration | `binary-diff` |
| Patch to exploit (n-day) | `patch-diff-exploit` |
| Protection stripping, canary/ASLR/NX bypass | `binary-protection-bypass`, `anti-debugging-techniques` |
| Packer, VM protection, control-flow flattening | `code-obfuscation-deobfuscation`, `vm-and-bytecode-reverse` |
| Exploitation chain | `pwn-chain`; per-class: `stack-overflow-and-rop`, `heap-exploitation`, `format-string-exploitation`, `kernel-exploitation`, `arbitrary-write-to-rce` |
| Fuzzing | `symbolic-execution-tools` |
| Emulate a fragment in isolation | `rev-unicorn-debug` |

**Do not load two tool-specific skills at once.** They describe different hosts.

`reverse-engineer-anything` is the one that needs no manual tool-driving and is
preferred whenever the task is "explain how this shipped thing works".

---

## Authored skills

These five are in `.agents/skills/` and are this repo's own work.

| Skill | Use when |
| --- | --- |
| `game-engine-detection` | Determining which engine/stack a game uses from verifiable file-tree and PE evidence, before choosing analysis tools |
| `game-memory-lab` | Hands-on memory research: finding a value, tracing pointer chains, correlating writers with disassembly |
| `game-modding-lab` | Choosing the least-complex mod route — official SDK, supported loader, config edits, scripting hooks |
| `anti-cheat-architecture` | Studying protection architecture: trust boundaries, detection surfaces, defense tradeoffs |
| `game-research-tool-discovery` | When a task needs a capability the environment lacks — check installed tooling first, then evaluate, then integrate only if justified |

Plus two local skills in `~/.config/opencode/skills`:
`game-security-reverse-engineering`, `luau-roblox-reverse`.

---

## Routers that stay off-catalog

Ten `hack-skills` routers are deliberately **not** linked:

`hack`, `api-sec`, `auth-sec`, `recon-for-sec`, `business-logic-vuln`,
`injection-checking`, `file-access-vn`, `recon-and-methodology`,
`api-recon-and-docs`, `api-auth-and-jwt-abuse`.

`hack` carries a 657-character catch-all description that won the match on
nearly every security task and then applied its own authorization gate. Routing
to a leaf directly is faster and does not trip a gate meant for a different
entry point.

Files remain readable at `D:/opencode/hack-skills/skills/<id>/SKILL.md`.

---

## Search hygiene

The collections hold ~50,000 files. Reading broadly is the fastest way to burn
the context window and produce a *worse* answer, not a faster one.

- Delegate bulk searching to `explore` or `general`; keep only paths and
  summaries.
- `Grep` on a specific keyword, owner, or repo. Never `Glob` across `description/`
  or the archive.
- Read **one** `SKILL.md` per question, and at most a handful of reference files
  once you have decided you need them.
- Summaries are one paragraph. Do not read a reference file you have not decided
  you need.

---

## The full list

The 174 are enumerated with descriptions in the harness catalog at session
start. This repo ships the routing tables and the discipline rather than
duplicating 174 upstream descriptions that would drift on every upstream pull.

To enumerate locally:

```powershell
$roots = @(
  "$env:USERPROFILE\.config\opencode\gameskills",
  "$env:USERPROFILE\.config\opencode\hackskills",
  "$env:USERPROFILE\.config\opencode\reaskills",
  "$env:USERPROFILE\.agents\skills",
  "$env:USERPROFILE\.config\opencode\skills"
)
$roots | ForEach-Object { "{0,-12} {1}" -f (Split-Path $_ -Leaf),
  (Get-ChildItem $_ -Directory -ErrorAction SilentlyContinue).Count }
```

Five roots, not three. Counting only the configured roots undercounts by a third
— see [architecture.md](architecture.md#the-counting-bug).
