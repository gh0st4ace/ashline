# 46. GTA Online — research card

last_verified: 2026-10-15 · category: other-online

| field | value |
| ----- | ----- |
| publisher / developer | Rockstar Games / Rockstar North |
| platforms | Windows, consoles |
| region | global; PC BattlEye rollout |
| version/build verified | unverified |
| engine | RAGE [F] |
| client architecture | native x64 |
| anti-cheat (confirmed) | BattlEye [~], [O] |
| anti-cheat (other) | Rockstar server-side [F] |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: protection vendor: https://www.battleye.com/ (fetched 2026-10-15; self-describes 'Fully proactive kernel-based protection system') [F]
- SDK/source: FiveM/RAGE MP — third-party multiplayer clients (legal status varies; Rockstar policy 2024+) [unverified]

## Public research
- none collected

## Methods, tool limits, safe modding, host risks
- analysis methods: native RE; VM-only driver steps
- tool limits: BattlEye family traits [F]
- safe modding: single-player mods (outside GTA Online); FiveM ecosystems per current policy
- host risks: kernel driver present on host during play

## Next research tasks
- verify BattlEye rollout completeness on current build

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._