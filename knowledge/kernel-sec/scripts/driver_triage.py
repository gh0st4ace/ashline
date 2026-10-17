#!/usr/bin/env python3
# driver_triage.py — static triage of a Windows driver .sys file against the
# LOLDrivers feed (https://www.loldrivers.io/api/drivers.json, cached locally).
#
# Passive by construction: computes hashes, reads version metadata, matches
# against the cached LOLDrivers feed by SHA256/SHA1/MD5 and by filename.
# Never loads, never installs, never runs the driver.
#
# Usage:
#   py -3 driver_triage.py <file.sys> [more.sys ...]
#   py -3 driver_triage.py --json <file.sys>        # machine-readable
#   py -3 driver_triage.py --sig <file.sys>         # also fetch Authenticode
#                                                   # status via PowerShell
# Feed path (override): env LOLD_DRIVERS_JSON or default below.

import json, os, sys, hashlib

FEED_DEFAULT = r"D:\opencode\kernel-sec\knowledge\lol_drivers.json"
FEED = os.environ.get("LOLD_DRIVERS_JSON", FEED_DEFAULT)


def file_hashes(path):
    h = {"size": os.path.getsize(path)}
    for name in ("sha256", "sha1", "md5"):
        v = hashlib.new(name)
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                v.update(chunk)
        h[name] = v.hexdigest()
    return h


def version_info(path):
    try:
        import pefile
        pe = pefile.PE(path, fast_load=True)
        pe.parse_data_directories(
            directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]])
        info = {"machine": hex(pe.FILE_HEADER.Machine),
                "sections": [s.Name.rstrip(b"\x00").decode(errors="replace") for s in pe.sections]}
        fi = getattr(pe, "FileInfo", None)
        kv = {}
        if fi:
            for lst in fi:
                for e in lst:
                    if e.Key.decode(errors="replace") == "StringFileInfo":
                        for st in e.StringTable:
                            for k, v in st.entries.items():
                                kv[k.decode(errors="replace")] = v.decode(errors="replace")
        info.update({akey: kv.get(akey, "") for akey in
                     ("ProductVersion", "CompanyName", "FileDescription", "OriginalFilename",
                      "InternalName", "ProductName")})
        info["timestamp"] = pe.FILE_HEADER.TimeDateStamp
        return info
    except Exception as exc:  # non-fatal: metadata is best-effort
        return {"pe_error": repr(exc)}


def load_feed():
    if not os.path.isfile(FEED):
        return [], f"feed missing: {FEED} (run: curl -o {FEED} https://www.loldrivers.io/api/drivers.json)"
    try:
        data = json.load(open(FEED, encoding="utf-8"))
    except Exception as exc:
        return [], f"feed parse error: {exc!r}"
    idx = {"sha256": {}, "sha1": {}, "md5": {}, "name": {}}
    for entry in data:
        mitre = entry.get("MitreID") or "n/a"
        cat = entry.get("Category") or "unknown"
        verified = entry.get("Verified") or "FALSE"
        title = entry.get("Author") or ""
        for s in entry.get("KnownVulnerableSamples", []):
            hit = {
                "MitreID": mitre, "Category": cat, "Verified": verified,
                "Driver": title,
                "Filename": s.get("Filename") or s.get("OriginalFilename") or "",
                "FileVersion": s.get("FileVersion") or "",
                "Company": s.get("Company") or "",
                "LoadsDespiteHVCI": s.get("LoadsDespiteHVCI") or "",
            }
            for k in ("SHA256", "SHA1", "MD5"):
                hv = s.get(k)
                if hv:
                    key = k.lower()
                    idx[key].setdefault(hv.lower(), []).append({**hit, "matched_by": key})
            fname = hit["Filename"].lower()
            if fname:
                idx["name"].setdefault(fname, []).append(
                    {"MitreID": mitre, "Category": cat, "Verified": verified, "Driver": title})
    return idx, f"feed ok: {len(data)} drivers @ {FEED}"


def match(idx, hashes, name):
    hits = []
    for k in ("sha256", "sha1", "md5"):
        hv = hashes.get(k)
        if hv and hv.lower() in idx[k]:
            hits.extend(idx[k][hv.lower()])
    return hits


def main():
    args = sys.argv[1:]
    json_out = "--json" in args
    want_sig = "--sig" in args
    paths = [a for a in args if not a.startswith("--")]
    if not paths:
        print(__doc__)
        return 2
    idx, feed_status = load_feed()
    if not idx:
        print("FATAL:", feed_status)
        return 1
    report = {"feed": feed_status, "results": []}
    for p in paths:
        if not os.path.isfile(p):
            report["results"].append({"path": p, "error": "file not found"})
            continue
        r = {"path": p, "hashes": file_hashes(p), "version": version_info(p)}
        base = os.path.basename(p)
        hits = match(idx, r["hashes"], base)
        r["loldrivers"] = {
            "matched": bool(hits),
            "hits": hits,
            "confidence": "hash-match" if hits else "no-identifier-match",
        }
        if not hits:
            nb = idx["name"].get(base.lower(), [])
            if nb:
                r["loldrivers"]["name_only_hits"] = nb
                r["loldrivers"]["confidence"] = "filename-only (NOT proof — verify version/hashes)"
        if want_sig:
            try:
                import subprocess
                # One call fetches status AND signer identity: the validator run of
                # 15.10.2026 noted --sig gave status only and needed a second
                # Get-AuthenticodeSignature call for the subject CN — fixed here.
                cmd = "$s=Get-AuthenticodeSignature '" + p.replace("'", "''") + "'; "
                cmd += 'if($s){ "$($s.Status)|$($s.SignerCertificate.Subject)|$($s.SignerCertificate.Issuer)" } else { "NoSuchSignature" }'
                out = subprocess.run(["powershell", "-NoProfile", "-Command", cmd],
                                     capture_output=True, text=True, timeout=30)
                parts = (out.stdout or "").strip().split("|")
                r["authenticode_status"] = parts[0] if parts else "unknown"
                if len(parts) >= 2:
                    r["authenticode_subject"] = parts[1]
                    r["authenticode_issuer"] = parts[2] if len(parts) > 2 else ""
            except Exception as exc:
                r["authenticode_status"] = f"error: {exc!r}"
        report["results"].append(r)
    if json_out:
        print(json.dumps(report, indent=1, ensure_ascii=False))
        return 0
    print(f"# {report['feed']}")
    for r in report["results"]:
        print(f"\n== {r['path']} ==")
        if "error" in r:
            print("  ERROR:", r["error"])
            continue
        h = r["hashes"]
        print(f"  size={h['size']} sha256={h['sha256']}")
        v = r["version"]
        print("  machine={} version={} company={}".format(
            v.get("machine", "?"), v.get("ProductVersion", "?"), v.get("CompanyName", "?")))
        ld = r["loldrivers"]
        if ld["matched"]:
            for hit in ld["hits"]:
                print(f"  !! LOLDrivers MATCH [{ld['confidence']}]: {hit.get('Filename') or '?'} "
                      f"Mitre={hit.get('MitreID')} Category={hit.get('Category')} Verified={hit.get('Verified')} "
                      f"LoadsDespiteHVCI={hit.get('LoadsDespiteHVCI')}")
        else:
            if "name_only_hits" in ld:
                print("  [-] LOLDrivers: filename-only matches (weak signal):", ld["name_only_hits"])
            else:
                print("  [-] LOLDrivers: no match")
        if want_sig:
            print("  authenticode:", r.get("authenticode_status", ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
