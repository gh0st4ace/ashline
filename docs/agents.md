# Agents

4 authored domain agents. Specialists, not generalists — each exists because a
general agent gets this class of question wrong.

---

## The four

| Agent | Domain | Why it exists |
| --- | --- | --- |
| `spacebunnyjb` | General operator agent | Default working agent; reasoning-effort management |
| `gamesec` | Game security research | Routes to the awesome-game-security domain skills and reads real project sources before answering |
| `kernel-driver-analyst` | Windows drivers / BYOVD | Backed by the `kernel-sec` workspace; static and passive-first |
| `ksec-validator` | Independent validation | Restates the claim under test, checks it against primary sources and local evidence, **attempts active falsification** |

Files live in `agents/`.

---

## `spacebunnyjb`

The default agent, pinned to `opencode/space-bunny-free`.

Manages reasoning effort actively and treats resource use as a duty. The
discipline that matters: **lower effort before trivial turns, raise it for
ambiguity, debugging, risky changes, and multi-step synthesis.** Reassess at
turn start, after meaningful new evidence, and when the task shifts. Never leave
the level unchanged by inertia, and never answer a trivial turn without
considering a downshift.

### Why `default_agent` is absent from the config

Deliberate, and the comment block in `opencode.jsonc` says so.

An agent pinned to a free model as the config default makes **every new session**
fail with `FreeUsageLimitError` (429) once the quota is exhausted. It was also
the direct cause of `Session.AgentNotFoundError` (3× on 14.10 at 15:53). Without
the line, the agent is chosen in the UI and remembered per session.

If you add `default_agent` back, you are re-introducing a known failure.

---

## `gamesec`

Game-security research agent. Routes to the awesome-game-security domain skills
and **reads real project sources before answering**.

Its core obligation is the routing protocol in
[skills-catalog.md](skills-catalog.md#routing-protocol): load `overview` when
the question is about the collection, load exactly one domain skill, and read
the actual `description/<owner>/<repo>/description_*.txt` for every project
named. Never describe a project from memory.

Collection membership is not endorsement and not evidence of capability. It
keeps repository metadata, maintained summaries, primary-source evidence,
inference, and recommendation clearly separated.

---

## `kernel-driver-analyst`

Windows kernel-driver / BYOVD security analyst, backed by the `kernel-sec`
workspace: LOLDrivers feed cache, triage scripts, evidence sheets.

| Behaviour | Rule |
| --- | --- |
| Triage | Static and passive-first. `driver_triage.py` never loads, installs, or runs a driver |
| Surface review | IOCTL handlers, device ACLs, callback registration, IRQL discipline |
| Root-cause research | Trace to primary sources; a filename match is not a finding |
| Report drafting | Cite provenance: hash, signer, version, date |
| **Dynamic tests** | **VM only, via `vmhelper.ps1`. Never on the host.** |

BYOVD specifically means *legitimately signed but vulnerable*. Check the vendor
advisory for the **fixed** version before calling a matched build unpatched.

---

## `ksec-validator`

The most valuable of the four, because its job is to **disagree**.

When a conclusion matters, a second agent that agrees with the first is close to
worthless — shared context produces correlated error. This agent exists to break
that.

Its protocol:

1. **Restate the claim under test** in its own words. If it cannot restate it,
   the claim was not clear enough to test.
2. **Check it against primary sources** and local evidence.
3. **Attempt active falsification** — go looking for the observation that
   disproves it, not the one that supports it.
4. **Return every item labelled** `verified` / `reported` / `inferred`.

Use it after a `measured` finding, before writing it down. It costs one
subagent call and has caught real errors.

---

## Writing a new agent

An agent earns its place by being *worse at general work and better at
something*. If it is only a shorter prompt, delete it and use a skill.

### Shape

```markdown
---
description: <when to reach for this, and what it is NOT>
mode: subagent
model: <optional pin>
temperature: <optional>
---

# <Name>

<One paragraph: the domain, and the specific failure mode this agent exists to
prevent.>

## Routing

<Which skills, in which order, with which stop conditions.>

## Obligations

<The things it must always do. Non-negotiable.>

## Never

<The failure modes it must never produce.>
```

### Rules learned here

- **A general agent with a domain prompt is not a specialist.** The routing table
  and the "never" list are the agent. The preamble is not.
- **State the failure mode, not just the domain.** "Covers game security" does
  nothing. "Does not answer from memory about a project it has not read the
  summary of" prevents a specific, observed error.
- **Route to exactly one domain skill by default.** Two only when two boundaries
  genuinely dominate. Over-routing costs context and produces mush.
- **Pin the model** if the agent needs consistent behaviour. An unpinned agent
  silently changes under you.
- **Keep the validator separate from the doer.** Same agent cannot both produce
  and falsify.

---

## Delegating to these agents

```text
Subagent: gamesec
Question: <one specific question, with the owner/repo if a project is named>

Subagent: kernel-driver-analyst
Artifact: <path to .sys>
Task: surface review

Subagent: ksec-validator
Claim under test: <the exact sentence from your finding>
```

Give the validator the **exact claim**, not a summary of it. Restating it is
part of its job, and a paraphrase hides the imprecision you want it to find.
