# 8. PUBG: Battlegrounds — research card

last_verified: 2026-10-15 · category: shooter-fps

| field | value |
| ----- | ----- |
| publisher / developer | Krafton / PUBG Studios |
| platforms | Windows, consoles, mobile (separate build) |
| region | global; mobile build differs |
| version/build verified | unverified |
| engine | Unreal Engine 4 [F] |
| client architecture | native x64 |
| anti-cheat (confirmed) | BattlEye [F], [O] |
| anti-cheat (other) | additional proprietary layers [~] |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: protection vendor: https://www.battleye.com/ (fetched 2026-10-15; self-describes 'Fully proactive kernel-based protection system') [F]

## Public research
- none collected

## Methods, tool limits, safe modding, host risks
- analysis methods: native UE RE (ReClass, Rea), VM-only driver steps
- tool limits: BattlEye family traits [F]
- safe modding: none known
- host risks: kernel driver present on host during play

## Next research tasks
- identify the extra proprietary layers

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._