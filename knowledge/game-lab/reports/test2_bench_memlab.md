# Test 2 — memory variable research on the lab bench (PASSED)
15.10.2026 · target: `D:\opencode\game-lab\bench\bench_native.exe` (own build, MSVC 14.51 x64)

## Instrument used for the AUTHORITATIVE pass: cheat-mcp
`tools["cheat-mcp"].process_candidates("bench_native")` → pid; `process_open`; `scan_aob`
writable_only → exactly **1 hit** at `+0x9004` (pattern `19 00 00 00 'bench_warrior',??`); then
typed reads at `g`:
| field | offset | printed by source | observed in memory |
| ----- | ------ | ----------------- | ------------------ |
| health f32 | 0x00 | 100.0 | `hex 00 00 C8 42` → 100.0 ✓ |
| ammo i32 | 0x04 | 25 | 25 ✓ |
| name cstr | 0x08 | "bench_warrior" | ✓ |
| xp i32 | 0x20 | 0 | 0 ✓ |
| calls i32 | 0x24 | 0 (hold) | 0 ✓ (and =6 mid-flight in the earlier live scan at calls tick 6, hex `06`) |
| score f64 | 0x28 | 999.5 | `hex 00 00 00 00 00 3C 8F 40` → 999.5 ✓ |

## Restart stability (PASSED)
- run at base `0x7FF72F330000`: g at module+0x9000
- run at base `0x7FF636D39000`: g at module+0x9000
- `.map` (cl /Fm) says g RVA = 0x9000 (Rva+Base column 140009000 minus load addr 140000000)
- absolute address changed across spawns/boots, `module+RVA` stayed constant — this is the
  teaching point: document `module+RVA`, never an absolute VA.

## Writer correlation (static ↔ runtime)
- `apply_damage` at `.map` RVA+base `0x1400013B0` decompiled by REA (ghidra provider):
  `*param_1 = *param_1 - param_2; if (*param_1 <= 0.0)` — source-equivalent
  (`tests\decompile_apply_damage.json`, sha256 of image recorded by REA).
- live behavior: each tick health −7 (prints 93/86/79/72/…) consistent with the call
  counter incrementing 1 per tick (mid-flight scan saw calls=6, xp=60 = 10×6 — the
  xp/calls invariant held).

## Known limitations (honest)
- The pure-python ReadProcessMemory path in this Python host returns data only for the
  FIRST read per opened handle and then fails with ERROR_PARTIAL_COPY/0 in several
  orderings that were re-tested 5+ ways (root cause unresolved, not reproduced in
  standalone scripts). cheat-mcp (its own C-based reader) reads reliably — production
  flows should use cheat-mcp; `scripts\bench_memprobe.py` remains as the teaching
  fallback with its ordering workaround (fresh handle per read).
- `scan_aob` returned exactly the struct instance in ~4.3 MB working set; on real games
  the same pattern discipline applies but expect multiple hits; narrow by writer analysis.

Deliverable files: `scripts\bench_memprobe.py`, `bench\bench_native.c`,
`bench\build_bench.bat`, `tests\bench_run*.txt`, `tests\decompile_apply_damage.json`.
