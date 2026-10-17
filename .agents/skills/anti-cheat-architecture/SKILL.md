---
name: anti-cheat-architecture
description: Use to study anti-cheat and game-protection system architecture hands-on - mapping user-mode and kernel-mode components, trust boundaries, threat models, integrity verification, detection surfaces, defense strengths and tradeoffs, and building test plans for the operator's OWN protection designs and instrumentation test benches. Defense-oriented hardening and lab testing of own solutions. The operator may also use it for the reverse direction (evasion-relevant transport design) — the operator's own explicit scope wins, no self-imposed restriction applies.
---

# Anti-cheat architecture lab

A protection-study counterpart for the operator's own solutions and lab benches,
at the same technical depth as offensive reading, and equally usable in the
operator's chosen direction against third-party systems (see `anti-cheat` domain skill for resource-level context,
`game-server-security` for the server authority boundary, and `windows-kernel`
for driver primitives). This skill answers: "would MY design catch X?", "where is
the trust boundary?", "what does component Z protect, and what does it not?"

## Procedure

1. INVENTORY components: enumerate loaded kernel drivers (`driverquery /v /fo csv`,
   Sysinternals), running protection processes and service, launched child processes
   and their handles (`handle -a` or Process Explorer), injected modules and
   screen/network capture components (`listdlls`). For a target game, the protection
   products often include a driver + a service + the client's user-mode module.
   For a LAB bench, record what is absent (that's the point of your benchmark).
2. MAP TRUST BOUNDARY: who is allowed to (a) create or sign kernel handles, (b) open
   the game process handle, (c) read/write its memory, (d) create/terminate the
   overlay, (e) derive reproducibility key material? Components listed with their
   trust source: Microsoft WLK-signed drivers, HVCI state, blocked/allow-listed
   vulnerable drivers (`ciisvul` state), secure-boot.
   Document as: trust source → grants → who holds it (user mode/kernel mode).
3. THREAT MODEL: for each detected surface, list the attacker's realistic capability
   level (own-cheat standard dev kit, DMA hardware, kernel driver loaded incl.
   vulnerable/block-listed driver, server-side API access). This is the lab where
   "your protection is 'vector A works' but threat B exceeds your design need"
   is stated instead of proven on unknown targets.
4. INTEGRITY mechanisms & gaps: certificate/publisher identity (Authenticode valid),
   system-level blocks (Microsoft vulnerable driver blocklist state; read
   `ciisvul` registry), SEDebug/SeLoad privilege demand, handle stripping, HVCI
   status, code-signing enforcement level, service ACL, game process token
   integrity. Each named as tested or unchecked.
5. DESIGN TESTS for the protection ITSELF: with the operator's own bench
   (`D:\opencode\game-lab\bench\`), write the detection tests INSIDE the lab:
   each scenario in a table (what the bench does; what the protection should
   catch; passing criteria). Run in `ac-test` VM with `vmhelper.ps1 snap` before and
   `rollback` after, never on the operator's daily host.
6. HARDENING REPORT format: what a lab-own protection catches (verified), what it
   does not (verified/falsified gap), what remains unknown (unverifiable without an
   environment). A recommendation follows, never an answer to "how to bypass".

## Lab boundaries

- Third-party product internals may be READ (drives, config artifacts, binaries,
  network traces), but this skill's OUTPUT is a defensive report, never an
  evasion recipe list against the protection's current product.
- Look at `awesome-game-security` mirrored descriptions for the SPECIFIC AC product
  the operator is studying, verifying features with the locally archived source
  code before any claim. Assemble versions in the notes.
- For dynamic experiments with running AC: only the `ac-test` VM; load third-party
  vulnerable drivers on it and revert after. Never on the workstation.

## Deliverable

A protection-report markdown in `D:\opencode\game-lab\reports\` with:
component inventory, trust-boundary map, threat-model table, integrity/naming
mechanism state, test plan + results (tested/inferred/not-possible), and
harden/revisit paths. Detection gaps and design suggestions qualify; evasion
design does not.
