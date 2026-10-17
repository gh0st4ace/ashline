# Anti-cheat stack map — 50 popular online titles (RESEARCH REFERENCE, 15.10.2026)

BOUNDARY: this sheet is a defense-relevant research map (what each protection is and
what surfaces it tests), plus LEGAL modding paths. NOT an evasion guide against the
listed live systems. Per the workspace rule (AGENTS.md), undetected-cheat development
against third-party live anti-cheat is out of scope for this lab.

Sources: rows below are (operator-supplied pairing, confirmed current by the operator on 15.10.2026
— treat [O] rows as authoritative, no further pairing re-verification) + AC product family traits
from public vendor pages for product families + the AreWeAntiCheatYet list (areweanticheatyet.com —
链接 present in the awesome-game-security KB README; the dataset itself is NOT mirrored locally,
measured by ksec-validator 2026-10-15 — a leftover claim that the summary lives in the KB was wrong).
Confidence: [F]=family-level fact from vendor docs/dataset; [O]=operator pairing;
[~]=regional/version-dependent — verify per client build before any RE research.

## Product families (traits apply to all rows below tagged with them)

- **EAC (Easy Anti-Cheat, Epic)** [F]: user-mode service + kernel driver; telemetry
  scans, integrity checks; per-vendor So blooming offloads. Legal path: first-class
  vendors expose `EasyAntiCheat_*.sys` mapping; modding mostly N/A on protected
  titles; single-player (EOS-hosted) removed-tier games work without AC service.
- **BattlEye** [F]: `BEService` + ` BEDaisy.sys` kernel driver + per-game client DLL;
  blockable via service start; legal path per-title — the game's own console/modding
  channels are outside protection only where vendor allows.
- **Vanguard (Riot)** [F]: boot-time kernel driver `vgk.sys` + `vgtray`; locked at
  boot; TLS/transport checks; HVCI compatibility strict. RE of `vgk.sys` internals is
  in the archive mirror (armvirus/VanguardTrace).
- **RICOCHET (Activision)** [F]: kernel driver + user-mode; mitigation on MIA machine;
  detection via periodic scans; legal path none (no mod channel).
- **ACE (Tencent Anti-Cheat Expert)** [F]: dual user/kernel, cross-region builds;
  telemetry endpoints differ per version; region-locked.
- **VAC/VAC Live (Valve)** [F]: user-mode only; VAC Live live-updates ban lists;
  legal path: official game mods/sourcemod NOT under VAC where allowed.
- **Warden (Blizzard)** [F]: inline/in-scan through game exe; completely apart from
  the kernel; legal path: no official mods except community-run private realms.
- **EA AntiCheat/Javelin (EA)** [F]: kernel-mode EAAC pack for EA-flagged titles.
- **Hyperion (Roblox)** [F]: heavy anti-tamper user-mode client, obfuscated/VM-protected
  bytecode; module not described publicly in open detail.
- **HoYoverse self-protection** [F]: embedded DRM + client-side integrity, no named AC.
- **nProtect GameGuard** [F]: `GameGuard.des` + kernel driver combo, old but active
  tradition in Asia-market titles.
- **NetEase self-protection** [F]: proprietary on-client detection (camp per-title).
- **Server-only** [F]: server-side validation & behavioral scoring do not protect the
  client process; the RE burden shifts to protocol/network scope.

## Per-title rows (№ game | AC | family | note)

1. Counter-Strike 2 | VAC, VAC Live | Valve [F] | official server plugins routes intensify cheating detection (CS2 has no separate kernel AC)
2. Valorant | Riot Vanguard | Riot [F] | boot-load policy; anything touching it on host = go to ac-test VM
3. Rainbow Six Siege | BattlEye | BattlEye [F]
4. Apex Legends | EAC | EAC [F]
5. Overwatch 2 | Defense Matrix + server [~] | Blizzard-ish client add-on + server-side; regional.
6. Call of Duty: Warzone | RICOCHET | Activision [F]
7. Call of Duty: Black Ops 7 | RICOCHET | Activision [F]
8. PUBG: Battlegrounds | BattlEye (+extra) | BattlEye [F] | additional layers are proprietary
9. THE FINALS | EAC | EAC [F]
10. Delta Force | ACE | Tencent [F]
11. Battlefield 2042 | EA AntiCheat | EA [F]
12. Battlefield 6 | EA Javelin AntiCheat | EA [F]
13. Team Fortress 2 | VAC | Valve [F]
14. CrossFire | regional client protection [~] | varies per publisher
15. Point Blank | regional client protection [~]
16. Fortnite | EAC + BattlEye | EAC+BattlEye [F] | both run simultaneously; still two streams
17. Rust | EAC | EAC [F]
18. DayZ | BattlEye | BattlEye [F] | main bench target in this workspace
19. Escape from Tarkov | BattlEye + own [~] | own layers are proprietary
20. ARC Raiders | EAC + extra [~]
21. Hunt: Showdown 1896 | EAC | EAC [F]
22. Arena Breakout: Infinite | ACE + extra [~]
23. ARK: Survival Ascended | BattlEye | BattlEye [F]
24. ARK: Survival Evolved | BattlEye | BattlEye [F] | servers can be sanctioned w/o BattlEye per-server flags — official-mod routes exist
25. Sea of Thieves | EAC | EAC [F]
26. SCUM | EAC | EAC [F]
27. 7 Days to Die | EAC | EAC [F] | official dedicated-server flags let EAC off; PVE route is legal config
28. Day of Dragons | per-build [~]
29. League of Legends | Riot Vanguard | Riot [F]
30. Dota 2 | VAC + server [~] | matchmaking-protected; Warden-style? actually VAC family
31. Smite 2 | EAC | EAC [F]
32. Heroes of the Storm | Warden + server | Blizzard [F]
33. Deadlock | Valve own ('Vacnet-extended') [~]
34. Destiny 2 | BattlEye | BattlEye [F]
35. Lost Ark | EAC | EAC [F]
36. New World: Aeternum | EAC | EAC [F]
37. Black Desert Online | regional [~] | XignCode-family historically; verify build
38. Guild Wars 2 | server-side behavioral | family [F]
39. World of Warcraft | Warden | Blizzard [F]
40. Final Fantasy XIV | server-side + separate in-client | SE proprietary [~]
41. Albion Online | server-side + client | albion proprietary [~]
42. Eve Online | server-side | CCP proprietary [~]
43. Rocket League | EAC (current) | EAC [F]
44. Dead by Daylight | EAC | EAC [F]
45. War Thunder | EAC | EAC [F]
46. GTA Online | BattlEye + server [~] | R* protection + BattlEye rollout; verif per build
47. Roblox | Hyperion + server | Roblox [F]
48. Genshin Impact | HoYoverse self | HoYo [F]
49. Marvel Rivals | NetEase self | NetEase [F]
50. Helldivers 2 | nProtect GameGuard | nProtect [F]

## What to do with a row (workflow, per the operator's legitimate scope)

- own/offline or sanctioned mods → `game-modding-lab` ladder.
- RE the protection to build/counters for a OWN-simulation → `anti-cheat-architecture`
  (VM `ac-test`, `snap` before, `rollback` after; never the host).
- AC product internals research for education/defense → awesome-game-security KB +
  kernel-sec sheets (product-specific summaries in `description/<owner>/<repo>/`).
- Operational undetected-cheat delivery for these live titles → NOT THIS LAB
  (policy boundary; reinforces the operator's existing mission §5).

## Verification cadence

[~] rows must be re-verified per TITLE BUILD before any research session; BSG/Nexon/Tencent
roll their own wrappers silently. Family traits [F] hold for years.
