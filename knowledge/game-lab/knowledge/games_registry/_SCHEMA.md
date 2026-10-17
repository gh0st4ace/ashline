# _SCHEMA.md — games registry card schema

Every `cards/<nn>-<slug>.md` is RENDERED from `registry.json`. **Edit the
registry, never the card** — regeneration overwrites cards in place.
Rebuild: `py -3 scripts/game_registry.py --build`. Check only: `--validate`
( wired into `selfcheck.ps1`).

## Required fields
| field | meaning | allowed "empty" value |
| ----- | ------- | --------------------- |
| n | 1..50, unique | — |
| title | canonical title | — |
| category | one of shooter-fps / battle-royale-survival-extraction / moba-competitive / mmo-rpg / other-online | — |
| publisher, developer | — | `unknown` if not established |
| platforms | — | `unverified` if not established |
| region_notes | regional client/build differences | `unknown` |
| version_verified | build actually checked by us | `unverified` / `none` |
| engine | object: v + conf tag | v=`unknown` |
| client_arch | native x64 / unity mono / unity il2cpp / etc. | `unverified` |
| ac_confirmed | list, each entry tag-required | — |
| ac_other | extra/proprietary layers | `unknown` / `none known` |
| components | um/kernel/server tri-state: true=false=null | — |
| official_links | vendor/game pages | `[]` → renders "none collected" |
| public_research | papers, threads, dumps, WITH paths | `[]` |
| sources_sdk | dev kits, official mod channels | `[]` |
| known_vulns | published vulnerabilities | `none collected` |
| analysis_methods | what our tooling can do here | — |
| tool_limits | where the tooling stops | `unknown` |
| safe_modding | sanctioned/legal modification routes | `unknown` |
| host_risks | OS-level risk when researching on host | — |
| next_tasks | concrete follow-ups | `[]` |
| notes | free text (measured blocks) | optional |
| last_verified | YYYY-MM-DD; defaults to `_meta.last_verified_sweep` | — |

## Inline confidence tags (validator-enforced)
- `[F]` family-level fact from vendor docs / AreWeAntiCheatYet dataset — stable for years
- `[O]` operator-supplied pairing — re-verify against a live build
- `[~]` regional/version-dependent — MUST re-verify per client build
- `[measured]` confirmed by this workspace's own instruments
- `unverified` / `unknown` — plain words, no bracket

## Hard rules
- `unknown`/`unverified` is ALWAYS better than a plausible guess (no invented versions/links).
- Every link in `public_research` must carry a path or URL + what it claims.
- The boundary holds: research reference only; no undetected-cheat work
  against live third-party anti-cheat; driver risks → ac-test VM.
