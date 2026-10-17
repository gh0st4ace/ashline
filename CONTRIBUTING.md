# Contributing

The evidence discipline is not negotiable. A change that weakens it will be sent
back regardless of how good the code is.

---

## The short version

1. **Label every claim** `verified` / `reported` / `inferred`, and name your
   instrument or your source.
2. **No falsifier, no claim.** A claim without "what observation would disprove
   it" is not finished.
3. **Strike, don't delete.** A wrong claim gets struck in place with what refuted
   it and which instrument did. See [methodology §4](docs/methodology.md#4-superseded-claims-stay-visible).
4. **`unknown` beats a plausible guess.** Invented versions and invented links
   are worse than a blank.
5. **No third-party source.** Declare it as a pinned dependency instead.
6. **No secrets, ever.** Placeholders only.

---

## What gets accepted

| Good | Why |
| --- | --- |
| A failure mode with its cost and the rule it produced | Creates reusable knowledge |
| A measured fact from two independent instruments | Checkable |
| A falsifier that is operationally usable | Not decorative |
| A struck claim explaining what refuted it | Prevents re-derivation |
| An environmental fact that is measured, not assumed | Saves someone the same afternoon |

## What gets sent back

| Rejected | Why |
| --- | --- |
| A claim with no instrument and no source | Unverifiable |
| An offset as an absolute address | Invalidated by ASLR |
| `unknown` replaced with a plausible guess | Worse than a blank |
| Vendored upstream source | Licensing and staleness |
| A plausible-looking but unmeasured check | Silent false confidence |
| Deleted wrong documentation | Guarantees re-derivation |
| A credential, token, or absolute user path | Security defect |

---

## Pull requests

**Branch:** `feat/`, `fix/`, `docs/`, `chore/` — plus a hyphenated subject.

**Title:** imperative, specific, under 72 characters.

> `fix: reject tracebacks as success banners in verify-setup.ps1`
>
> `docs: document the 12/93/3 junction false-green`

**Body:**

```
## What

One paragraph. What changed and why this way.

## Why

The failure mode this addresses, or the capability it adds.
If it fixes a bug, name the instrument that found it and what it returned
before and after.

## Evidence

- Instrument: <command>
- Before: <observed output>
- After: <observed output>

Claim labels used: verified / reported / inferred

## Falsifier

What observation would show this change is wrong or incomplete.
```

That last section is the one that gets skipped and the one that matters most.

---

## Commit messages

Conventional Commits. The `docs:` prefix is used honestly — a doc change that
records a *measured* environmental fact is `docs:`, not `feat:`, and pretending
otherwise is how documentation starts drifting.

---

## Adding a script

Every script in `scripts/` follows the same contract, and each rule exists
because its absence caused a failure:

| Rule | Failure it prevents |
| --- | --- |
| Existence-gated installs | Re-downloading and re-installing |
| Reject downloads under 100 KB | Writing a 404 HTML page as if it were a binary |
| Verify the expected executable is *inside* a directory | A directory that exists but contains nothing usable |
| Tag-pinned URLs | `latest/download` returning an error page |
| `[System.IO.Directory]::Delete($link, $false)` for junctions | Deleting the **upstream** directory |
| PowerShell 5.1 compatible | Silent failure on the shipped OS |
| Always exits 0 for background updaters | A scheduled task reporting failure |
| Document parameters in the header — **and strike stale ones** | Drift |

Name the script in [docs/scripts.md](docs/scripts.md) and add it to
`verify-setup.ps1` if it is a check.

---

## Adding a skill

1. One problem per skill. If it is only a shorter prompt, it does not need to
   exist.
2. State the **failure mode** it prevents, not just its domain.
3. Document when **not** to use it. Ambiguity here is what caused the
   catch-all router problem — see
   [skills-catalog](docs/skills-catalog.md#routers-that-stay-off-catalog).
4. Add it to the routing table in [docs/skills-catalog.md](docs/skills-catalog.md)
   if it owns a boundary.
5. Check for name collisions across **all five** roots, not just the three
   configured ones.

---

## Adding a collection

Follow the six-step checklist in
[docs/collections.md](docs/collections.md#adding-a-collection). The two that get
skipped:

- `edit: deny` on the permission matrix, **after** the grants
- A `Test-Path` check in `verify-setup.ps1`

---

## Style

- **Follow the surrounding code.** These are Windows PowerShell scripts written
  for a specific host. Do not introduce syntax that is 5.1-incompatible.
- **Comments explain *why*.** The code says what it does. If a line looks
  redundant, read the comment above it — several exist to stop a future
  maintainer from "fixing" something deliberate.
- **UTF-8 without BOM.** A BOM breaks YAML frontmatter in some skill readers and
  confuses older tooling.
- **No absolute user paths.** Use `$env:USERPROFILE`, `${CONFIG_DIR}`, or a
  parameter.

---

## Reporting a security issue

Not a public issue. See [SECURITY.md](SECURITY.md).

---

## Code of conduct

Assume the other person is competent and acting in good faith. Disagree with the
claim, not the person. Every contribution here rests on someone's measurement
that they were sometimes wrong about, and the documentation says so.
