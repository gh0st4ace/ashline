# Worked example: from "the offset stopped working" to a written finding

A real shape of problem, using synthetic values. Every step is the method; the
numbers are not from any specific target.

This is what the repository is actually for. The tooling is ordinary. The
discipline is the product.

---

## The symptom

> "My health offset worked yesterday. Today the process reads the address fine
> but the value is nonsense."

Four readings are live at once, and they need different fixes:

| Reading | Implication |
| --- | --- |
| The client was updated | Re-derive everything against the new build |
| The pointer chain shifted (a new field) | Re-derive the chain, not the offset |
| It is a **different** process's module base | Wrong module, wrong everything |
| The value is genuinely at that offset and the game state changed | No bug |

They are distinguishable. Getting there is the work.

---

## Step 1 — check the client identity before anything else

**The cheapest falsifier, and it catches the most common cause.**

```powershell
py -3 scripts\doctor.py
```

The client-identity section reads the PE `TimeDateStamp` and `SizeOfImage` from
the executable and compares them to the expected values for the build you have
offsets for.

```
[BAD] client identity mismatch
      expected TimeDateStamp=0x6A72FC58  SizeOfImage=0x4406000
      actual   TimeDateStamp=0x6A81D3A0  SizeOfImage=0x4408000
      -> все смещения использовать нельзя
```

`TimeDateStamp` differs and `SizeOfImage` grew by 8 KB. **The client was
updated.** Every offset derived before today is now suspect, and no amount of
pointer-chain debugging will fix it.

This check exists because a stale offset and a genuine bug look identical from
the inside. The PE header settles it in under a second.

> Label: `measured`.

---

## Step 2 — do not carry the old offset forward

The tempting move is to nudge the offset until the value looks plausible. That
produces a finding that is wrong and unfalsifiable.

Re-derive against the current build, and record which build.

---

## Step 3 — re-derive, with two independent instruments

### Instrument A — static, from the writer

Find the function that writes the field, and read its disassembly. `apply_damage`
is the usual suspect because it is where health changes.

```powershell
rea decompile <binary> 0x1400013B0 --format json
```

In the decompile, the write is visible as a store to a member at a constant
displacement from a register that was itself loaded from a chain.

### Instrument B — dynamic, from the runtime

```powershell
# module-relative, never an absolute address
process_candidates          # confirm the base
scan_aob --writable-only   # find the candidate
```

The candidate lands at `module_base + 0x9004`.

### Cross-check

| Property | Instrument A (static) | Instrument B (dynamic) |
| --- | --- | --- |
| Field displacement | `+0x9004` | `+0x9004` |
| Type | `f32` (single-precision store) | value behaves as `f32` |
| Written by | `apply_damage` | value changes on damage, only there |

Two independent instruments agree. That is the bar.

> Label: `measured`. Falsifier: if the static decompile and the dynamic scan
> disagree on the displacement, one of them is wrong — and neither finding stands
> until you find out which.

---

## Step 4 — state it in the form that survives a restart

```
Bad:  health is at 0x7FF72F330000 + 0x9004

Good: health is f32 at module_base + 0x9004, verified against
      client build <TimeDateStamp=0x6A81D3A0>, static writer
      apply_damage @ RVA 0x1400013B0, dynamic scan via scan_aob
```

The good version records:

- **module + RVA** — survives ASLR, which the absolute address does not
- **type** — `f32`, not "a float"
- **the build** — `TimeDateStamp`, so a future reader knows whether to re-check
- **both instruments** — so a disagreement is detectable
- **the writer** — so the field has a meaning, not just an address

ASLR changes the base on every restart. An absolute address is wrong the moment
the process restarts, and it will look wrong in a way that invites more
debugging rather than less.

---

## Step 5 — write it down with a stale marker

Entry in the registry:

```json
{
  "n": 17,
  "title": "Example Title",
  "version_verified": "2026-10-17",
  "engine": { "v": "unknown", "conf": "[~]" },
  "client_arch": "native x64",
  "ac_confirmed": [],
  "components": { "um": null, "kernel": null, "server": null },
  "analysis_methods": "Memory research complete for health/ammo. Offsets module+RVA, verified by static decompile of the writer and a dynamic scan. Not a cheat; research only.",
  "host_risks": "Do not load any kernel component on the host. Dynamic driver work only in the VM.",
  "next_tasks": ["Re-verify offsets on next client update before use"],
  "last_verified": "2026-10-17"
}
```

`[~]` on the engine version is deliberate — regional and version-dependent facts
must be re-verified per client build. `unknown` is better than a guess.

And in the session notes:

```
Offset re-derived 2026-10-17 after a client update invalidated the
2026-10-15 set (TimeDateStamp 0x6A72FC58 -> 0x6A81D3A0). Superseded
claims struck, not deleted: the 15.10 offsets are kept above so nobody
re-derives them without seeing that they were invalidated.
```

---

## What made this fast

Not a clever tool. Four things:

1. **The identity check ran first.** It eliminated two of the four readings in
   one second, before any RE work started.
2. **The offset was never carried forward.** The plausible-value trap was
   available and was not taken.
3. **Two independent instruments.** Neither alone would have been enough, and a
   single instrument agreeing with itself is not confirmation.
4. **It was written as module + RVA against a named build.** So the next person
   — including you, after the next update — knows exactly when to re-check.

---

## The same shape, applied to a driver claim

| Step | Question | Instrument |
| --- | --- | --- |
| 1 | Is this file the known-vulnerable build? | `driver_triage.py --sig --json` |
| 2 | Is a filename-only match being mistaken for proof? | Read the `matched_by` label |
| 3 | Does the signer and version match the known-bad sample? | `--sig`, plus the feed entry |
| 4 | What would disprove the claim? | The falsifier on the evidence sheet |
| 5 | Would the remediation actually fix it? | Class-level check, not a size check |

A filename match is a starting point for a hash check. It is never the finding —
and `driver_triage.py` labels filename-only hits
`"filename-only (NOT proof — verify version/hashes)"` for exactly this reason.

> Never load a driver on the host to "confirm" it. Snapshot the VM first:
> `vmhelper.ps1 snap pre-test`.
