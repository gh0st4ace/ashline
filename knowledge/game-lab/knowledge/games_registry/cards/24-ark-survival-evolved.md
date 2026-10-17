# 24. ARK: Survival Evolved — research card

last_verified: 2026-10-15 · category: battle-royale-survival-extraction

| field | value |
| ----- | ----- |
| publisher / developer | Studio Wildcard / Studio Wildcard/Instinct Games |
| platforms | Windows, consoles, Linux servers |
| region | global; per-server BattlEye flags |
| version/build verified | unverified |
| engine | Unreal Engine 4 [F] |
| client architecture | native x64 |
| anti-cheat (confirmed) | BattlEye [F], [O] |
| anti-cheat (other) | none known |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: protection vendor: https://www.battleye.com/ (fetched 2026-10-15; self-describes 'Fully proactive kernel-based protection system') [F]
- SDK/source: ARK Dev Kit (official) [F]
- SDK/source: server modding (official mod support) [F]

## Public research
- none collected

## Methods, tool limits, safe modding, host risks
- analysis methods: UE4 RE; Dev Kit route
- tool limits: BattlEye can be disabled per-server flag on unofficial servers [F]
- safe modding: Dev Kit mods on own servers; per-server EAC-off flags
- host risks: kernel driver present on host during play

## Next research tasks
- fill official links

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._