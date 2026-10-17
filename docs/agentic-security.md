# Agentic security

A review of this workbench's own agent setup, using the same evidence discipline
it applies to everything else.

Adapted from `docs/agentic-security.md` in the local security guide
(the-security-guide.md), condensed to what applies here.

---

## The threat model

An agent harness is an attack surface with three distinct classes of risk:

| Class | What it is | Example |
| --- | --- | --- |
| **Supply chain** | Malicious or mutable tooling | A pinned-vs-`@latest` plugin resolving to new code |
| **Context poisoning** | Untrusted content becoming trusted instruction | A web page or a memory entry telling the agent what to do |
| **Blast radius** | What a compromised agent can reach | `filesystem` MCP with a broad root; an elevated tool; `bash` |

Most agent security effort goes to the first. The second is the one that actually
bites, and the third is what determines the blast radius when it does.

---

## 1. Separate the identity first

The single highest-value control. A compromised agent session should not be able
to reach the operator's real identity.

- Run untrusted work under a different account than your daily driver.
- Do not run agent work elevated by default. If elevation is needed, make it an
  explicit, per-operation decision.

This is why `cheat-mcp` reports `is_admin: false` and exposes `elevate` as a
separate opt-in tool rather than running elevated: the elevated path is a
decision, not a default.

> [!IMPORTANT]
> The trade-off is real. Elevated agents can do things unelevated ones cannot —
> driver work, some memory operations. The control is not "never elevate". It is
> "elevate deliberately, per operation, with the identity separated".

---

## 2. Run untrusted work in isolation

Three layers, in increasing cost:

| Layer | Cost | What it stops |
| --- | --- | --- |
| Separate identity | free | Credential theft, profile corruption |
| Container / VM | minutes | Filesystem writes, network reach, persistence |
| Dedicated VM with snapshot | minutes + disk | **Kernel-level damage — BSOD, driver state** |

Kernel anti-cheat and vulnerable-driver tests get the third layer, always.
`vmhelper.ps1` provides `snap` / `rollback` so the cost of trying something is
one command.

> [!WARNING]
> A malformed `.sys` blue-screens the host. There is no partial failure. Snapshot
> before, rollback after, no exceptions.

---

## 3. Restrict tools and paths

### The permission matrix is the primary control

Every reference collection gets `read` + `external_directory` and **`edit: deny`**.

The deny is load-bearing. Without it, "fix a typo in the skill description"
mutates a third-party repository in place and the next `git pull` conflicts with
no record of who changed what.

### Least agency per operation

- Read-only tools by default; write tools only when the task needs them.
- Never a broad-root `filesystem` MCP in a session that also handles untrusted
  input.
- Network egress only where the task requires it.

### The compaction surface

Compaction summarises context into text that becomes the next context. That is a
trust boundary: injected content that survives compaction is now part of the
instruction set.

This workspace's mitigation is bounded context (`tool_output` 256 KB / 2000
lines) and explicit compaction settings, so what gets summarised is limited and
predictable.

---

## 4. Pin everything

| Surface | Rule | Failure it prevents |
| --- | --- | --- |
| `plugins:` | Exact versions | `@latest` re-resolves per load; staging debris; a compromised upstream release lands silently |
| MCP `npx` args | Exact versions | Same, for `@modelcontextprotocol/*` and every community server |
| Collections | Pinned commit | Upstream content changes under you |
| Reference collection data | Refresh date recorded | Stale data presented as current |

Three catalogued MCP entries use `@latest` and should be pinned. The
`plugins:` array is already pinned — 746 MB of staging debris were reclaimed when
it was changed.

---

## 5. Sanitize what the model sees

Content the agent reads is data, not instruction — even when it looks like
instruction.

- Hidden Unicode: zero-width characters, bidi control characters that reorder
  rendered text, homoglyphs.
- HTML comments and invisible blocks in fetched content.
- Attachments: sanitize before the model sees them, not after.
- **Linked content too** — a page that agrees with you is still untrusted input.

The 34-server MCP catalog includes servers whose own descriptions warn about
this: `memxus` flags memory-poisoning prompt injection and says to review stored
memories before using them in production agents; `ecc-memory-vault` states its
writes are create-only and **always unreviewed**.

---

## 6. Memory is a trust boundary

A memory store is a write path into future context. Three failures to guard:

| Failure | Guard |
| --- | --- |
| **Poisoning** — untrusted content stored as instruction | Never auto-capture untrusted sources; review before promote |
| **Staleness** — an old decision re-derived as current | Tag memories with the decision date; prefer explicit `add` over silent capture |
| **Leakage** — secrets or PII persisted and later injected | Never store credentials; scrub before capture |

This workspace disables auto-capture entirely, because auto-capture requires
provider structured output which the pinned free model does not return — it runs
in the background and silently does nothing. That failure is benign (no
poisoning) and also means **nothing is remembered unless written by hand**:

> Write memories yourself before a session ends. `add` / `search` / `list` all
> work; only auto-capture is dead.

Memory search is measured at 100% precision on this host — four correct hits,
zero false positives against four distractors. Keep it that way; a memory store
that injects wrong context is worse than none.

---

## 7. Approval boundaries

Agentic work spans a spectrum, and the amount of human approval should scale
with the irreversibility of the action.

| Action | Approval |
| --- | --- |
| Read a file | none |
| Edit a file in the project | none |
| Run a read-only command | none |
| Install software | confirm |
| Change system state (PATH, registry, services) | confirm, with the plan shown |
| Network egress with payload | confirm |
| Push, publish, delete | confirm, showing exactly what |
| Commit-rewrite, force-push, `DROP` | explicit, per occurrence |

`/verify` demonstrates the pattern this repo uses throughout: it runs the check
and **changes nothing before you have seen the output**.

---

## 8. Observability

You cannot debug what you cannot see.

- Log tool invocations with enough context to reconstruct a decision.
- Bound the logs — a multi-GB log is unreadable and unbounded. `doctor.py`
  scans the **last 4000 lines** with `collections.deque(maxlen=4000)` for exactly
  this reason.
- Make failures legible: a check that reports `[BAD]` with a cause and a remedy
  is worth ten that report "ok".

---

## 9. Kill switches

- Bound context so the session cannot grow without limit.
- Timeouts on every long-running operation. `hashcat -v` is VERBOSE mode and
  starts a cracking run that never returns — which is why `verify-setup.ps1`
  probes `--version` instead.
- Never probe a GUI binary by launching it. `windbg -?` opens the GUI.
- A repeatable `rollback` is the kill switch for destructive work.

---

## 10. The minimum bar checklist

- [ ] Separate identity for agent work
- [ ] Sandbox or VM for anything touching the kernel
- [ ] `edit: deny` on every third-party path
- [ ] Every version pinned, no `@latest`
- [ ] Untrusted content sanitized before it reaches the model
- [ ] Memory writes reviewed, not automatic
- [ ] Approval required for irreversible actions
- [ ] Logs bounded and legible
- [ ] A tested rollback path
- [ ] Context bounded so sessions cannot run away

---

## Apply this to your own setup

`security-audit` and the `agent-security-hardening` skill cover the general case.
This page covers what is specific to *this* workbench: the six active MCP
servers, the read-only collection matrix, the VM discipline, and the disabled
memory auto-capture.
