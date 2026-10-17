# games_registry — 50-game research registry

Structure:
- `registry.json` — SOURCE OF TRUTH. All 50 games, all §7-schema fields, honest `unknown`/`unverified` defaults.
- `cards/01-…50-*.md` — rendered human-readable cards (do NOT edit; regenerate).
- `index.md` — rendered index (same rule).
- `_SCHEMA.md` — field spec + confidence-tag rules.

Rebuild / validate:
```powershell
py -3 D:\opencode\game-lab\scripts\game_registry.py --build      # render cards + index
py -3 D:\opencode\game-lab\scripts\game_registry.py --validate   # checks only (selfcheck wires this)
```

Update workflow (per master-prompt §8 pipeline):
1. Research one game (vendor page, AreWeAntiCheatYet dataset in the KB, live build if installed).
2. Edit that game's entry in `registry.json` (tags: [F]/[O]/[~]/[measured]/unverified/unknown).
3. `--build` → cards re-render; `--validate` must stay [OK].
4. Fill `official_links` and `version_verified` whenever a page/build is actually fetched/measured.

Current unknown-field top: official links (49/50), verified build versions (50/50),
[~] regional rows (CrossFire, Point Blank, BDO, Delta Force, Arena Breakout).
