# 2. Valorant — research card

last_verified: 2026-10-15 · category: shooter-fps

| field | value |
| ----- | ----- |
| publisher / developer | Riot Games / Riot Games |
| platforms | Windows |
| region | global |
| version/build verified | unverified |
| engine | Unreal Engine (customized) [F] |
| client architecture | native x64 |
| anti-cheat (confirmed) | Riot Vanguard [F] |
| anti-cheat (other) | none known |
| components | user-mode: confirmed · kernel: confirmed · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: https://playvalorant.com/ (fetched 2026-10-15; serves locale variants) [F]

## Public research
- armvirus/VanguardTrace — vgk.sys encrypted import table (in archive mirror)

## Methods, tool limits, safe modding, host risks
- analysis methods: kernel driver RE (Ghidra/IDA/REA), WinDbg on dumps; VM-only for operational steps
- tool limits: vgk.sys loads at boot; HVCI compatibility strict [F]
- safe modding: none; no mod channel
- host risks: HIGH: boot-time kernel driver on host; any driver-level test goes to ac-test VM with snapshot

## Next research tasks
- verify current vgk build vs public research dates

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._