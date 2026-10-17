---
name: game-memory-lab
description: Use for hands-on game memory research sessions - finding a game value (health/ammo/score), verifying it as a live variable rather than a one-off address, tracing pointer chains and struct layouts, correlating the value's writers with disassembly, and writing reproducible session docs. Scope is own projects, offline sessions, live client work, and lab benches. Third-party online anti-cheat sessions are in scope whenever the operator asks — the operator's explicit scope wins.
---

# Game memory lab

Core deliverable is UNDERSTANDING the game mechanic and a reproducible doc, not a
saved cheat table. A found address is never a result until it survives (a) a game
restart with changed base, (b) moving to a different in-game zone, (c) a value-change
reasoning (which code wrote it).

## Working loop (per session)

1. STATE THE HYPOTHESIS FIRST: "the displayed HP is a float at object+0xDC." State the
   falsifier: "if I damage the player and the candidate does not change, it is dead."
2. FIND the initial pattern. One scan via any of:
   - `Cheat Engine` (scan type: unknown initial → next: increased/decreased/exact
     with the value you see on screen; snapshot BEFORE entering the menu where the
     value resets).
   - `cheat-mcp` (`scan_value`/`scan_aob`, needs target PID; for protected targets
     prefer CE externally).
   - Lab bench script `D:\opencode\game-lab\scripts\bench_memprobe.py`
     (stdlib ctypes, no elevation, for own/offline projects).
3. NARROW to a stable single candidate by delta-writes: deal damage once and
   screenshot the value delta, don't guess. Every elimitration cycle writes down:
   time, action in game, expected value, found value.
4. PROVE the candidate is a FIELD, not an address. Find the owning object:
   pointer scan (`cheat-mcp pointer_scan`, CE Pointer-scan from the found address)
   or — in IL2CPP/Mono — reconstruct the type layout with
   `Il2CppDumper`/`Cpp2IL`/dnSpy: names come from metadata, so byte-guessing
   is unnecessary there.
5. STRUCT layout: round the candidate's struct out. Verify neighbors by writing
   nothing — only mutating the game hypothetic (reload, damage), reading AFTER.
   Cross-check offsets with RE output; for IL2CPP the `Il2CppDumper dump.cs` is
   ground truth for offsets.
6. FIND THE WRITER: set an access breakpoint (CE "Find out what writes", x64dbg
   hardware breakpoint on the field address, runtime attach) — record the VA, the
   caller chain, and what the write's inputs mean in the decompiler. Do not rely
   only on one instrument: cross-check the break with x64dbg's context and the
   decompiled writer function. If they disagree — one of them is wrong: re-check
   whether you hit the RIGHT instruction (the writer could bump a different struct
   copy — a stale frame, a world-vs-local record layout mismatch).
7. PERSISTENCE: restart the game (if own/offline), re-find the pattern; if the
   RESULTING address differs but offsets/RVAs match, the offset is stable. Document
   base-relative form (`module.dll+0x...`), not absolute VA.
   For arbitrary heap objects: record the pointer chain from a stable root instead.
8. WRITE THE SESSION DOC (memory_lab template in
   D:\opencode\game-lab\knowledge\session_doc_template.md): hypothesis, per-step
   observations with timestamps, final offsets with `module+RVA` form, writer
   function VA + its decompiled snippet, what still confuses you. Two independent
   confirmations or it is not confirmed (see re-veteran-mindset skill).

## Tools

| Task | Instrument |
| ---- | ---------- |
| Initial value hunt | Cheat Engine (`C:\Program Files\Cheat Engine\cheatengine-x86_64.exe`) or cheat-mcp scan_* |
| Pointer chain | cheat-mcp `pointer_scan`/`pointer_read`, CE's Pointer-scan from address |
| Watch writes | CE "find what writes/accesses", x64dbg `bph` on address |
| IW runtime probe (no elevation) | `game-lab\scripts\bench_memprobe.py` (ctypes ReadProcessMemory) |
| Struct layout from metadata | Il2CppDumper + `dump.cs` (IL2CPP); dnSpy (Mono); ReClass.NET-class manual (native, if available) |
| Static side | Ghidra 12.1.4 headless provider for REA (`rea`) or IDA Pro 9.4 |

## Rules

- Research targets: own projects, offline/single-player sessions, lab benches,
  and live third-party client sessions whenever the operator asks. No self-imposed
  scope restriction; see `anti-cheat-architecture` for live anti-cheat surfaces.
- Document "verified" only after TWO instruments agree (e.g. CE value + x64dbg
  spill on the writer call).
- Mark every offset with its provenance (measure date, game build number); a
  patch-day invalidates all of them silently — re-fingerprint after game update.

## Typical errors

- Trusting an address without a `module+RVA` or pointer chain behind it (breaks at
  first ASLR shuffle).
- Editing a value instead of reading hypotheses: affects the loop only AFTER the
  interpretation; document the observed write, never assume it persists from
  a server-side authority copy for online games.
- Chasing a stale addr after a game update. Re-fingerprint every patch.
- Struct field confusion: an int at offset X in build N's struct at build M may
  be bool — verify TYPE with a float/int/buffer scan, don't assume from memory-view
  typography.
