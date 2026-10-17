# 1. Counter-Strike 2 — research card

last_verified: 2026-10-15 · category: shooter-fps

| field | value |
| ----- | ----- |
| publisher / developer | Valve / Valve |
| platforms | Windows, SteamOS/Linux (Steam page lists no macOS build) [F] |
| region | global |
| version/build verified | unverified |
| engine | Source 2 [F] |
| client architecture | native x64 |
| anti-cheat (confirmed) | VAC [F], VAC Live [F] |
| anti-cheat (other) | server-side moderation/OVERWATCH human review [unverified] |
| components | user-mode: confirmed · kernel: no · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: https://store.steampowered.com/app/730/CounterStrike_2/ (fetched 2026-10-15) [F]
- SDK/source: Source 2 workshop tools [F]
- SDK/source: sourcemod/Metamod community ecosystem for CS:GO-era [unverified]

## Public research
- Steam page (fetched 2026-10-15): 'Built on the Source 2 engine' [F]; 'Uses Anti-Cheat Software: VAC (Valve Anti-Cheat)' [F]; VAC Live not advertised on the store page [~]

## Methods, tool limits, safe modding, host risks
- analysis methods: native RE (Ghidra/IDA/REA), ReClass; server-plugin route for behavior study
- tool limits: VAC is user-mode only; VAC Live ban lists update live [F]
- safe modding: official server plugins; custom game modes on own servers
- host risks: standard client RE only; no kernel AC

## Next research tasks
- verify VAC Live status vs VAC legacy per current build
- fill official links

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._