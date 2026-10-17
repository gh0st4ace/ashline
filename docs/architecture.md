# Architecture

How the pieces fit, and the reasoning that produced each arrangement.

---

## The shape

```
                       ┌─────────────────────────────┐
                       │        AGENTS.md            │
                       │  methodology, loaded first   │
                       └──────────────┬──────────────┘
                                      │ routes by protocol
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
┌───────────────┐          ┌──────────────────┐          ┌──────────────────┐
│    Skills     │          │  Reference       │          │    MCP servers   │
│  174 · 5 roots│          │  collections · 7 │          │  6 servers       │
│               │          │  21.2 GiB        │          │  277 tools       │
│  never whole- │          │  never wholesale │          │                  │
│  loaded       │          │  read-only       │          │                  │
└───────┬───────┘          └────────┬─────────┘          └────────┬─────────┘
        │                           │                             │
        └───────────────────────────┴─────────────────────────────┘
                                    ▼
                       ┌─────────────────────┐
                       │  Agents (4)         │
                       │  domain specialists │
                       └──────────┬──────────┘
                                  ▼
                       ┌─────────────────────┐
                       │  Scripts (20)       │
                       │  install · verify   │
                       │  update · VM        │
                       └─────────────────────┘
```

Two orthogonal halves. **Skills and collections** decide *what to read*.
**Scripts** decide *whether the environment can do it at all*.

---

## Why collections are dependencies

7 collections, 21.2 GiB:

| Collection | Size |
| --- | ---: |
| `awesome-game-security` | 3.05 GiB |
| `awesome-game-security-archive` | 18.19 GiB |
| `cybersecurity-skills` | 0.04 GiB |
| `hacking-online-games` | 0.06 GiB |
| `hack-skills` | 0.01 GiB |
| `game-hacking-references` | <0.01 GiB |
| `rea` | 0.01 GiB |

Vendoring any of it would mean republishing other people's MIT work under this
repo's name, would break on every upstream move, and would exceed GitHub's
100 MB per-file limit outright. So they are declared with a pinned commit and
fetched by script. See [collections.md](collections.md).

---

## The counting bug

An earlier revision of the inventory claimed 109 skills. The real number was 174.

**Cause.** Only the three roots named in `skills:` were counted. OpenCode also
discovers `~/.agents/skills` and `~/.config/opencode/skills` by default — 66 more
skills. The error was undercounting by a third.

**Why it mattered.** A fix applied to only the configured roots leaves two
thirds of the catalog untouched. Both `verify-setup.ps1` and `doctor.py` now
check all five roots.

**Why it is still a trap.** The count is not derivable from the config alone. If
you add a root, the count changes and nothing tells you. This is the kind of
inference that must be measured, not reasoned about.

---

## Skill discovery: five roots, zero collisions

| Root | Count | Loaded via |
| --- | ---: | --- |
| `gameskills/` | 12 | `skills:` — junctions |
| `hackskills/` | 93 | `skills:` — junctions |
| `reaskills/` | 3 | `skills:` — junctions |
| `~/.agents/skills` | 64 | default discovery |
| `~/.config/opencode/skills` | 2 | default discovery |

Verified zero name collisions, so nothing shadows anything else.

### The junction deletion trap

NTFS directory junctions behave unlike symlinks in one way that matters:
`Remove-Item -Recurse` on a junction **follows the link and deletes the real
directory** in the upstream repo.

Both linking scripts use:

```powershell
[System.IO.Directory]::Delete($link, $false)
```

which removes the junction itself. If you write a maintenance script that
deletes skill links, use that and not `Remove-Item`.

### One copy, not a link

`awesome-game-security`'s `reverse-engineering` skill is installed as a **renamed
copy** at `skills/game-security-reverse-engineering`, not a junction, because the
upstream id would shadow the general-purpose `reverse-engineering` skill in
`~/.agents/skills`. `sync-awgs-skills.ps1` rewrites its frontmatter and writes
**UTF-8 without BOM** — `Set-Content -Encoding utf8` in PowerShell 5.1 emits a
BOM that breaks YAML frontmatter in some readers.

---

## Routers stay off-catalog

`yaklang/hack-skills` has 103 skills on disk; 93 are linked. Ten are excluded:

`hack`, `api-sec`, `auth-sec`, `recon-for-sec`, `business-logic-vuln`,
`injection-checking`, `file-access-vn`, `recon-and-methodology`,
`api-recon-and-docs`, `api-auth-and-jwt-abuse`.

They are **routers**, not leaves. `hack`'s catch-all description won the match on
nearly every security task and then applied its own authorization gate, which is
why it is off-catalog. The files stay readable on disk at
`D:/opencode/hack-skills/skills/<id>/SKILL.md`.

Routing to a leaf directly is faster and does not trip a gate meant for a
different entry point.

---

## The permission matrix

`opencode.jsonc` grants `external_directory` and `read` on every collection and
**denies `edit`**. Three rules per collection — 21 rules total, in this order.

The deny is the load-bearing half. Without it, "fix a typo in the skill
description" mutates a third-party repo in place and the next `git pull`
conflicts blind. A deny you did not write down is a deny that will be
misunderstood.

---

## Plugin surface

Two plugins, both version-pinned:

| Plugin | Purpose |
| --- | --- |
| `opencode-mem` | Persistent memory; vector store + local web UI |
| `adaptive-thinking` | Reasoning-effort control |

Pinned, never `@latest`. `@latest` re-resolves on every load and leaves
`.staging-*` directories behind — 746 MB were reclaimed by switching to pins.

### An inert entry plugin

`plugins/index.ts` exports `{ id, setup }` with an empty `setup`, on purpose.
OpenCode auto-loads every file in the directory *and* the `./plugins` entry from
config; loading a barrel that registered hooks would initialize each hook twice.
The file must still be a valid v2 definition or the TUI marks it failed and shows
it red.

---

## Config decisions worth remembering

Each of these was made against a failure.

| Decision | Failure it prevents |
| --- | --- |
| No `default_agent` | A default pinned to a free model makes every new session fail with 429 when quota runs out |
| Pinned plugin versions | `.staging-*` debris on every load |
| `small_model` set | Compaction and title generation competing with the working context |
| `tool_output` 256 KB / 2000 lines | One command eating a quarter of the context |
| `compaction` has only supported keys | Legacy keys silently dropped with a warning |
| Comments above every deviation | The next person "fixes" a deliberate decision back |

The last one is the important one. `opencode.jsonc` opens with a block explaining
each divergence and why. **If you change one, update that block in the same
commit** or you will spend an afternoon reverting a decision that was made on
purpose.

---

## Memory: capture does not work here

`opencode-mem` auto-capture requires the provider to return structured output.
`opencode/space-bunny-free` does not provide it, so capture runs in the
background and does nothing, silently.

**Measured, not assumed:** after eight hours of session with many idle periods,
the store still held exactly one memory — the one added by hand.

So the rule is explicit: **write memories yourself** before a session ends.
`add` / `search` / `list` all work; only auto-capture is dead.

Two config values must not be reverted without re-indexing:

| Setting | Value | Why |
| --- | --- | --- |
| `embeddingUseTaskPrefixes` | `true` | Nomic needs asymmetric prefixes, or only verbatim wording matches |
| `similarityThreshold` | `0.45` | Default 0.6 was too strict for short queries |

Search behaviour, measured: short keyword queries match well ("Ghidra", "диск
D"). Long paraphrases with different wording return nothing. Precision verified
at 100% — four correct hits, zero false positives against four distractors.

---

## Update flow

Two collection updates have Task Scheduler launchers. Nothing else runs on a
schedule — health checks and installers are manual by design.

```
run-awgs-update.cmd  → update-awgs.ps1        # sparse pull + re-link
run-awgs-archive.cmd → update-awgs-archive.ps1  # 18 GiB tarball, atomic swap
                      update-hack-skills.ps1    # pull + re-link + prune
                      ↓
                      verify-setup.ps1, doctor.py
```

`/refresh` runs the first three in order.

Design points that matter:

- **`reset --hard` + `clean -fd`, not a plain pull.** Upstream renames must
  apply; a plain pull leaves stale directories behind.
- **The 18 GiB archive is a tarball, not git.** Git lazy-blob fetching at that
  size stalls. The swap is atomic — the mirror is never half-written.
- **All git calls pass `-c safe.directory=<repo>`** rather than mutating global
  config, because Task Scheduler runs under a different account than the clone
  owner.
- **`update-awgs.ps1` always exits 0.** A failed pull leaves the current
  checkout intact. It is a background refresh, not a gate.

One known inconsistency: `sync-awgs-skills.ps1:43` calls a bare
`git -C $Repo pull` without `-c safe.directory=`. Harmless today because
`update-awgs.ps1` always passes `-SkipPull`, but it would fail on
dubious-ownership if run standalone under the scheduler account.
