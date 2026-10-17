# 3. Rainbow Six Siege — research card

last_verified: 2026-10-15 · category: shooter-fps

| field | value |
| ----- | ----- |
| publisher / developer | Ubisoft / Ubisoft Montreal |
| platforms | Windows, consoles |
| region | global |
| version/build verified | unverified |
| engine | proprietary (Ubisoft internal) [~] |
| client architecture | native x64 |
| anti-cheat (confirmed) | BattlEye [F] |
| anti-cheat (other) | server-side [unverified] |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: protection vendor: https://www.battleye.com/ (fetched 2026-10-15; self-describes 'Fully proactive kernel-based protection system') [F]

## Public research
- none collected

## Methods, tool limits, safe modding, host risks
- analysis methods: native RE, ReClass, cheat-mcp on own benches only
- tool limits: BEService + BEDaisy.sys + per-game client DLL [F]
- safe modding: none known
- host risks: kernel driver present on host during play

## Next research tasks
- confirm engine name from current build

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._