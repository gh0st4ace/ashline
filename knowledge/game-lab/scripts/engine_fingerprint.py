#!/usr/bin/env python3
# engine_fingerprint.py — detect which engine/stack a local game uses, from file-tree
# and PE evidence only. Passive; never launches the game.
#
# Usage:
#   py -3 engine_fingerprint.py "<game install dir>" [--json]
#   py -3 engine_fingerprint.py --exe "<specific game exe>"   # override candidate
#
# Verdicts are evidence-listed: each evidence line names an actual existing file
# (or, for literal scans, the exact PE it was found in) and why it counts.
import os, sys, json, struct

try:
    import pefile
except ImportError:
    pefile = None

IGNORE_EXE_NAMES = re_names = {"unitycrashhandler", "unitor0", "vc_redist", "dxsetup",
    "crashpad", "simplelauncher", "unitor", "profilecomposer", "unitor0crash"}
LANUNCHER_HINTS = ("launcher", "crash", "redist", "setup", "installer", "eac", "battleye",
    "anticheat", "unitor0", "diag", "watchdog", "patcher")  # substring hints for skipping


def version_of(pe):
    out = {}
    try:
        fi = pe.FileInfo or []
        for lst in fi:
            for e in lst:
                if e.Key.decode(errors="replace") == "StringFileInfo":
                    for st in e.StringTable:
                        for k, v in st.entries.items():
                            out[k.decode(errors="replace")] = v.decode(errors="replace")
    except Exception:
        pass
    return out


def find_exes(root):
    cands = []
    for dirpath, _dirnames, filenames in os.walk(root):
        depth = dirpath[len(root):].count(os.sep)
        if depth > 3:
            _dirnames[:] = []
            continue
        for fn in filenames:
            if fn.lower().endswith(".exe"):
                cands.append(os.path.join(dirpath, fn))
    return cands


def pick_main_exe(exes):
    best = None
    for p in exes:
        low = os.path.basename(p).lower()
        if any(h in low for h in LANUNCHER_HINTS):
            continue
        try:
            sz = os.path.getsize(p)
        except OSError:
            continue
        if best is None or sz > best[0]:
            best = (sz, p)
    return best


class Tree:
    def __init__(self, root):
        self.root = root
        self.files = []           # (relpath, size)
        for dirpath, _dirs, fns in os.walk(root):
            depth = dirpath[len(root):].count(os.sep)
            if depth > 5:
                _dirs[:] = []
                continue
            for fn in fns:
                rel = os.path.relpath(os.path.join(dirpath, fn), root)
                try:
                    self.files.append((rel.replace(os.sep, "/"), os.path.getsize(os.path.join(dirpath, fn))))
                except OSError:
                    pass
        self.files.sort()
        self.lowers = [(r.lower(), s) for r, s in self.files]

    def has(self, pred, path_pred=None):
        rel, size = None, None
        for (low, s), (orig, _) in zip(self.lowers, self.files):
            if pred(low, s) and (path_pred is None or path_pred(low)):
                return orig, s
        return None

    def first_by_name(self, name, require_min=0):
        for (low, s), (orig, _) in zip(self.lowers, self.files):
            if low.endswith(name.lower()) and s >= require_min:
                return orig, s
        return None

    def count_by_ext(self, ext, under=None):
        n = 0
        for (low, s), (orig, _) in zip(self.lowers, self.files):
            if low.endswith("." + ext) and (under is None or under in low):
                n += 1
        return n


def scan_ue_literal(path):
    """Score UE version literal '+release-' or 'release-' lines inside the exe."""
    pat = b"+release-"
    hits = 0
    with open(path, "rb") as f:
        while True:
            chunk = f.read(1 << 20)
            if not chunk:
                break
            hits += chunk.count(pat)
    return hits


def scan_engine_strings(pe, exe, tree):
    ev = []
    lit = scan_ue_literal(exe)
    if lit:
        ev.append(("unreal", "literal '+release-' found %d times in PE %s" % (lit, os.path.relpath(exe, tree.root))))
    return ev, lit


def analyze(root, overrides=None):
    tree = Tree(root)
    exes = find_exes(root)
    main = overrides or pick_main_exe(exes)
    ev = {"dir": root}
    engines = {}
    def add(name, detail):
        engines.setdefault(name, [])
        engines[name].append(detail)
    if main is not None:
        main_size, exe = main
        ev["main_exe"] = os.path.relpath(exe, root)
        ev["main_size"] = main_size
        if pefile:
            try:
                pe = pefile.PE(exe, fast_load=True)
                pe.parse_data_directories(directories=[
                    pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"],
                    pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"]])
                vi = version_of(pe)
                ev["exe_version"] = {k: vi.get(k, "") for k in
                    ("CompanyName", "ProductName", "FileDescription", "ProductVersion")}
                imports = set()
                try:
                    for entry in getattr(pe, "DIRECTORY_ENTRY_IMPORT", []):
                        imports.add(entry.dll.decode(errors="replace").lower())
                except Exception:
                    pass
                ev["exe_imports_sample"] = sorted(list(imports))[:14]
                if any(d.startswith("mscoree") for d in imports):
                    add("managed_dotnet", "exe imports mscoree.dll (managed .NET host)")
                for lit_name in ("dxgi.dll", "d3d11.dll", "d3d9.dll", "vulkan-1.dll", "opengl32.dll"):
                    if any(d.startswith(lit_name.split(".")[0]) for d in imports):
                        pass
            except Exception as exc:
                ev["pe_error"] = repr(exc)
    else:
        ev["main_exe"] = None

    e27 = tree.first_by_name("gameassembly.dll", require_min=1 << 20)
    if e27 is not None:
        add("unity_il2cpp", "GameAssembly.dll present: %s (%d bytes)" % (e27[0], e27[1]))
        gm = tree.first_by_name("global-metadata.dat")
        if gm:
            add("unity_il2cpp", "il2cpp metadata present: %s" % gm[0])

    mono = tree.first_by_name("assembly-csharp.dll")
    if mono is not None:
        add("unity_mono", "Assembly-CSharp.dll present: %s (%d bytes)" % (mono[0], mono[1]))
    mgd = tree.first_by_name("mono.exe") or tree.has(lambda low, s: "/mono/" in low or low.startswith("mono/"))
    if mgd:
        add("unity_mono", "Unity mono runtime dir present: %s" % mgd[0])
    unity_data = tree.has(lambda low, s: low.count("/") == 1 and low.endswith("_data") and s == 0,
                          path_pred=None)
    if False:
        pass
    unity_dir = tree.has(lambda low, s: low.count("/") == 1 and low.endswith("_data") )
    if unity_dir:
        add("unity", "Unity *_Data directory in tree: %s" % unity_dir[0])

    uexp = tree.count_by_ext("uexp")
    umap = tree.count_by_ext("umap")
    pak_under_content = tree.count_by_ext("pak", under="content/paks")
    pak_any = tree.count_by_ext("pak")
    if pak_under_content or uexp or umap:
        if pak_under_content:
            add("unreal", "*.pak under Content\\Paks: %d file(s); uexp=%d umap=%d" %
                (pak_under_content, uexp, umap))
        if uexp or umap:
            add("unreal", "UE asset types present: .uexp=%d .umap=%d" % (uexp, umap))
    elif pak_any and main is not None and ev.get("main_exe"):
        # paks next to the exe, not under Content/Paks -> likely webtech, not UE
        add("webtech_or_other", "*.pak files found outside Content\\Paks (%d) — consider Electron/Chromium; ue pak path required for Unreal" % pak_any)
    engine_dir = tree.has(lambda low, s: low.startswith("engine/") or "/engine/" in low)
    if engine_dir:
        add("unreal", "Engine directory present: %s" % engine_dir[0])
    if main is not None:
        _, lit = scan_engine_strings(None, os.path.join(root, ev["main_exe"]), tree) if main else (None, 0)
    enfusion = tree.has(lambda low, s: low.startswith("dbgv133i") or "/dbgv133i" in low)
    if enfusion:
        add("custom_native_enfusion", "Enfusion artifacts present: %s" % enfusion[0])

    ev["engines"] = engines
    ev["file_count"] = len(tree.files)
    ev["exes_skipped_hint"] = sorted({os.path.basename(p) for p in exes} -
        {os.path.basename(main[1]) for p in [] if main})
    return ev


def verdict(ev):
    eng = ev.get("engines", {})
    scored = {}
    for k, dets in eng.items():
        w = min(50, 10 * len(dets))
        if k == "unity":
            continue  # combined family marker; only target unity_mono/il2cpp for study
        if k in ("unity_il2cpp", "unity_mono", "unreal", "managed_dotnet"):
            w = 1000 if dets else 0
        scored[k] = max(scored.get(k, 0), w) if k != "unity" else w
    order = sorted(scored.items(), key=lambda kv: -kv[1])
    return order


def main():
    args = sys.argv[1:]
    as_json = "--json" in args
    paths = [a for a in args if not a.startswith("--")]
    if not paths:
        print(__doc__)
        return 2
    root = os.path.abspath(paths[0])
    override = None
    if "-exe" in paths or "--exe" in paths:
        i = paths.index("--exe") if "--exe" in paths else paths.index("-exe")
        override = paths[i + 1]
    ev = analyze(root, override)
    ranks = verdict(ev)
    ev["ranked"] = ranks
    if as_json:
        print(json.dumps(ev, indent=1, ensure_ascii=False))
    else:
        print("# dir:", ev["dir"])
        print("main exe:", ev.get("main_exe"), "(%s bytes)" % ev.get("main_size"))
        print("version:", json.dumps(ev.get("exe_version", {}), ensure_ascii=False))
        for k, dets in ev["engines"].items():
            for d in dets:
                print("  [%s] %s" % (k, d))
        if not ev["engines"] or ranks[0][1] == 0 and not any(
                k in ("unity_il2cpp", "unity_mono", "unreal", "managed_dotnet")
                for k in ev["engines"]):
            print("  [custom_native_inferred] no IL2CPP/Mono/UE/managed markers found in tree; "
                  "main exe is native PE — engine likely custom/self-hosted (UNVERIFIED engine identity, "
                  "confirm via exe strings/imports before claiming it)")
        print("VERDICT:", ranks[0][0] if ranks and ranks[0][1] > 0 else "custom-native-or-unknown",
              "| runners:", [r for r in ranks[1:3]])
    return 0


if __name__ == "__main__":
    sys.exit(main())
