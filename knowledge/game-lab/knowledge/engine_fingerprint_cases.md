# Test 1 — engine detection on real installed games (PASSED)
15.10.2026 · tool: `D:\opencode\game-lab\scripts\engine_fingerprint.py` (passive: file tree + PE)

| Game | Verdict | Evidence found by the script |
| ---- | ------- | ----------------------------- |
| DayZ (H:\SteamLibrary...) | **custom-native** (Enfusion, inference-labelled) | no IL2CPP/Mono/UE markers; DayZ_x64.exe 17.8 MB, Bohemia Interactive; engine identity NOT asserted by the script (inference label) |
| Squad | **unreal** | 175 *.pak under Content\Paks; Engine\Binaries third-party; main exe SquadGame\Binaries\Win64 Licensed-SquadGame-Shipping.exe 230 MB, Offworld Industries |
| Backrooms Extractions | **unreal 5.5** | 1 pak under Content\Paks; Engine dir; PE version literal `++UE5+Release-5.5-CL-40574608` |
| PEAK | **unity_mono** | PEAK_Data/Managed/Assembly-CSharp.dll (1.4 MB); MonoBleedingEdge dir; ProductVersion `6000.0.62f1` |

Resulting research plans per stack (from `game-engine-detection` skill):
- Unity Mono → dnSpy on Managed
- IL2CPP → Il2CppDumper + GameAssembly + global-metadata (branch present but no local IL2CPP target found to
  confirm with — stay aware)
- UE → Dumper-7/UE4SS style SDK route (XY skill `unreal-engine-dumping`)
- custom native → CE/x64dbg + REA ghidra path (DayZ case here = exact reference target).

Limitation: no IL2CPP install found locally to verify that branch live; the IL2CPP branch logic is
code-present but verified only structurally. The negative/ambiguous cases (unknown dir) tested on
DayZ as "custom/or-unknown" — verdict text explicitly labels inference.
