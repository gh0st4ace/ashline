# Disclaimer

## Scope

This workbench is for **legitimate security research, reverse engineering, and
game-internals work on systems you own or are authorised to test.**

**In scope**

- Your own software, your own game projects, offline sessions
- Lab benches — including the self-built `bench_native` target
- Systems where you hold explicit written authorisation
- Vulnerability research on software you have a legitimate interest in
- Anti-cheat architecture study as defensive threat modelling

**Out of scope**

- Undetected cheat development or deployment against a live third-party
  anti-cheat
- Accessing systems you do not own or have authorisation for
- Evasion of protective measures on third-party production systems
- Anything under the active instruction set of a live competitive service

The 50-game registry in `knowledge/game-lab/` is a **research reference**. It
records engine, anti-cheat, and tooling facts. It is not a target list.

---

## Legal

Reverse engineering, interoperability, and security research are lawful in many
jurisdictions and restricted in others. Exemptions exist in the EU (Software
Directive Art. 6), the US (DMCA 17 U.S.C. §1201(f)), the UK, Japan, Australia,
and elsewhere — with conditions that vary, often including that the information
not already be available by other means, and that it not be used to infringe.

**Nothing here is legal advice.** The line between protected research and
prohibited access is jurisdictional and fact-specific, and it is your
responsibility to know where you are. If you are unsure, get a lawyer before you
get a tool.

You are solely responsible for how you use anything in this repository.

---

## Third-party software

This repository **bundles no third-party source**. It declares upstream
collections as dependencies; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Consequences you accept:

- Upstream tools are installed on your machine at install time and are governed
  by **their** licenses, not this repo's.
- Their behaviour can change without this repo changing.
- Availability depends on upstream staying up.
- **Collection membership is not endorsement and is not evidence of capability.**
  A project appearing in a reference collection is an index entry.

Some referenced tools are dual-use offensive tooling. Their presence in a
reference catalog is a **fact about the field**, not a recommendation.

---

## No warranty

Provided "AS IS", without warranty of any kind, as stated in the
[MIT license](LICENSE).

Specifically, this workbench makes **no accuracy claim** about any offset,
version, or vulnerability record it ships. Those are point-in-time records that
go stale — sometimes silently, which is exactly what
`doctor.py`'s client-identity check exists to catch.

Verify everything against your own build before relying on it.

---

## Data and privacy

- **No telemetry.** Nothing in this repo phones home.
- **No secrets shipped.** All credential slots in `config/` are placeholders.
- **Memory is local.** The vector store is on your disk; its web UI is bound to
  `127.0.0.1`.
- **Memory auto-capture is disabled** in this configuration. Nothing enters
  context without a human writing it.

If you enable a hosted MCP server from the catalog, you are sending data to that
provider under their terms. Read them.

---

## Safety practices this repo enforces

| Rule | Why |
| --- | --- |
| Dynamic kernel tests run in a snapshot-able VM, never the host | A malformed `.sys` blue-screens the machine |
| Agent work runs unelevated by default | Limits blast radius |
| `edit: deny` on all third-party paths | Prevents silent mutation of other people's repos |
| Offsets stated as module + RVA, never absolute addresses | ASLR invalidates absolutes immediately |
| Client identity checked before offsets are trusted | A client update invalidates every offset silently |

These are engineering practices, not legal restrictions. They exist because they
protect your machine and cost nothing.
