# Reference collections

7 collections, 21.2 GiB. **Declared as dependencies. Never vendored.**

---

## Why not vendor

| Argument | Consequence if ignored |
| --- | --- |
| They are other people's repositories | Republishing MIT work under this repo's name |
| They move | Every upstream commit breaks the vendored copy |
| GitHub's per-file limit is 100 MB | `awesome-game-security-archive` cannot be pushed at all |
| 21.2 GiB | Repo becomes unusable |

So: pinned commit, declared license, fetched by script.

---

## The 18 GiB archive

**The single largest object in this environment, and the one most likely to be
forgotten about.** It deserves its own section.

| Property | Value |
| --- | --- |
| Path | `D:/opencode/awesome-game-security-archive` |
| Size | **18.19 GiB** — 74% of everything under `D:\opencode` |
| Contents | `archive/<owner>/<repo>/` — 4,086 primary-source mirrors |
| Upstream | [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security), same commit as the index |
| License | MIT |
| Fetch | `scripts/update-awgs-archive.ps1` |
| Updater | `update-awgs-archive.ps1`, `-MaxAgeDays 7`, `-Force` to bypass |

### Why it is a tarball and not a git clone

This is the whole reason it is a separate object with its own script.

> Git lazy-blob fetching at 18 GiB **stalls**.

A partial or blobless clone does not help — the archive tree itself is the
bulk, so it has to be fetched. The script downloads the GitHub source tarball
instead.

### Its flags exist because of specific failures

| Flag / behaviour | Why |
| --- | --- |
| `--retry 20 --retry-delay 10` | The transfer is long enough that a single blip used to abort it |
| `--connect-timeout 60` | A hung connection otherwise waits forever |
| `--speed-limit 20000 --speed-time 120` | Abort if throughput drops below ~20 KB/s for 120 s. A stalled transfer looks identical to a slow one otherwise |
| Download to `$Cache.part`, rename on success | A partial file must never be mistaken for a complete one |
| `ArchiveDir` → `.old`, `.new` → `ArchiveDir`, delete `.old` | **Atomic swap.** The mirror is never half-written |
| 7-day cache gate | 18 GiB is not worth re-downloading weekly |
| Logs size and file count | The only way to notice the mirror silently became empty |

### How to use it

Only as a last resort, and only for one project:

> A summary in `awesome-game-security` says what a project *claims*.
> The archive holds what the project *is*.

Read one `description/<owner>/<repo>/description_*.txt` first. If it settles
the question, stop. If it genuinely cannot — the summary is wrong, the version
differs, you need the actual source to check a claim — then target exactly one
`archive/<owner>/<repo>/` directory.

**Never glob or grep across it.** 4,086 mirrors at 18 GiB will exhaust the
context window and produce a worse answer, not a faster one. Delegate to a
subagent and keep only the paths and summaries you need.

### It is `hidden: true`

In `config/opencode.jsonc.template` this collection carries `"hidden": true`, so
it stays out of the per-step context until you actually open it. A 18 GiB
reference that the agent reads on every step is worse than no reference.

### Reproducing it

```powershell
.\scripts\update-awgs-archive.ps1 -DryRun   # does it take the flag?
.\scripts\update-awgs-archive.ps1           # fetch if older than 7 days
.\scripts\update-awgs-archive.ps1 -Force    # re-download regardless of age
```

Expect hours. It is the dominant cost of `-Profile full`.

---

## The manifest

| Alias | Path | Size | Upstream | License | Used for |
| --- | --- | ---: | --- | --- | --- |
| `awesome-game-security` | `D:/opencode/awesome-game-security` | 3.05 GiB | [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) | see upstream | ~40,871 project summaries, 4,105 wiki pages, 13 domain skills |
| `game-security-archive` | `D:/opencode/awesome-game-security-archive` | 18.19 GiB | same (archive tree) | see upstream | 4,086 primary-source mirrors |
| `hack-skills` | `D:/opencode/hack-skills` | 0.01 GiB | [yaklang/hack-skills](https://github.com/yaklang/hack-skills) | see upstream | 103 practical security skills |
| `cyber-skills` | `D:/opencode/cybersecurity-skills` | 0.04 GiB | [mukul975/Anthropic-Cybersecurity-Skills](https://github.com/mukul975/Anthropic-Cybersecurity-Skills) | see upstream | 818 skills, 291 MITRE techniques |
| `game-hacking-refs` | `D:/opencode/game-hacking-references` | <0.01 GiB | [dsasmblr/game-hacking](https://github.com/dsasmblr/game-hacking) | MIT | Curated game-RE tutorials and tools |
| `hacking-online-games` | `D:/opencode/hacking-online-games` | 0.06 GiB | [dsasmblr/hacking-online-games](https://github.com/dsasmblr/hacking-online-games) | MIT | GameGuard architecture, server-side emulation, pointer scanning, 8 PDFs |
| `rea` | `D:/opencode/rea` | 0.01 GiB | [morluto/rea](https://github.com/morluto/rea) | MIT | 170-tool MCP server; `docs/` holds the provider guides |

Reproduction paths differ. `cyber-skills` and `hack-skills` are plain clones.
`awesome-game-security` is a **blobless sparse partial clone**
(`sparse-checkout: .claude description scripts wiki`). The archive mirror is a
**tarball**, not git, because git lazy-blob fetching stalls at 18 GiB.

Exact pinned SHAs live in `collections.lock.json` at the repo root. That file is
the authoritative record; this table is the human-readable one.

---

## Fetching

```powershell
# Full fetch
.\install.ps1 -Profile full

# Refresh (the /refresh command runs these three in order)
.\scripts\update-awgs.ps1          # sparse pull + re-link
.\scripts\update-awgs-archive.ps1  # tarball, atomic swap, 7-day cache gate
.\scripts\update-hack-skills.ps1   # pull + re-link + prune
```

---

## How they are used

| Collection | Access pattern |
| --- | --- |
| `awesome-game-security` | `Grep` with a specific owner/repo/keyword → read **one** `description_*.txt` → archive mirror only if the summary cannot settle it |
| `game-security-archive` | Target one project. ~18 GiB; never search broadly |
| `hack-skills` | 93 of 103 linked as junctions. Read one leaf `SKILL.md` |
| `cyber-skills` | **Largest by count.** Grep directory names for a keyword, then read exactly one `SKILL.md`. Use `index.json` for official titles, `ATTACK_COVERAGE.md` for coverage questions |
| `game-hacking-refs` | Read when locating a technique or tool |
| `hacking-online-games` | Read the PDFs when the technique question needs the original |
| `rea` | Read **one specific guide** when a provider or platform workflow needs explaining. The live capability is the `rea` MCP server, not this directory |

---

## Search hygiene

**Never `Glob` or `Grep` across `description/` or the archive without a filter.**

- Delegated to a subagent (`explore` / `general`) which returns only paths and
  summaries.
- One filter minimum, always specific: an owner, a repo, or a keyword.
- One `SKILL.md` per question. A handful of reference files once decided.

Local skill names collide silently across discovery roots when installing from
upstream — one case was skipped after a `~/.agents/skills` content check found a
same-named skill already present.

---

## Read-only, enforced

Every collection has `read` and `external_directory` granted and **`edit` denied**
in the permission matrix.

The deny is the load-bearing half. Without it, an agent asked to "fix a typo in
the skill description" mutates a third-party repository in place, and the next
`git pull` conflicts with no record of who changed what.

---

## Adding a collection

1. Clone it somewhere outside the config directory.
2. Add `read` + `external_directory` + **`edit: deny`** to the permission matrix.
3. Add an entry to the `references` block in `opencode.jsonc` with a description
   that says *when to use it*, not what it contains.
4. Add it to the manifest and `collections.lock.json` with a pinned SHA.
5. Add a `Test-Path` check to `verify-setup.ps1`.
6. Document the access pattern in this file.

If it will be linked as skills, write a linking script that uses
`[System.IO.Directory]::Delete($link, $false)` for cleanup. `Remove-Item -Recurse`
on a junction follows the link and deletes the upstream directory.

---

## Membership is not endorsement

A project appearing in `awesome-game-security` is an **index entry**, not a
recommendation, and not evidence that the tool does anything.

Keep these separate in every document:

| Layer | Meaning |
| --- | --- |
| Repository metadata | Someone published it under that name |
| Maintained summary | A maintainer wrote a paragraph about it |
| Primary-source evidence | The code does what the summary says |
| Inference | What you concluded from the above |
| Recommendation | What you suggest, and why |

Write them differently. A `reported` claim quoted as `verified` is the specific
error this repository is built to avoid.
