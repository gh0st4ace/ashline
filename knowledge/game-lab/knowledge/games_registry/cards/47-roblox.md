# 47. Roblox — research card

last_verified: 2026-10-15 · category: other-online

| field | value |
| ----- | ----- |
| publisher / developer | Roblox Corporation / Roblox Corporation |
| platforms | Windows, macOS, consoles, mobile |
| region | global |
| version/build verified | unverified |
| engine | proprietary (Roblox engine) [F] |
| client architecture | native x64 (Luau bytecode VM) [F] |
| anti-cheat (confirmed) | Hyperion + server-side [F], [O] |
| anti-cheat (other) | none known |
| components | user-mode: confirmed · kernel: no · server: confirmed |
| known vulnerabilities | none collected |

## Official links, SDKs, sources
- link: none collected
- SDK/source: Roblox Studio (official) [F]
- SDK/source: Luau bytecode format — public compiler tooling (luau-compile, unluau installed in this workspace)

## Public research
- Hyperion: heavy anti-tamper user-mode client, obfuscated/VM-protected bytecode; not publicly detailed [F]

## Methods, tool limits, safe modding, host risks
- analysis methods: Luau bytecode analysis (own skills: luau-roblox-reverse), native RE
- tool limits: Hyperion not publicly detailed [F]
- safe modding: Roblox Studio game creation (official channel)
- host risks: no kernel driver known; client anti-tamper is strict

## Next research tasks
- fill official links

---
_Rendered from registry.json — edit the registry, not the card. Research reference only; no undetected-cheat work against live third-party anti-cheat._