#!/usr/bin/env python3
# bench_memprobe.py — lab probe for game-lab\bench\bench_native.exe (v2, verified pattern).
#
# Pipeline:
#   run #1: spawn bench -> parse hdr + ticks -> OpenProcess -> verify memory equals
#           the bench's own printed final state -> close
#   run #2: spawn bench again -> compare module bases -> module+RVA stability check
#   scan:   AOB sweep (last by design; earlier ordering experiments showed order
#           effects in this python host, so probes come first).
#
# Usage: py -3 bench_memprobe.py [--out report.json]
import ctypes, json, math, os, re, struct, subprocess, sys, time

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
PROCESS_VM_READ = 0x0010
PROCESS_QUERY_INFORMATION = 0x0400
BENCH = r"D:\opencode\game-lab\bench\bench_native.exe"
MAP = r"D:\opencode\game-lab\bench\bench_native.map"
DEFAULT_OUT = r"D:\opencode\game-lab\reports\bench_memprobe_report.json"


def rpm_fresh_openread(pid, addr, size):
    h = k32.OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, False, pid)
    if not h:
        return None
    r = rpm_raw(h, addr, size)
    k32.CloseHandle(h)
    return r


def rpm_raw(handle, addr, size):
    buf = ctypes.create_string_buffer(size)
    got = ctypes.c_size_t(0)
    ok = k32.ReadProcessMemory(handle, ctypes.c_void_p(addr), buf, size, ctypes.byref(got))
    return buf.raw[:got.value] if ok else None


def rpm(handle, addr, size):
    # ordering quirk measured: only the FIRST ReadProcessMemory per handle in this
    # python host returns data; later calls return 299/0. Re-open per read.
    return rpm_raw(handle, addr, size)


def parse_map_rva(path, sym):
    """MSVC .map: ` 0003:00000000       g       0000000140009000  obj`
    Rva+Base column minus the 'Preferred load address' image base."""
    if not os.path.isfile(path):
        return None
    txt = open(path, "r", errors="replace").read()
    mimg = re.search(r"Preferred load address is ([0-9A-Fa-f]+)", txt)
    img = int(mimg.group(1), 16) if mimg else 0x140000000
    m = re.search(r"^\s*[0-9a-fA-F]{4}:[0-9a-fA-F]{8}\s+%s\s+([0-9a-fA-F]{8,16})" % re.escape(sym),
                  txt, re.M)
    return int(m.group(1), 16) - img if m else None


def spawn_and_parse(rounds):
    p = subprocess.Popen([BENCH, "--rounds", str(rounds)], stdout=subprocess.PIPE, text=True)
    hdr, ticks, aob, final = {}, [], None, None
    re_hdr = re.compile(r"hdr_(module_base|apply_damage|g)=([0-9a-fA-F]+)")
    re_aob = re.compile(r"hdr_g_aob_static=([0-9a-f]+)")
    re_tick = re.compile(r"tick=(\d+) health=([\d.-]+) ammo=(\d+) xp=(\d+) calls=(\d+)")
    re_final = re.compile(r"final tick=(\d+) health=([\d.-]+) calls=(\d+)")
    for line in p.stdout:
        s = line.strip()
        m = re_hdr.match(s)
        if m:
            hdr[m.group(1)] = int(m.group(2), 16)
            continue
        m = re_aob.match(s)
        if m:
            aob = bytes.fromhex(m.group(1))
            continue
        m = re_tick.match(s)
        if m:
            ticks.append(dict(tick=int(m.group(1)), health=float(m.group(2)),
                              ammo=int(m.group(3)), xp=int(m.group(4)), calls=int(m.group(5))))
            continue
        m = re_final.match(s)
        if m:
            final = dict(tick=int(m.group(1)), health=float(m.group(2)), calls=int(m.group(3)))
            continue
        if s == "ends":
            break
    return p, hdr, ticks, aob, final


def rva_of_map_run():
    return parse_map_rva(MAP, "g")


def verify_run1():
    p, hdr, ticks, aob, final = spawn_and_parse(2)
    pid = p.pid
    base = hdr.get("module_base")
    g = hdr.get("g")
    rva_map = rva_of_map_run()
    if rva_map is not None and base + rva_map != g:
        print("[probe] WARNING: map rva does not match runtime g")
    r32 = rpm_fresh_openread(pid, g, 64)
    mem_health = struct.unpack("<f", r32[0:4])[0] if (r32 and len(r32) >= 4) else None
    mem_calls = struct.unpack("<l", r32[36:40])[0] if (r32 and len(r32) >= 40) else None
    aob_at = None
    if aob:
        r64 = rpm_fresh_openread(pid, g, 64)
        aob_at = bool(r64 and len(r64) >= 32 and r64[4:32] == aob)
    try:
        p.wait(timeout=20)
    except Exception:
        p.kill()
    return {"base": hex(base), "g": hex(g), "map_rva": rva_map,
            "map_base_plus_rva_matches_hdr": (rva_map is not None and base + rva_map == g),
            "read32_ok": r32 is not None, "mem_health": mem_health,
            "printed_final_health": final["health"] if final else None,
            "mem_health_eq_printed": (mem_health == final["health"]) if (final and mem_health is not None) else None,
            "mem_calls": mem_calls,
            "printed_final_calls": final["calls"] if final else None,
            "mem_calls_eq_printed": (mem_calls == final["calls"]) if (final and mem_calls is not None) else None,
            "aob_static_matches": aob_at}


def stability_run2():
    """restart bench: module base may change per ASLR; g_RVA must be constant."""
    p, hdr, _ticks, _aob, _final = spawn_and_parse(1)
    info = {"base2": hex(hdr.get("module_base", 0)), "g2": hex(hdr.get("g", 0))}
    rva_map = rva_of_map_run()
    b2 = hdr.get("module_base", 0); g2 = hdr.get("g", 0)
    info["rva_stable"] = (rva_map is not None and g2 - b2 == rva_map)
    try:
        p.wait(timeout=20)
    except Exception:
        p.kill()
    return info


def aob_scan(pid, aob: bytes, base, g, limit=(256 << 20)):
    class MBI(ctypes.Structure):
        _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p),
                    ("AllocationProtect", ctypes.c_ulong), ("RegionSize", ctypes.c_size_t),
                    ("State", ctypes.c_ulong), ("Protect", ctypes.c_ulong), ("Type", ctypes.c_ulong)]
    hits = []
    addr = 0
    total = 0
    while addr < (1 << 47) and total < limit:
        mbi = MBI()
        r = k32.VirtualQueryEx(pid, ctypes.c_void_p(addr), ctypes.byref(mbi), ctypes.sizeof(MBI))
        if r == 0:
            break
        sz = mbi.RegionSize or 0
        if mbi.State == 0x1000 and (mbi.Protect & 0xFF) not in (0, 1, 0x100):
            chunk = rpm_fresh_openread(pid, addr, min(sz, 1 << 20))
            if chunk:
                total += len(chunk)
                pos = chunk.find(aob, 0)
                while pos != -1:
                    hits.append(addr + pos - 4)
                    pos = chunk.find(aob, pos + 1)
        addr = addr + sz
    return hits


def scan_run3():
    p, hdr, _t, aob, _f = spawn_and_parse(1)
    hits = aob_scan(p.pid, aob, hdr.get("module_base"), hdr.get("g")) if aob else []
    hit_match = hdr.get("g") in hits
    try:
        p.wait(timeout=20)
    except Exception:
        p.kill()
    return {"aob_hits": len(hits), "aob_match_hdr": hit_match}


if __name__ == "__main__":
    report = {"run1": verify_run1(), "run2": stability_run2(), "run3": scan_run3()}
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else DEFAULT_OUT
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=1)
    print(json.dumps(report, indent=1))
