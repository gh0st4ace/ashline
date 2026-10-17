---
layout: home

hero:
  name: OpenCode Workbench
  text: One hardened OpenCode setup.
  tagline: Security research, reverse engineering, and game internals — with the evidence discipline and the health checks written down.
  actions:
    - theme: brand
      text: Get started
      link: /installation
    - theme: alt
      text: Methodology
      link: /methodology
    - theme: alt
      text: View on GitHub
      link: https://github.com/YOUR_USER/opencode-workbench

features:
  - title: Evidence, not confidence
    details: Every claim is verified, reported, or inferred. No claim enters the store without a source, a date, affected versions, and a falsifier.
    link: /methodology
  - title: Instruments that get instrumented
    details: verify-setup.ps1 executes every tool rather than resolving it, rejects tracebacks as banners, and bounds every substring.
    link: /scripts
  - title: 174 skills, one routing protocol
    details: Load one domain skill by default. Two only when two boundaries genuinely dominate. Never read a collection wholesale.
    link: /skills-catalog
---

## Start with one command

```powershell
git clone https://github.com/YOUR_USER/opencode-workbench
cd opencode-workbench
.\install.ps1 -DryRun
```

The installer prints every step before it runs. Nothing is written until you drop
the flag.

Then prove the install:

```powershell
.\scripts\verify-setup.ps1     # toolchain + wiring, always exits 0
py -3 .\scripts\doctor.py      # runtime health, exits 0/1/2 — CI-usable
```

## What you get

| Component | Count |
| --- | ---: |
| Skills across 5 discovery roots | 174 |
| Reference collections | 7 |
| Live MCP tools | 277 |
| Authored domain agents | 4 |
| Maintenance scripts | 20 |
| Knowledge workspaces | 2 |

See [collections](/collections) for the 21.2 GiB of upstream collections this
repo declares as dependencies rather than vendoring.

## Start reading

| If you want to | Read |
| --- | --- |
| Install it | [installation](/installation) |
| Understand the design | [architecture](/architecture) |
| Adopt the discipline | [methodology](/methodology) |
| Pick a skill | [skills catalog](/skills-catalog) |
| Fix something broken | [troubleshooting](/troubleshooting) |
| Review it for attack surface | [agentic security](/agentic-security) |
