# Knowledge workspaces

Two authored data workspaces behind the skills. Both are **evidence stores**, not
tool repositories, and both enforce the same admission rule.

---

## `game-lab`

Game RE / memory research / modding workbench. Backs `game-engine-detection`,
`game-memory-lab`, `game-modding-lab`, `anti-cheat-architecture`, and
`game-research-tool-discovery`.

```
knowledge/game-lab/
├── knowledge/
│   ├── DISCOVERY_SHEET.md          open-tooling decision record
│   ├── ac_stack_map_50games.md     AC product-family traits
│   ├── engine_fingerprint_cases.md Test-1 evidence table
│   ├── session_doc_template.md     per-session evidence template
│   └── games_registry/             50-game registry
├── scripts/  engine_fingerprint.py · game_registry.py · bench_memprobe.py
├── bench/    own MSVC target — health/ammo/name/xp/score
└── reports/  per-session test reports
```

### The games registry

`registry.json` is the source of truth: 50 rows, 22 fields each, validated by
`game_registry.py --validate`.

| Category | Count |
| --- | ---: |
| `shooter-fps` | 15 |
| `battle-royale-survival-extraction` | 13 |
| `mmo-rpg` | 9 |
| `other-online` | 8 |
| `moba-competitive` | 5 |

`client_arch`: 28 `native x64`, 9 `native x64 [unverified]`, 13 other tagged
variants.

### Confidence tags

Enforced by the validator, not by convention:

| Tag | Meaning |
| --- | --- |
| `[F]` | Family-level fact from vendor docs / AreWeAntiCheatYet. Stable for years |
| `[O]` | Operator-supplied pairing. Re-verify against a live build |
| `[~]` | Regional or version-dependent. **MUST** re-verify per client build |
| `[measured]` | Confirmed by this workspace's own instruments |
| `unverified` | Plausible but unchecked |
| `unknown` | Not established — do **not** invent |

### Hard rules

> `unknown` is always better than a plausible guess. Invented versions and
> invented links are worse than a blank.

> Every link in `public_research` must carry a path or URL **plus what it
> claims**. A bare URL is an assertion, not a source.

Boundary: research reference only; no undetected-cheat work against a live
third-party anti-cheat; driver risks go to the VM.

### A subtlety worth knowing

`last_verified` is required by both the schema and the validator, but is
**absent from all 50 entries as stored**. `game_registry.py` injects it at build
time from `_meta.last_verified_sweep`, and the validator uses `.get(..., "")` so
it only format-checks a non-empty value.

So `--validate` passing does **not** mean every row is verified — it means the
rows that carry the field are well-formed. Do not read a green validate as a
freshness guarantee.

---

## `kernel-sec`

Windows driver / BYOVD evidence workspace. Backs `windows-driver-security`.

Self-described as **"a data cache or an evidence sheet. Not a tool
repository."** Everything passive and read-only: no driver binaries, no PoC
repos, no exploit store.

```
knowledge/kernel-sec/
├── knowledge/
│   ├── README.md              evidence sheets — the admission rule
│   ├── lol_drivers.json       702-entry feed cache (33.3 MB)
│   └── ms_blocklist_rules.html
├── scripts/  driver_triage.py · feed_query.py
└── tests/    NVD CVE records, ghidra project dir
```

### The falsifier convention

The admission gate, verbatim:

> A claim enters here only with: source (primary preferred), date checked,
> affected versions, confidence (verified / reported / inferred), and a
> **falsifier** — what would disprove it.

Not decorative. For CVE-2021-21551 the falsifier is operational:

> a signed newer `dbutil` build with a security-descriptor-gated device or the
> IOCTL removed would not match the feed sha256 — check signer + version first.

So finding `dbutil_2_3.sys` on disk is **not** evidence of CVE-2021-21551.
Signature and version provenance are.

This is the workspace's answer to the failure mode where a filename match is
mistaken for proof — the same discipline `game-lab` applies to
`version_verified`.

Note also that BYOVD means *legitimately signed but vulnerable*. "It is signed"
is not a defence. And the class-level remediation is **access checks plus
IRP_MJ_DEVICE_CONTROL buffer validation — not a size-check fix**. A driver that
merely validates buffer sizes would still match a naive "patched" reading and
would be wrong.

---

## The LOLDrivers feed

`knowledge/lol_drivers.json` — a **flat JSON array**, 702 entries, no envelope
metadata.

| Field | Meaning |
| --- | --- |
| `Id` | GUID, stable identifier |
| `Tags` | Driver filenames the entry is filed under |
| `Verified` | `TRUE`/`FALSE` — **source-reported, not ours** |
| `Author` | Research author of the finding |
| `Created` | Publication date |
| `MitreID` | ATT&CK technique id, mostly `T1068` |
| `Category` | `malicious` (124) or `vulnerable driver` (578) |
| `Commands` | The `sc.exe create … && sc.exe start …` load line |
| `Resources` | Analyst writeups, issues, vendor advisories |
| `CVE` | Optional — present in 117/702, often `[""]` |
| `KnownVulnerableSamples[]` | 2407 samples: hashes, PE metadata, certs, sections, imports |

`LoadsDespiteHVCI` across samples: `FALSE` 1666, **`TRUE` 479** — 479 samples
load even with HVCI enabled.

### Provenance lives outside the data

There is **no** `Fetched` or provenance field in the file — probed ten candidate
keys, all 0/702. Provenance lives only in `knowledge/README.md`:

- Source: `https://www.loldrivers.io/api/drivers.json`
- Fetched: 15.10.2026, 33.3 MB, 702 entries verified by parse
- Refresh: `curl.exe -sS -L -o knowledge\lol_drivers.json https://www.loldrivers.io/api/drivers.json`

> [!NOTE]
> The feed's own `Verified` flag is labelled "source-reported, not ours". It is
> **not** our verification. `TRUE` in that field means the upstream maintainer
> verified it.

### Why the feed proves its own failure mode

Three entries in the cache are worth reading before trusting a filename match:

- One self-identifies as `Product: "RansomwareTerminator"` with
  `OriginalFilename: "RWTKrl.sys"` while carrying a legitimate-looking WoSign
  code-signing chain — and its tagged filename is `driver_090d409f.sys`.
- One impersonates CrowdStrike: `Company: "CrowdStrike, Inc."`,
  `Product: "CrowdStrike Falcon Sensor"`, `OriginalFilename: "CSAgent.sys"` —
  and **all normal-section entropies are `0.0`** with a high-entropy section
  named `.lI\``. Packed.
- One shares a byte-identical `RichPEHeaderHash` with the first — same packer
  stub.

Filenames are chosen by the author. Signatures are chosen by whoever signed.
Only hashes are evidence.

---

## `driver_triage.py`

Passive by construction: computes hashes, reads version metadata, matches the
cached feed. **Never loads, installs, or runs the driver.**

```powershell
py -3 driver_triage.py --sig --json <file.sys> [<more.sys> ...]
```

| Capability | Detail |
| --- | --- |
| Hashes | SHA256 + SHA1 + MD5 + size, streamed in 1 MiB chunks |
| PE metadata | machine, sections, `TimeDateStamp`, StringFileInfo fields |
| Feed index | sha256, sha1, md5, and name indices over `KnownVulnerableSamples[]` |
| Match | any of the three hashes → `MitreID`, `Category`, `Verified`, `LoadsDespiteHVCI`, `matched_by` |
| `--sig` | Authenticode via one `Get-AuthenticodeSignature` call: status, subject, issuer |
| `--json` | Machine-readable full report |

### Confidence labelling

This is the part that matters:

| Label | Meaning |
| --- | --- |
| `hash-match` | A hash matched a feed sample |
| `filename-only (NOT proof — verify version/hashes)` | Only the filename matched |
| `no-identifier-match` | Nothing matched |

A filename-only hit is **explicitly labelled as not proof**, and the script
tells you what to check. Do not promote it to a finding.

Feed override: `LOLD_DRIVERS_JSON` env var, else the default path.

`feed_query.py` modes: `stats`, `name`, `company`, `cve`, `id`, `top`.

---

## Pre-session gates

Both workspaces ship a `selfcheck.ps1`:

| Workspace | Assertions | What it protects |
| --- | ---: | --- |
| `game-lab` | 20 | Skills linked, registry schema valid, scripts present, tools resolvable |
| `kernel-sec` | 10 | Feed present and parseable, scripts present, evidence sheets coherent |

Run one before working in it. They are cheap and they catch a broken link before
you build a conclusion on it.

---

## Environmental facts recorded here

Verified 15.10.2026, and worth having written down:

- WinDbg is at `D:\Windows Kits\10\Debuggers\x64\`.
- Ghidra headless smoke-tested PASSED on `mup.sys`.
- **The `analyzeHeadless` project directory must exist before the call**, or it
  dies with `FileNotFoundException`.
- The NVD API needs a ≥100 s timeout from this network — 45 s failed, 100 s
  succeeded.
- `DriverView.exe` is **not** present in the Sysinternals suite. Use
  `driverquery.exe` or pefile/LIEF enumeration.
- DriverStore FileRepository holds 433 `.sys` packages — a static pool. **Never
  load them on the host.**
- Python 3.14.7 with importable pefile.
