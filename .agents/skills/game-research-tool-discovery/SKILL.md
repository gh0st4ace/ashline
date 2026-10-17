---
name: game-research-tool-discovery
description: Use whenever a game-research task needs a capability the environment does not yet have - to check installed tooling first, then find, evaluate and (only if justified) integrate open-source tools, skills, MCP servers or knowledge bases, keeping the toolchain lean and verified. Covers GitHub/open-source discovery for game reverse engineering and offlinemod development on Windows.
---

# Tool discovery for game research

The system stays LEAN: install only what a concrete task needs, from official
sources, and record the decision.

## Loop (per task)

1. WHAT IS MISSING: name the exact capability gap ("cannot read .uexp", "need
   a IL2CPP dumper", "want pointer-scan automation"). A vague "more tools" is not
   a gap.
2. CHECK INSTALLED FIRST: consult `~/.config/opencode/AGENTS.md` inventory +
   `D:\opencode\game-lab\knowledge\DISCOVERY_SHEET.md` before new installs —
   the workspace already ships Ghidra/IDA/REA (170 tools), x64dbg, Cheat Engine,
   ReClass.NET, dnSpy, Il2CppDumper, Cpp2IL, dnlib, RenderDoc, bridge scripts.
   Most "need a tool" answers are "use the one already there".
3. SEARCH OFFICIAL CHANNELS ONLY: GitHub search/API (note: anonymous API is
   rate-limited — for release pages use webfetch `releases/expanded_assets/<tag>`),
   official project sites, docs.opencode.ai (skills/mcp/agents docs). Do not take
   tool names from SEO-spam or advertorial pages; the GitHub rating games by
   stars are not a trust signal.
4. EVALUATE each candidate on: license, last push (stale >1y is a flag, not a
   ban), release binaries vs source-only, dependency weight, Windows compatibility,
   whether it duplicates an installed tool, and HOW automation-friendly its
   interface is for this agent (CLI > MCP > GUI-only).
5. INSTALL MINIMALLY:
   - skills: prefer a git shallow clone `D:\opencode\game-lab\external\<repo>` +
     junction each skill dir into `%USERPROFILE%\.agents\skills\<name>` (collision
     with an existing name ⇒ skip and note; do NOT clobber). Record the upstream
     URL, license and date in DISCOVERY_SHEET.md.
   - binaries: official GitHub release asset ONLY (verify repo page matches the
     project owner); unpack to `D:\Tools\<tool>`; never let an installer touch
     Windows dirs or run admin.
   - Do NOT run `npx skills add` / install.ps1 / curl|bash flows: clone and link
     by hand instead — the same effect without executing a third-party bootstrap.
   - MCP servers: only when a cheaper path (CLI/API/skill) fails the need; every
     new MCP costs session tokens and attack surface.
6. VERIFY the install by RUN: a skills junction proves nothing — the announcement
   of the skill in the catalog does; a tool binary must produce output once
   (`--help`, `--version`, or a one-shot run on a bench artifact).
7. RECORD: DISCOVERY_SHEET.md row (repo, role, license, pushed, status, install
   path, verification evidence, date). Memory only for workspace-level facts
   (paths/config), not for individual tool trivia.

## Rejection rules

- Duplicate of an installed tool without a specific capability difference REJECT.
- Gui-only tool with no CLI/scriptable surface — still allowed as an operator
  desktop tool, but never counted as automation.
- No LICENSE, or license hostile to linking/distribution — do not touch.
- Repo that ships binaries without source or provenance — do not run.
- Anything that requires disabling Windows protections (HVCI/DEP/SmartScreen
  explanations aside) — refuse by default; the lab bench / VM rules in
  `anti-cheat-architecture` govern exceptions.

## Output of a discovery session

Diff of DISCOVERY_SHEET.md + a short note about which installed tool was chosen
for the ACTUAL task and why the alternative lost.
