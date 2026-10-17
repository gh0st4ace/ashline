# 19. Escape from Tarkov — research card

last_verified: 2026-10-15 · category: battle-royale-survival-extraction

| field | value |
| ----- | ----- |
| publisher / developer | Battlestate Games / Battlestate Games |
| platforms | Windows |
| region | global |
| version/build verified | unverified |
| engine | Unity [F] |
| client architecture | Unity managed (Mono per common knowledge) [~] |
| anti-cheat (confirmed) | BattlEye [F], [O] |
| anti-cheat (other) | own proprietary layers [~] |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: protection vendor: https://www.battleye.com/ (fetched 2026-10-15; self-describes 'Fully proactive kernel-based protection system') [F]

## Public research
- none collected

## Methods, tool limits, safe modding, host risks
- analysis methods: Mono/IL2CPP dumpers (installed); native RE
- tool limits: BSG rolls its own wrappers silently [~] — re-verify per build
- safe modding: none; SPT (single-player mod) exists as community route [unverified]
- host risks: kernel driver present on host during play

## Next research tasks
- re-verify own-layer composition per build

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._