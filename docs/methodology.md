# Methodology

The reason this project exists as a document rather than a pile of tools.

Four failure modes drove everything below. Each is described with what it cost,
because a rule without its failure gets relaxed the first time it is inconvenient.

---

## 1. The instrument lied, and the lie was believed

**What happened.** Reading a kernel module list, the code read at offset `+4`
instead of `+8` and then trusted a reported count of 207 entries when only 112
fit the buffer. The read returned `0xC0000005`. The conclusion drawn from it was
"driver not loaded" — confidently, and wrong.

**The compounding mistake.** Separately, a Ghidra decompile of a KMDF driver
rendered as `return;` was used to conclude something about the driver's
infrastructure. That rendering cannot distinguish the hypotheses. A check that
distinguishes nothing is not evidence.

**Cost.** Hours, and a wrong architectural conclusion that shaped later work.

**The rule that came out of it.**

> An instrument must be instrumented. Verify the reading, not just the read.

Concretely, every rule in [AGENTS.md §1](AGENTS.md#1-instrument-before-you-theorize)
exists because of a specific incident. `verify-setup.ps1` enforces them
mechanically:

| Check | What it rejects |
| --- | --- |
| Tools are **executed**, not resolved | A shim on `PATH` pointing at nothing |
| Banner regex | `Traceback (most recent call last):` as a success line |
| `Math.Min` on every substring | A short banner throwing and misreporting the check |
| Buffer-fit assertions | A count that could not fit the buffer |
| Independent second method | A single-method confirmation |

---

## 2. A check that cannot distinguish is not a check

**What happened.** A decompiler emitted `return;` for a function, and that
output was treated as a finding.

**The rule.**

> Before citing a check as evidence, ask: what observation would have produced a
> different result?

If nothing would have, the check has no discriminating power and cannot support
a conclusion. This applies to false readings *and* to false confidence — a check
that always passes is as useless as one that always fails.

`verify-setup.ps1` has this weakness in one documented place: its `Check()`
helper treats any non-empty return as `[ OK ]`, so a dropped junction reports
`'0/12'` under a green OK. It is documented in
[troubleshooting](troubleshooting.md#false-green-in-verify-setup) rather than
silently inherited.

---

## 3. Provenance is not proof

**What happened.** A driver filename appeared in a known-vulnerable-driver feed.
It was treated as evidence of vulnerability.

**Why that is wrong.** The feed's own data demonstrates the failure mode. One
entry in the cache self-identifies as `Product: "RansomwareTerminator"` while
carrying a legitimate-looking code-signing certificate and an
`OriginalFilename` that differs from the tagged filename. Another carries
`Company: "CrowdStrike, Inc."` with all normal-section entropies at `0.0` and a
high-entropy section named `.lI\`` — packed, and impersonating a specific
vendor.

A filename match is a starting point for a hash check. It is never the finding.

**The rule that came out of it** is the [falsifier
convention](knowledge-workspaces.md#the-falsifier-convention): a claim does not
enter the evidence store without *a source, a date, affected versions, a
confidence, and an observation that would disprove it*.

For CVE-2021-21551 that falsifier is operational and concrete: a signed newer
`dbutil` build with a security-descriptor-gated device would not match the known
hash. So finding the file on disk is not enough — check the signer and version
first. BYOVD means *legitimately signed but vulnerable*, so "it is signed" is
not a defence either.

---

## 4. Superseded claims stay visible

**What happened.** Documentation drift accumulated silently. A parameter
documented in a comment (`-ArchiveOnly`) did not exist in any script. A header
claimed a script "does NOT delete" cache versions while its body deleted them.

**The rule.**

> Strike a wrong claim in place. Write what refuted it and which instrument did.
> Never delete it.

A deleted wrong claim is a claim someone will re-derive next month. A struck
one is a trap that has already been sprung once and is now defused.

This applies to code comments too. `update-awgs.ps1` still documents a parameter
that does not exist, with a note that it does not. That note is more valuable
than a corrected comment would have been.

---

## 5. The evidence ladder

Use it when writing any finding.

| Rung | Means | Requires | Example |
| --- | --- | --- | --- |
| `measured` | Confirmed by this workspace's own instruments | Two independent instruments, named | Module+RVA stable across restarts |
| `verified` | Confirmed against a primary source at source level | Source, date, version | Disassembly shows the IOCTL dispatch |
| `reported` | A source claims it | Name the source | Vendor advisory states X is fixed in Y |
| `inferred` | Reasoned from other facts | Say what you reasoned from | "Probably two code paths because..." |
| `unverified` | Plausible, unchecked | — | — |
| `unknown` | Not established | — | — |

Two rules that the 50-game registry enforces with a validator:

> `unknown` is always better than a plausible guess. Invented versions and
> invented links are worse than a blank.

> Every link must carry a path or URL **plus what it claims**. A bare URL is an
> assertion, not a source.

Regional and version-dependent facts are tagged `[~]` and must be re-verified per
client build. Family-level facts stable for years are tagged `[F]`. A measured
fact is `[measured]`. Getting this wrong is how stale offsets survive.

---

## 6. Fail closed, loudly

Two failure modes to avoid:

**Silent partial success.** An installer that half-completes and reports success.
Every installer here is existence-gated: `Get-Tool` refuses an on-disk directory
unless the expected executable is genuinely inside it, and rejects any download
under 100 KB as a probable HTML error page. That rule exists because
`releases/latest/download/<asset>` returned a 404 page that was written to disk
as if it were a binary.

**Ambiguous pass.** A check that reports success while describing a failure
state. Where `verify-setup.ps1` still has this, it is documented in
[troubleshooting](troubleshooting.md#false-green-in-verify-setup) rather than
left for someone to discover.

---

## 7. Deny by default, explicitly

The permission matrix in `opencode.jsonc` grants `read` and
`external_directory` on each collection and **denies `edit`**. The deny is the
load-bearing half. Without it, an agent asked to "fix a typo in the skill
description" edits a third-party repository in place, and the next `git pull`
produces a conflict the operator has to diagnose blind.

Rule of thumb: **a deny you did not write down is a deny that will be
misunderstood.**

---

## 8. Summary of the rules

1. Label every claim `verified` / `reported` / `inferred`.
2. Name two or three alternative readings; state what would falsify yours.
3. Instruments get instrumented. Execute, don't resolve.
4. A check with no discriminating power is not a check.
5. Filename and membership are never proof. Hash and version provenance are.
6. No falsifier, no claim.
7. State offsets as module + RVA, against a named build.
8. Strike superseded claims; never delete them.
9. Dynamic kernel tests in a snapshot-able VM, always.
10. `unknown` beats a plausible guess.
