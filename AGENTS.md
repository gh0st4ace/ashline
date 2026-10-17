# AGENTS.md

Operating instructions for agents and humans working in this repository, and
the methodology this workbench is built on.

Read this file first. It is the cheapest file in the repo and it prevents the
expensive mistakes documented in [docs/methodology.md](docs/methodology.md).

---

## 0. The one rule that outranks convenience

**Label every claim: `verified`, `reported`, or `inferred`.**

- **verified** — you ran an instrument and saw the result. Name the instrument.
- **reported** — a source, a document, or an upstream project claims it. Name the
  source. A claim made by a summary is *reported*, even when the summary is
  correct.
- **inferred** — you reasoned it from other facts. Say what you reasoned from.

These are different facts and they are written differently. Never let certainty
rest on an unverified base, and never upgrade `reported` to `verified` because
it sounds right.

Membership in a collection is not endorsement and not evidence of capability.

---

## 1. Instrument before you theorize

The most expensive failure mode in this domain is a confident instrument
producing a confident wrong answer, and the wrong answer being believed. It has
happened here, repeatedly, and each time it cost hours.

Before acting on anything consequential:

1. Name **two or three live alternative readings** of the evidence.
2. Say **what observation would prove your conclusion wrong**.
3. Go get it — one targeted `Grep`, one `Read`, one tool call. Do not infer.

### Instruments must themselves be instrumented

| Trap | Rule |
| --- | --- |
| A tool resolving on `PATH` | Execute it and read its output. Resolution proves nothing. |
| A traceback used as a banner | Reject `Traceback (most recent call last):` as success. |
| A read whose count exceeds the buffer | Never trust a reported count without checking it fits. |
| An alignment that silently reads the wrong field | Verify the offset with a second, independent method. |
| A decompiler rendering a stub as `return;` | A check that distinguishes nothing is not evidence. |
| A single-method confirmation | Two independent instruments, or it is not confirmed. |
| Client version drift | Re-derive per build. Absolute addresses are never recorded. |

`verify-setup.ps1` implements all of these. Read it before modifying it.

---

## 2. Routing is a protocol, not a keyword match

Skill selection is gated. Load in this order:

1. `overview` — only when the question is about what exists in a collection or
   where a resource belongs.
2. **Exactly one** domain skill for the boundary that dominates.
   A second only when a second boundary genuinely dominates.
3. Read the **actual** file for every project named. Never describe a project
   from memory. Never `Grep` or `Glob` an entire collection.
4. Read primary sources only when a summary cannot settle the question.
5. `research-rigor` for any consequential or disputed claim.

Full table in [docs/skills-catalog.md](docs/skills-catalog.md).

---

## 3. Collections are read-only dependencies

`D:/opencode/*` collections are clones of other people's repositories.

- **Never edit** them. The permission matrix in `opencode.jsonc` denies `edit`
  on every one and that deny is intentional.
- **Never vendor** them into this repo. They are declared with a pinned commit
  in [docs/collections.md](docs/collections.md).
- **Never glob or grep across them** without a specific filter. 21 GiB will
  exhaust the context window and produce a *worse* answer, not a faster one.
- Delegate bulk searching to a subagent and keep only the paths and summaries you
  need.

---

## 4. Kernel and driver work

Static and passive by default. **Dynamic tests happen in a VM, never on the
host.**

This is not a scope limitation. It is rollback discipline: a malformed `.sys`
blue-screens the machine, and a snapshot is the only cheap way back.

```powershell
.\scripts\vmhelper.ps1 status
.\scripts\vmhelper.ps1 snap pre-test
# ... test ...
.\scripts\vmhelper.ps1 rollback
```

Other non-negotiables:

- BYOVD means *legitimately signed but vulnerable*. Check the vendor advisory for
  the **fixed** version before calling a matched build unpatched.
- `Filename` is never proof. Hash and version provenance are.
- The `kernel-sec` falsifier convention applies: a claim needs a source, a date,
  affected versions, a confidence, and a falsifier.

---

## 5. Findings are stated as module + RVA

**Never record an absolute address.** ASLR makes it wrong the moment the process
restarts; the RVA survives.

```
Bad:  health is at 0x7FF72F330000 + 0x9004
Good: health is f32 at module_base + 0x9004
```

State the client build the offset was verified against. Re-derive per build.

---

## 6. Keep the context window affordable

The failure mode is a session that grows to 1500+ messages until the provider
rejects requests. Three habits prevent it:

- **Read a bounded region.** `offset`/`limit`, not whole files. `docs/HANDOFF.md`
  in a sibling project was 4213 lines; there is a `state.py` that prints a
  summary instead.
- **Delegate breadth.** Subagents return paths and summaries, not dumps.
- **Load one skill per problem.** Two at most.

---

## 7. Configuration facts worth knowing

| Fact | Why it matters |
| --- | --- |
| Config root is `~/.config/opencode` | Everything lives here. |
| **Never work from `C:\WINDOWS\system32`** | Each MCP server is spawned per directory; the tool set doubles (measured: 368 instead of 184). |
| `opencode.jsonc` is JSONC, not JSON | Only full-line `//` comments are stripped by the bundled reader. |
| Plugin versions are pinned, not `@latest` | `@latest` re-resolves on every load and leaves `.staging-*` directories behind. 746 MB were reclaimed this way. |
| `default_agent` is deliberately absent | A default agent pinned to a free model makes every new session fail with 429 when the quota runs out. |
| Skill roots are **five**, not three | Two are discovered by default. Counting only the configured roots undercounts by a third. |

---

## 8. Verify before you claim

```powershell
.\scripts\verify-setup.ps1     # toolchain and wiring, always exits 0
py -3 .\scripts\doctor.py      # runtime health, exits 0/1/2 — CI-usable
```

`doctor.py` is the only instrument here that returns non-zero, which makes it the
only one usable as a gate.

---

## 9. Documentation discipline

When a claim is superseded:

- **Strike it in place** and write what refuted it and which instrument did.
- **Do not delete it.** The wrong reasoning stays visible, so nobody re-derives it.

This is not stylistic. A deleted wrong claim is a claim someone will re-prove
next month.

---

## 10. Safety boundaries

- Memory acquisition against a **live third-party anti-cheat** is out of scope for
  this workbench. Own projects, offline sessions, and lab benches are in scope.
  See [DISCLAIMER.md](DISCLAIMER.md).
- Do not load kernel anti-cheat or vulnerable-driver components on the host.
- Do not add capability claims to a collection page to make it look better than
  its source code supports.

---

## Repository map

```
AGENTS.md                  this file
README.md / README.ru.md   entry points
docs/                      guides, one topic each
agents/                    4 authored domain agents
.agents/skills/            5 authored skills (published to skills.sh)
scripts/                   20 maintenance scripts
config/                    sanitized config templates
knowledge/game-lab/        50-game registry, engine detection
knowledge/kernel-sec/      driver feed, evidence sheets, triage
```

Third-party source is **not** vendored. See [docs/collections.md](docs/collections.md).
