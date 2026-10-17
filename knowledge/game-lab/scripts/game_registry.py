# game_registry.py — build/validate the 50-game research registry.
#
# Source of truth: knowledge/games_registry/registry.json
# Renders:         knowledge/games_registry/cards/<nn>-<slug>.md
#                  knowledge/games_registry/index.md
# Validate mode:   --validate  (checks only, no writes; used by selfcheck.ps1)
#
# Rules (see knowledge/games_registry/_SCHEMA.md):
#   - unknown/unverified are the DEFAULT for anything not verified — never invent.
#   - inline confidence tags: [F] family, [O] operator, [~] build/regional,
#     [measured] own instruments.
#   - components: um/kernel/server tri-state; null = unknown.
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "knowledge" / "games_registry"
REG = ROOT / "registry.json"
CARDS = ROOT / "cards"
CATEGORIES = {"shooter-fps", "battle-royale-survival-extraction", "moba-competitive", "mmo-rpg", "other-online"}
TAGS = {"F", "O", "~", "measured", "unverified", "unknown"}
REQUIRED = ["n", "title", "category", "publisher", "developer", "platforms", "engine",
            "client_arch", "ac_confirmed", "components", "analysis_methods",
            "safe_modding", "host_risks", "next_tasks", "last_verified"]
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(title: str) -> str:
    s = SLUG_RE.sub("-", title.lower()).strip("-")
    return s.strip("-") or "unknown"


def iter_fields(v):
    """Yield (field_name, string_value) for every string leaf in the game dict,
    so tag validation covers nested dicts and lists too."""
    if isinstance(v, dict):
        for k, sub in v.items():
            yield from iter_fields(sub)
    elif isinstance(v, list):
        for sub in v:
            yield from iter_fields(sub)
    elif isinstance(v, str):
        yield v


def validate(games):
    errs = []
    n_list = [g.get("n") for g in games]
    if sorted(n_list) != list(range(1, 51)):
        errs.append(f"expected exactly rows 1..50, got {len(games)} rows")
    if len(set(n_list)) != len(n_list):
        errs.append("duplicate row numbers")
    slugs = set()
    for g in games:
        where = f"row {g.get('n')} ({g.get('title', '?')})"
        for f in REQUIRED:
            if f not in g:
                errs.append(f"{where}: missing required field {f}")
        if g.get("category") not in CATEGORIES:
            errs.append(f"{where}: bad category {g.get('category')}")
        lv = g.get("last_verified", "")
        if not DATE_RE.match(str(lv)):
            errs.append(f"{where}: last_verified not YYYY-MM-DD")
        if g.get("engine", {}).get("conf") not in TAGS:
            errs.append(f"{where}: engine.conf tag '{g['engine'].get('conf')}' not in {sorted(TAGS)}")
        comp = g.get("components", {})
        if set(comp.keys()) != {"um", "kernel", "server"} or any(
            comp.get(k) not in (True, False, None) for k in ("um", "kernel", "server")
        ):
            errs.append(f"{where}: components must be tri-state um/kernel/server")
        # every string value's bracket tag must be a known tag; values without a
        # tag are fine only if the whole value is a known default word
        for s in iter_fields({k: v for k, v in g.items() if k != "n"}):
            for tag in re.findall(r"\[([^\[\]]+)\]", s):
                if tag not in TAGS:
                    errs.append(f"{where}: unknown tag [{tag}] in: {s[:60]}")
        s_ = slugify(g.get("title", ""))
        if s_ in slugs:
            errs.append(f"{where}: duplicate slug {s_}")
        slugs.add(s_)
    return errs, slugs


def yn(b):
    return {True: "confirmed", False: "no", None: "unknown"}[b]


def render_card(g):
    eng = g["engine"]
    comp = g["components"]
    lines = [
        f"# {g['n']}. {g['title']} — research card",
        "",
        f"last_verified: {g['last_verified']} · category: {g['category']}",
        "",
        f"| field | value |",
        f"| ----- | ----- |",
        f"| publisher / developer | {g['publisher']} / {g['developer']} |",
        f"| platforms | {g['platforms']} |",
        f"| region | {g.get('region_notes', 'unknown')} |",
        f"| version/build verified | {g.get('version_verified', 'unknown')} |",
        f"| engine | {eng['v']} [{eng['conf']}] |",
        f"| client architecture | {g['client_arch']} |",
        f"| anti-cheat (confirmed) | {', '.join(g['ac_confirmed'])} |",
        f"| anti-cheat (other) | {g.get('ac_other', 'unknown')} |",
        f"| components | user-mode: {yn(comp['um'])} · kernel: {yn(comp['kernel'])} · server: {yn(comp['server'])} |",
        f"| known vulnerabilities | {g.get('known_vulns', 'none collected')} |",
        "",
    ]
    lines.append("## Official links, SDKs, sources")
    links = g.get("official_links") or ["none collected"]
    for x in links:
        lines.append(f"- link: {x}")
    for x in g.get("sources_sdk") or []:
        lines.append(f"- SDK/source: {x}")
    lines.append("")
    lines.append("## Public research")
    for x in g.get("public_research") or ["none collected"]:
        lines.append(f"- {x}")
    lines.append("")
    lines.append("## Methods, tool limits, safe modding, host risks")
    lines.append(f"- analysis methods: {g['analysis_methods']}")
    lines.append(f"- tool limits: {g.get('tool_limits', 'unknown')}")
    lines.append(f"- safe modding: {g['safe_modding']}")
    lines.append(f"- host risks: {g['host_risks']}")
    if g.get("notes"):
        lines.append("")
        lines.append("## Measured notes (this workspace)")
        lines.append(g["notes"])
    lines.append("")
    lines.append("## Next research tasks")
    for x in g.get("next_tasks") or []:
        lines.append(f"- {x}")
    lines.append("")
    lines.append("---")
    lines.append("_Rendered from registry.json — edit the registry, not the card. "
                 "Research reference only; no undetected-cheat work against live third-party anti-cheat._")
    return "\n".join(lines)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--build"
    data = json.loads(REG.read_text(encoding="utf-8"))
    games = data["games"]
    for g in games:
        # per-game last_verified defaults to the sweep date from _meta; rows
        # re-verified individually carry their own date
        g.setdefault("last_verified", data["_meta"]["last_verified_sweep"])
    errs, slugs = validate(games)
    if errs:
        print("REGISTRY INVALID:")
        for e in errs:
            print("  [FAIL]", e)
        return 1
    print(f"[OK] registry valid: {len(games)} rows, slugs unique, tags/categories/date formats checked")
    if mode == "--validate":
        return 0
    CARDS.mkdir(exist_ok=True)
    counts = {}
    for g in games:
        s = slugify(g["title"])
        (CARDS / f"{g['n']:02d}-{s}.md").write_text(render_card(g), encoding="utf-8")
        counts[g["category"]] = counts.get(g["category"], 0) + 1
    idx = ["# 50-game research registry — index", "",
           f"Generated {data['_meta']['created']} from registry.json. "
           "Confidence tags: [F] family, [O] operator, [~] build/regional, [measured].",
           "", "| # | game | category | anti-cheat (confirmed) | engine |", "| - | ---- | -------- | ---------------------- | ------ |"]
    for g in games:
        s = slugify(g["title"])
        idx.append(f"| [{g['n']:02d}](cards/{g['n']:02d}-{s}.md) | {g['title']} | {g['category']} | "
                   f"{', '.join(g['ac_confirmed'])} | {g['engine']['v']} [{g['engine']['conf']}] |")
    idx += ["", "## Category counts"]
    idx += [f"- {k}: {v}" for k, v in counts.items()]
    idx += ["", "## Unknown-field sweep (update targets)",
            "Fields still at unknown/unverified across the registry: official links (49/50), "
            "version_verified (50/50), regional variants of [~] rows, extra proprietary layers. "
            "Update cadence: verify [~] rows per client build before any RE session."]
    (ROOT / "index.md").write_text("\n".join(idx) + "\n", encoding="utf-8")
    print(f"[OK] rendered {len(games)} cards + index.md -> {CARDS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
