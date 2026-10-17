# 18. DayZ — research card

last_verified: 2026-10-15 · category: battle-royale-survival-extraction

| field | value |
| ----- | ----- |
| publisher / developer | Bohemia Interactive / Bohemia Interactive |
| platforms | Windows, consoles |
| region | global; community servers |
| version/build verified | unverified build; 1.29 offsets reference exists |
| engine | Enfusion (custom native) [measured] |
| client architecture | native x64 [measured] |
| anti-cheat (confirmed) | BattlEye [F], [O] |
| anti-cheat (other) | server-side validation [unverified] |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: https://store.steampowered.com/app/221100/DayZ/ (fetched 2026-10-15) [F]
- SDK/source: Enfusion/DayZ server modding (official) [F]
- SDK/source: own client-side research overlays in OBSIDIAN project

## Public research
- DayZ Bible UC thread 774987 (v1.29) -> local research note DAYZ_OFFSETS_1.29_REFERENCE.md (private project, not redistributed)
- DayZ-Dumper offset table — REFUTED as constant source on our client (see kernel-sec/game-lab CONSTRAINTS), where-to-look only
- own measured: World 0x4262FE8, NetworkManager 0x100EBD0 (object, not pointer), camera basis path in world_to_screen PROVEN live
- Steam page (fetched 2026-10-15): 'Uses Kernel Level Anti-Cheat: BattlEye — requires manual removal after game uninstall' and copyright 'includes BattlEye(TM) anti-cheat technology' [F] — SECOND independent confirmation of kernel component

## Methods, tool limits, safe modding, host risks
- analysis methods: native RE + live memory research (measured extensively in OBSIDIAN project); camera layout confirmed two ways (pattern + disassembly)
- tool limits: dumper table uncorroborated — measured offsets only; ArmaString layout (+0x08 len, +0x10 text)
- safe modding: official server modding; client-side overlay research is operator's own project (OBSIDIAN)
- host risks: BattlEye on host during play; overlay project runs on host by design

## Measured notes (this workspace)
 dayz.com returned HTTP 403 to non-browser fetch (2026-10-15); CDN-blocked, not evidence of absence; verify in a browser when filling the game's own link.

## Next research tasks
- code the proven basis-based world_to_screen into OBSIDIAN world.cpp (HANDOFF ДОПОЛНЕНИЕ 44)
- projection coefficients (0.7813/1.3890 vs 1/x relationship) still to resolve in code

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._