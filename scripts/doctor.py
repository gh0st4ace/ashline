#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""
doctor.py — проверка здоровья окружения OpenCode и проекта OBSIDIAN.

Проверяет ровно те вещи, которые уже ломали работу:
  1. рассинхрон версий движков (npm CLI против desktop) — убивал сессии
  2. призрачные документы в drafts.sqlite — давали "Session not found"
  3. раздутый кэш плагинов и мёртвые каталоги
  4. сессии без сжатия — дают invalid_request_error на длинной истории
  5. состояние конфига
  6. ошибки в серверном логе
  7. проект: git, идентичность клиента, доказательства verify

Запуск:  py -3 %USERPROFILE%\.config\opencode\doctor.py
Код возврата: 0 — чисто, 1 — есть предупреждения, 2 — есть поломки.
"""

import io
import os
import re
import sys
import json
import glob
import sqlite3
import subprocess
import collections

HOME = os.path.expanduser("~")
CFG = os.path.join(HOME, ".config", "opencode")
DATA = os.path.join(HOME, ".local", "share", "opencode")
STATE = os.path.join(HOME, ".local", "state", "opencode")
CACHE = os.path.join(HOME, ".cache", "opencode", "npm")
DESKTOP = os.path.join(HOME, "AppData", "Roaming", "ai.opencode.desktop")
LOG = os.path.join(DATA, "log", "opencode.log")
DRAFTS = os.path.join(DESKTOP, "drafts.sqlite")
DB = os.path.join(DATA, "opencode.db")
PROJECT = os.path.join(HOME, "Desktop", "OBSIDIAN")

problems = []
warnings = []
oks = []


def ok(t):
    oks.append(t)


def warn(t):
    warnings.append(t)


def bad(t):
    problems.append(t)


def hr(title):
    print()
    print("=" * 74)
    print(title)
    print("=" * 74)


def h(size):
    for u in ("B", "KB", "MB", "GB"):
        if size < 1024:
            return "%.1f %s" % (size, u)
        size /= 1024.0
    return "%.1f TB" % size


# ---------------------------------------------------------------- 1. версии
hr("1. ВЕРСИИ ДВИЖКОВ")
npm_ver = None
p = os.path.join(HOME, "AppData", "Roaming", "npm", "node_modules",
                 "@opencode", "cli", "package.json")
if os.path.exists(p):
    npm_ver = json.load(io.open(p, encoding="utf-8")).get("version")
    print("  npm CLI        : %s" % npm_ver)
else:
    print("  npm CLI        : не найден")

svc = None
sp = os.path.join(STATE, "service.json")
if os.path.exists(sp):
    try:
        svc = json.load(io.open(sp, encoding="utf-8"))
        alive = False
        if svc.get("pid"):
            try:
                os.kill(svc["pid"], 0)
                alive = True
            except Exception:
                alive = False
        print("  desktop service: %s  pid=%s  alive=%s" % (
            svc.get("version"), svc.get("pid"), alive))
    except Exception as e:
        print("  desktop service: нечитаем (%s)" % e)

if npm_ver and svc and svc.get("version"):
    if npm_ver != svc["version"]:
        bad("версии движков РАСХОДЯТСЯ: npm %s против desktop %s — "
            "любой вызов opencode из терминала убьёт сервис приложения"
            % (npm_ver, svc["version"]))
    else:
        ok("версии движков совпадают (%s)" % npm_ver)


# ------------------------------------------------------- 2. призраки в drafts
hr("2. ПРИЗРАЧНЫЕ СЕССИИ В drafts.sqlite")
if os.path.exists(DRAFTS) and os.path.exists(DB):
    real = set()
    try:
        c = sqlite3.connect("file:%s?mode=ro" % DB.replace("\\", "/"), uri=True)
        for t in ("session_v2", "session"):
            try:
                real |= {r[0] for r in c.execute("select id from %s" % t)}
            except Exception:
                pass
        c.close()
        d = sqlite3.connect("file:%s?mode=ro" % DRAFTS.replace("\\", "/"), uri=True)
        rx = re.compile(r"ses_[A-Za-z0-9]+")
        gdoc = gsta = 0
        for (k,) in d.execute("select key from document"):
            m = rx.search(k)
            if m and m.group(0) not in real:
                gdoc += 1
        for (k,) in d.execute("select key from state"):
            m = rx.search(str(k))
            if m and m.group(0) not in real:
                gsta += 1
        d.close()
        print("  живых сессий в базе   : %d" % len(real))
        print("  призрачных документов : %d" % gdoc)
        print("  призрачных записей    : %d" % gsta)
        if gdoc or gsta:
            bad("в drafts.sqlite %d призраков — UI будет опрашивать несуществующие "
                "сессии и показывать 'Session not found'. Чистить: "
                "py -3 %s\\..\\clean_drafts.py" % (gdoc + gsta, CFG))
        else:
            ok("призраков нет")
    except Exception as e:
        warn("не удалось проверить drafts.sqlite: %s" % e)
else:
    warn("drafts.sqlite или opencode.db не найдены")


# ------------------------------------------------------ 3. кэш плагинов
hr("3. КЭШ ПЛАГИНОВ")
if os.path.isdir(CACHE):
    total = 0
    dirs = []
    for name in sorted(os.listdir(CACHE)):
        full = os.path.join(CACHE, name)
        if not os.path.isdir(full):
            continue
        sz = 0
        for dp, _dn, fn in os.walk(full):
            for f in fn:
                try:
                    sz += os.path.getsize(os.path.join(dp, f))
                except Exception:
                    pass
        total += sz
        dirs.append((name, sz))
    print("  всего: %s" % h(total))
    for name, sz in dirs:
        print("     %-34s %10s" % (name, h(sz)))
    stg = [n for n, _ in dirs if n.startswith(".staging-")]
    if stg:
        warn("осиротевших .staging- каталогов: %d — мусор от сорванных установок"
             % len(stg))
    if total > 4 * 1024 ** 3:
        warn("кэш плагинов больше 4 ГБ — стоит почистить неиспользуемые")
    else:
        ok("кэш плагинов в разумных пределах")
else:
    print("  кэша нет")


# --------------------------------------------------- 4. сессии без сжатия
hr("4. СЕССИИ БЕЗ СЖАТИЯ (причина invalid_request_error)")
if os.path.exists(DB):
    try:
        c = sqlite3.connect("file:%s?mode=ro" % DB.replace("\\", "/"), uri=True)
        rows = c.execute("select id, title from session_v2").fetchall()
        flagged = 0
        for sid, title in rows:
            n = c.execute("select count(*) from session_message where session_id=?",
                          (sid,)).fetchone()[0]
            # только УСПЕШНЫЕ сжатия: провалившееся (status=failed) ничего не сжимает
            ncomp = 0
            for (data,) in c.execute(
                    "select data from session_message"
                    " where session_id=? and type='compaction'", (sid,)):
                try:
                    if json.loads(data).get("status") == "completed":
                        ncomp += 1
                except Exception:
                    pass
            if n > 400 and ncomp == 0:
                flagged += 1
                print("  [!] %-34s %5d сообщений, 0 успешных сжатий" % (sid, n))
                print("      %s" % (title or "")[:66])
        if flagged:
            bad("%d сессий без сжатия — на длинной истории провайдер отвергает "
                "запрос (invalid_request_error). Лечится сжатием или новой сессией."
                % flagged)
        else:
            ok("сессий без сжатия нет")
        c.close()
    except Exception as e:
        warn("не удалось проверить сессии: %s" % e)
else:
    warn("opencode.db не найдена")


# ------------------------------------------------------------ 5. конфиг
hr("5. КОНФИГ")
cfgs = sorted(glob.glob(os.path.join(CFG, "opencode.jsonc*")))
active = os.path.join(CFG, "opencode.jsonc")
print("  активный opencode.jsonc: %s" % ("ЕСТЬ" if os.path.exists(active) else "ОТСУТСТВУЕТ"))
for f in cfgs:
    print("     %-44s %8d B" % (os.path.basename(f), os.path.getsize(f)))
if not os.path.exists(active):
    warn("opencode.jsonc отсутствует — настройки (плагины, MCP, компакция) не применяются")
else:
    ok("конфиг активен")


# --------------------------------------------------------- 6. лог сервера
hr("6. ЛОГ СЕРВЕРА")
if os.path.exists(LOG):
    size = os.path.getsize(LOG)
    tail = collections.deque(maxlen=4000)
    with io.open(LOG, encoding="utf-8", errors="replace") as f:
        for line in f:
            tail.append(line)
    errs = sum(1 for l in tail if "level=ERROR" in l)
    kinds = collections.Counter()
    for l in tail:
        if "level=ERROR" not in l:
            continue
        m = re.search(r'message="?([^"\s][^"]{0,50})', l)
        if m:
            kinds[m.group(1)] += 1
    print("  размер лога      : %s" % h(size))
    print("  ERROR в последних %d строках: %d" % (len(tail), errs))
    for k, v in kinds.most_common(6):
        print("     %4d  %s" % (v, k))
    if errs > 40:
        warn("много ошибок в свежем хвосте лога — смотреть выше")
    else:
        ok("свежий хвост лога чист")
else:
    warn("лог не найден")


# ------------------------------------------------------------- 7. проект
hr("7. ПРОЕКТ OBSIDIAN")
if os.path.isdir(PROJECT):
    def git(*a):
        try:
            r = subprocess.run(["git", "-C", PROJECT] + list(a),
                               capture_output=True, text=True, timeout=30)
            return r.returncode, (r.stdout or "") + (r.stderr or "")
        except Exception as e:
            return 1, str(e)

    rc, out = git("rev-parse", "--is-inside-work-tree")
    if rc == 0:
        rc2, dirty = git("status", "--porcelain")
        n = len([l for l in dirty.splitlines() if l.strip()])
        rc3, log1 = git("log", "--oneline", "-1")
        print("  git              : есть")
        print("  последний коммит : %s" % log1.strip()[:70])
        print("  незакоммичено    : %d файл(ов)" % n)
        if n > 0:
            warn("есть незакоммиченные изменения — точка возврата отсутствует")
        else:
            ok("репозиторий чист")
    else:
        bad("git в проекте НЕТ — откатиться к проверенному состоянию нечем")

    hf = os.path.join(PROJECT, "docs", "HANDOFF.md")
    if os.path.exists(hf):
        lines = 0
        with io.open(hf, encoding="utf-8", errors="replace") as f:
            for _ in f:
                lines += 1
        print("  HANDOFF.md       : %s, %d строк" % (h(hf and os.path.getsize(hf)), lines))
        if lines > 10:
            print("                     сводка: py -3 tools\\state.py")

    st = os.path.join(PROJECT, "overlay", "game", "sig_table.h")
    if os.path.exists(st):
        txt = io.open(st, encoding="utf-8", errors="replace").read()
        m = re.search(r"kClientTimeDateStamp\s*=\s*(0x[0-9a-fA-F]+)", txt)
        sig = m.group(1) if m else "?"
        npat = len(re.findall(r'^\s*\{\s*"', txt, re.M))
        print("  sig_table TDS    : %s (шаблонов: %d)" % (sig, npat))
        if sig.lower() != "0x6a72fc58":
            warn("sig_table привязана к TDS %s, а проект проверялся на 0x6a72fc58 — "
                 "сверить с установленным клиентом" % sig)
else:
    warn("папка проекта не найдена: %s" % PROJECT)


# ------------------------------------------------- 8. идентичность клиента
hr("8. ИДЕНТИЧНОСТЬ ИГРОВОГО КЛИЕНТА")
DAYZ = os.environ.get("WB_GAME_CLIENT") or r"H:\SteamLibrary\steamapps\common\DayZ\DayZ_x64.exe"
EXPECTED_TDS = 0x6A72FC58
EXPECTED_SOI = 0x4406000

if os.path.exists(DAYZ):
    def pe_identity(path):
        """TimeDateStamp и SizeOfImage из PE-заголовка."""
        with open(path, "rb") as f:
            head = f.read(0x400)
            if head[:2] != b"MZ":
                return None, None
            pe = int.from_bytes(head[0x3C:0x40], "little")
            if head[pe:pe + 4] != b"PE\0\0":
                return None, None
            tds = int.from_bytes(head[pe + 8:pe + 12], "little")
            soi = int.from_bytes(head[pe + 80:pe + 84], "little")
            return tds, soi

    tds, soi = pe_identity(DAYZ)
    size = os.path.getsize(DAYZ)
    print("  путь     : %s" % DAYZ)
    print("  TimeDateStamp : 0x%08X   (ожидается 0x%08X)" % (tds or 0, EXPECTED_TDS))
    print("  SizeOfImage   : 0x%08X   (ожидается 0x%08X)" % (soi or 0, EXPECTED_SOI))
    print("  размер файла  : %s" % h(size))

    if tds == EXPECTED_TDS and soi == EXPECTED_SOI:
        ok("клиент тот же, на котором снимались смещения")
    else:
        bad("КЛИЕНТ СМЕНИЛСЯ. Все смещения и таблица сигнатур относятся к "
            "TDS 0x%08X / SizeOfImage 0x%08X. На этом бинарнике их НЕЛЬЗЯ "
            "использовать без повторной проверки." % (EXPECTED_TDS, EXPECTED_SOI))
        if tds and tds != EXPECTED_TDS:
            print("      (игра обновилась — вероятно, патч DayZ)")
        if soi and soi != EXPECTED_SOI:
            print("      (изменился размер образа — структура кода другая)")
else:
    warn("DayZ_x64.exe не найден по пути %s — проверка идентичности пропущена" % DAYZ)


# ------------------------------------------------------------- итог
hr("ИТОГ")
print("  проверок пройдено : %d" % len(oks))
print("  предупреждений    : %d" % len(warnings))
print("  поломок           : %d" % len(problems))
for t in oks:
    print("   [ ok ] %s" % t)
for t in warnings:
    print("   [warn] %s" % t)
for t in problems:
    print("   [BAD ] %s" % t)
print()
sys.exit(2 if problems else (1 if warnings else 0))
