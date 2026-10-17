# 17. Rust — research card

last_verified: 2026-10-15 · category: battle-royale-survival-extraction

| field | value |
| ----- | ----- |
| publisher / developer | Facepunch Studios / Facepunch Studios |
| platforms | Windows, macOS, Linux (Linux client unverified) |
| region | global; community servers |
| version/build verified | unverified |
| engine | Unity [F] |
| client architecture | Unity managed (Mono/IL2CPP per build) [~] |
| anti-cheat (confirmed) | EAC [F], [O] |
| anti-cheat (other) | server-side admin (Oxide/uMod ecosystem on community servers) [F] |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: https://playrust.com/ (fetched 2026-10-15) [F]
- SDK/source: server-side modding frameworks for community servers [F]

## Public research
- none collected

## Methods, tool limits, safe modding, host risks
- analysis methods: IL2CPP/Mono dumpers (installed), native RE
- tool limits: EAC family traits [F]
- safe modding: community server plugin ecosystem [F]
- host risks: kernel driver present on host during play

## Next research tasks
- confirm Mono vs IL2CPP on current build

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._