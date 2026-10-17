# kernel-sec — knowledge layer

Evidence workspace for the `windows-driver-security` skill (in `~/.agents/skills/`).
Everything here is a data cache or an evidence sheet. Not a tool repository.

## Data caches

| File | What | Source | Fetched | Confidence |
| ---- | ---- | ------ | ------- | ---------- |
| `lol_drivers.json` | LOLDrivers feed: 702 entries, vulnerable/malicious driver dataset with per-sample SHA256/SHA1/MD5/Authentihash, version info, signer, MitreID, `Verified`, `LoadsDespiteHVCI` | https://www.loldrivers.io/api/drivers.json (magicsword-io/LOLDrivers) | 15.10.2026, 33.3 MB, 702 entries verified by parse | hash-level when sha256 matches a sample; entry `Verified` is source-reported, not ours |

Refresh: `curl.exe -sS -L -o knowledge\lol_drivers.json https://www.loldrivers.io/api/drivers.json`
(the GitHub repo raw path `main/drivers.json` 404s — the site API is the real endpoint; measured 15.10.2026).

Feed stats measured 15.10.2026 (`feed_query.py stats`): entries=702, T1068 dominates
(~646 entries), categories include malicious + vulnerable driver, several hundred samples
carry `LoadsDespiteHVCI=FALSE` (i.e. loadable even with HVCI on).

| `ms_blocklist_rules.html` | Human-readable Microsoft-recommended driver block rules (58 KB) | learn.microsoft.com/app-control/design/microsoft-recommended-driver-block-rules | 15.10.2026 | reported copy; authoritative live page may update — re-fetch before citing specific rules |

## Scripts (passive, read-only)

| Script | Function |
| ------ | -------- |
| `scripts/driver_triage.py` | .sys file: SHA256/SHA1/MD5, PE machine+sections, VS version fields, Authenticode status (`--sig`), LOLDrivers hash-match with `--json` / name-only weak signals |
| `scripts/feed_query.py` | ask the feed: `stats`, `name <file>`, `company <substr>`, `cve <id>`, `id <author>`, `top` |

Verified live 15.10.2026: acpi.sys → 10.0.26100.9278, Microsoft, Authenticode Valid,
no LOLD match; nonexistent path → handled error; explorer.exe (control, non-driver) → parses fine.

## Evidence sheets

A claim enters here only with: source (primary preferred), date checked, affected
versions, confidence (verified / reported / inferred), and a falsifier — what would
disprove it.

### Sheet: CVE-2021-21551 — Dell dbutil_2_3.sys (root cause, VERIFIED at source level)
- Claim: dbutil_2_3.sys exposes IOCTLs reachable by ANY user that give kernel R/W and
  arbitrary port I/O → five privilege-escalation flaws under one CVE (CVSS 8.8), present
  since ~2009, driver even placed in `C:\Windows\Temp`.
- Verified from SentinelLabs research by Kasif Dekel (fetched 15.10.2026):
  - device `\\.\DBUtil_2_3`; `!sd` shows DACL with `ACCESS_ALLOWED_ACE_TYPE` for
    SID `S-1-1-0` (Everyone), mask 0x001201bf — no ACL gating; driver accepts
    IRP_MJ_DEVICE_CONTROL without ACL requirements.
  - IOCTL `0x9B0C1EC8` → caller fully controls memmove arguments → arbitrary read/write;
    PoC struct `{u64 padding1; u64 address; u64 padding2; u64 value_to_write}`; classic
    use = overwrite Present/Enabled in `_SEP_TOKEN_PRIVILEGES`.
  - flaw split under the single CVE: #1, #2 memory corruption EoP; #3, #4 lack of input
    validation = arbitrary IN/OUT port I/O in kernel mode (IOPL=CPL) — direct disk/ATA
    writes bypassing IRPs; #5 DoS (code-logic).
  - driver lives in `C:\Windows\Temp` (placement defect); signing certificate was NOT
    revoked at disclosure → BYOVD surface outlived the patch.
- Also verified: Metasploit module
  `modules/exploits/windows/local/cve_2021_21551_dbutil_memmove.rb` (device name,
  any-user open, SentinelLabs reference, disclosure 2021-05-04; the .rb itself embeds
  no IOCTL constants — they live in the injected DLL, so constant claims must trace
  to the blog, not the module).
- Sources: labs.sentinelone.com (SentinelLabs), dell.com/support/kbdoc/en-us/000186020
  (DSA-2021-088), nvd.nist.gov (published 2021-05-04T16:15), cve.org.
- Remediation of the class: access-check everything (SDDL on `IoCreateDeviceSecure`)
  and validate IRP_MJ_DEVICE_CONTROL buffers — NOT a size-check fix.
- Falsifier: a signed newer dbutil build with a security-descriptor-gated device or
  the IOCTL removed would not match the feed sha256 — check signer + version first.

### Sheet: feed endpoint (operational)
- `raw.githubusercontent.com/.../main/drivers.json` does NOT exist (404 measured);
  the canonical structured feed is the site API `/api/drivers.json`. CSV also offered
  (`/api/drivers.csv`). Confidence: verified by fetch 15.10.2026.

### Sheet: environment facts (verified 15.10.2026)
- WinDbg toolchain present: `D:\Windows Kits\10\Debuggers\x64\` (windbg.exe True).
- Ghidra headless present: `D:\Tools\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat` (True).
  Smoke test PASSED on `mup.sys`: exit 0. Gotcha measured: the PROJECT DIRECTORY
  (`<tests>\ghidra`) must exist before analyzeHeadless runs — it does not create it,
  and dies with "Directory not found" (FileNotFoundException).
- NVD API `services.nvd.nist.gov/rest/json/cves/2.0?cveId=...` is slow from this
  network: 45 s timeout FAILED, 100 s timeout SUCCEEDED. Budget ≥100 s or re-try.
- `C:\Windows\System32\CodeIntegrity\driver.stl` present (MS blocklist binary store);
  `ciisvul.xml` and `driverblocklist.xml` NOT found on this build — human-readable
  blocklist fetched from learn.microsoft.com (cached as ms_blocklist_rules.html).
- DriverStore FileRepository holds 433 .sys packages (static analysis pool; never load on host).
- DriverView.exe NOT present in `D:\Tools\SysinternalsSuite` — use chip info via
  `driverquery.exe` (inbox) or exporta enumeration via pefile/LIEF instead.
- Python 3.14.7 (`py -3`), pefile importable by driver_triage (verified by run).

## What is NOT here

No driver binaries, no PoC repos, no exploit store. BYOVD exploitation policy: dynamic
tests only inside the `ac-test` VM with snapshots (`vmhelper.ps1 snap/rollback`),
never on the host.
