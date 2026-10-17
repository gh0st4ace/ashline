---
name: game-engine-detection
description: Use to determine which engine/stack a game uses (Unity Mono, Unity IL2CPP, Unreal Engine, custom native, managed .NET, browser/web-tech) from verifiable file-tree and PE evidence before choosing analysis tools. Use when starting work on a new local game, choosing between dnSpy/Il2CppDumper/Cpp2IL/ReClass/UH-style tools, or when the user asks "what engine is this game built with". Not for analyzing a known engine's internals.
---

# Game engine detection

Decision procedure, evidence-first. Never conclude from the game's name, store page,
or genre. Run the fingerprinter first, then hand-check its evidence.

## Tool

```
py -3 D:\opencode\game-lab\scripts\engine_fingerprint.py "<game install dir>"
```

Output: verdict + per-engine evidence lines (each says WHICH file matched and WHY) +
confidence. The script is passive: file/dir names, PE headers, version resources,
import tables. It never launches anything.

## Algorithm

1. RUN the fingerprinter on the install dir it owns, not on a shortcut's target guess:
   resolve the live `*.exe` candidates with `Get-ChildItem -Filter *.exe` and if more
   than one, prefer the largest non-launcher binary (skip `UnityCrashHandler*`,
   `vc_redist*`, `*_crashpad*`, `QtWebEngine*`, `SimpleLauncher*`).
2. INTERPRET by engine families the script looks for:
   - **Unity IL2CPP**: `GameAssembly.dll` + `il2cpp_data\` (`global-metadata.dat`
     inside `Metadata\`), then IL2CPP pipeline applies.
   - **Unity Mono**: `*.exe` managed + `Mono\` or `mono2x\` dir + `Data\Managed\*.dll`
     C# assemblies; dnSpy applies directly.
   - **Unreal Engine 4/5**: `*.exe` binary plus `*.pak` files under `Content\Paks\`,
     `Engine\` dir, `*.uexp`, `*.umap`, `*.ushaderbundle`; UE-version strings in the
     exe (`+release-...-versioned-...` literal, or `UE4CommandLine.txt`).
   - **Custom native**: game exe with engine-specific imports (e.g. `dbgv133i`-class
     DayZ/Enfusion files `dbgv133i*`, use `*Enfusion*`), no managed runtime, no UE
     markers; the plan then goes through x64dbg/Ghidra/ReClass-class RE shells.
   - **Managed .NET non-Unity**: `*.exe.config`, `.deps.json`, single-file host —
     dnSpy/dnlib path.
   - **Webtech**: `*.pak` Chromium layout, `resources.pak`, `*.asar` — Electron path.
3. THE EXE MATTERS, THE DIR DOES NOT: a Steam game may sit under a fat `steamapps`,
   always pass the dir that CONTAINS the running exe (tasklist/Get-Process Name for
   verification while the game is offline check `tasklist /FI "IMAGENAME eq X.exe"`).
4. When verifier hits run out (mixed markers), record ambiguity explicitly and
   probe the strongest split: managed or not (ANSI import of `mscoree.dll` (C#),
   `GameAssembly` presence) — dnSpy opens the wrong tier of evidence otherwise.

## Verification rules

- Every verdict line the fingerprinter prints must name an actual existing file.
  Do not accept `Likely` on directory names alone when a marker file can be checked.
- Cross-check the version claim: the exe version resource (CompanyName/FileDescription)
  is evidence about the PUBLISHER, not the engine; engine evidence is only file-extensions,
  folder layout, PE imports, and embedded literals.
- Two engines' evidence can coexist (UE + Chromium overlay). Report the MAIN one,
  name the auxiliary one.

## Common errors

- Passing the launcher dir instead of the game data dir (biggest false "custom").
- `GameAssembly.dll` proves IL2CPP, but paks match Unreal — actually the game re-uses
  a UE map pak archive name in a non-UE build. Check `*.uexp` before claiming UE.
- Concluding "native" from ONE missing marker when Unity Mono's `Data\Managed`
  can be renamed by the vendor — fall back on imports + icon/company/version resources
  before declaring "custom/native".
