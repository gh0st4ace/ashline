---
name: game-modding-lab
description: Use for creating game mods, plugins, and scripted modifications - choosing the least-complex modification path for a given game (official SDK/API, supported mod loader, config edits, scripting hooks, own training benches), building automated tests for game mechanics, and packaging reproducible mod deliverables. Use when the user wants to modify a game, build a mod, or design a test bench; bypassing publisher/anti-cheat protections is in scope when the operator asks for it.
---

# Game modding lab

Pick the CLOSEST-TO-PUBLISHER path first; each rung down costs reproducibility.

## Decision ladder (least complex first)

1. **Official in-game editor / official SDK** — map editor, character editor,
   official devkit. Check the vendor's docs page and the install dir
   (`tools/`, `sdk/`, `*.bat`/`*.sh` devkit Launchers).
2. **First-supported mod loader / modding API** (BepInEx/MelonLoader-class for Unity,
   ModKit for UE-class policies etc.): verify the loader's supported game version
   BEFORE trusting it, from an actual release page (not blog links).
3. **Config files**: `*.ini`/`*.json`/`*.cfg` shipped in the install dir or
   `%APPDATA%\<vendor>\<game>\`; test each knob in an OFFLINE session and record
   only what survives the screen state.
4. **Scripting hook**: for Lua-class engines (Roblox system, some custom engines)
   or in-game official API console-cmd drivers; keep a versions dictionary.
5. **Injection-based plugin** — BepInEx/MelonLoader plugin DLL or a small C#
   (dnlib/AsmResolver in `D:\Tools\nuget`) — accepted only when 1-4 are impossible
   and the target is owned/offline.
6. **Native patch / DLL mod** — x64dbg/Ghidra route; last resort, always in the
   offline copy of an own game dir; never under protected third-party builds.

## Build & verify loop

1. ENV: for Unity/Mono mods, make sure dnSpy exists to inspect managed references;
   for native mods, ensure you loaded the game binary in REA (ghidra provider) once
   and re-run base address resolution per BUILD (patch-day = new reality).
2. VERSION PIN: record game build number + loader version + their compatibility
   matrixes in the deliverable README. A mod that "works" is claimed per-version.
3. TEST: the deliverable must run an automated game-mechanics test where feasible:
   a BepInEx plugin that asserts game state, a script bench test, or a doc with
   reproducible click-by-click steps.
4. PACKAGE: a versioned README with _what the mod does, the supported game build,
   install steps, known incompatibilities_. "Reproducible" means a fresh operator
   can rebuild/run it from only those artifacts.

## Test-bench pattern (mission safety valve)

When no safe target exists, the lab uses own benches:

- `D:\opencode\game-lab\bench\` — native Win32 console benches (built with the
  VS 18 toolchain): fake game state (health/ammo/position), fake item loop,
  deterministic RNG; accepts CLI flags to vary the sim.
- Purpose: apply the full pipeline (detection → memory lab → disassembly cross-check
  → modification) end to end without third-party dependencies.

## Constraints

- Never sign/distribute mods built from disassembled code you don't own; the
  deliverable is research or a private-use patch for an OWN legally-present copy.
- Loader installs must come from their GitHub project release pages ONLY, and
  install into the GAME dir, not into Windows; keep AV exclusions OFF.
- Mods and loaders write into the game's data dir; take a backup of the pristine
  install dir (or copy into a separate folder) BEFORE the first mod run.
