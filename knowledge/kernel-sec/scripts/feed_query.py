#!/usr/bin/env python3
# feed_query.py — ask the cached LOLDrivers feed questions.
#
# Usage:
#   py -3 feed_query.py name gdrv.sys          # exact filename match (any sample)
#   py -3 feed_query.py company "micro star"   # substring on sample Company
#   py -3 feed_query.py cve CVE-2021-21551     # substring across Resources
#   py -3 feed_query.py stats                  # dataset summary counts
#   py -3 feed_query.py id <author-substring>  # substring on entry Author
# Output: one line per match: filename | company | FileVersion | sha256[:16]
#         | Mitre | Category | Verified | DriverAuthor
import json, os, sys
FEED = os.environ.get("LOLD_DRIVERS_JSON", r"D:\opencode\kernel-sec\knowledge\lol_drivers.json")

data = json.load(open(FEED, encoding="utf-8"))
args = sys.argv[1:]
mode = args[0].lower() if args else "stats"
q = args[1] if len(args) > 1 else ""
q = q.lower()


def fmt(e, s):
    fn = s.get("Filename") or s.get("OriginalFilename") or "?"
    comp = s.get("Company") or "?"
    ver = s.get("FileVersion") or s.get("ProductVersion") or "?"
    sha = (s.get("SHA256") or "")[:16]
    hv = s.get("LoadsDespiteHVCI") or ""
    return (f"{fn:28s} | {comp[:28]:28s} | {ver:16s} | sha256={sha} | "
            f"{e.get('MitreID') or 'n/a':10s} | {e.get('Category') or '?':10s} | "
            f"Verified={str(e.get('Verified') or 'FALSE')[:5]:5s} | HVCI={hv:5s} | {e.get('Author') or ''}")


def show(e, s):
    print(fmt(e, s))


if mode == "stats":
    from collections import Counter
    samples = [s for e in data for s in e.get("KnownVulnerableSamples", [])]
    print(f"entries={len(data)} vulnerable_samples={len(samples)}")
    print("Category:", Counter((e.get("Category") or "?").lower() for e in data).most_common())
    print("Verified:", Counter(str(e.get("Verified") or "?") for e in data).most_common())
    print("MitreID:", Counter(e.get("MitreID") or "n/a" for e in data).most_common(10))
    print("LoadsDespiteHVCI:", Counter(str(s.get("LoadsDespiteHVCI") or "?") for s in samples).most_common())
    sys.exit(0)

for e in data:
    if mode == "name":
        for s in e.get("KnownVulnerableSamples", []):
            fn = (s.get("Filename") or s.get("OriginalFilename") or "").lower()
            if fn == q:
                show(e, s)
    elif mode == "company":
        for s in e.get("KnownVulnerableSamples", []):
            if q in (s.get("Company") or "").lower():
                show(e, s)
    elif mode == "cve":
        blob = json.dumps(e.get("Resources", []), default=str) + " "
        blob += json.dumps(e.get("KnownVulnerableSamples", []), default=str) + " "
        blob += e.get("Author") or ""
        if q in blob.lower():
            s0 = (e.get("KnownVulnerableSamples") or [{}])[0]
            show(e, s0)
    elif mode == "id":
        if q in (e.get("Author") or "").lower():
            s0 = (e.get("KnownVulnerableSamples") or [{}])[0]
            show(e, s0)
    elif mode == "top":
        if (e.get("Category") or "").lower() in ("malicious", "vulnerable"):
            s0 = (e.get("KnownVulnerableSamples") or [{}])[0]
            show(e, s0)
