# Third-party notices

This repository **contains no third-party source code.** It declares upstream
collections as runtime dependencies, cloned at install time and governed by
their own licenses.

This project's own code is MIT — see [LICENSE](LICENSE).

---

## Why nothing is vendored

The reference collections total **21.2 GiB**. Vendoring them would mean
republishing other people's work under this repository's name, would break on
every upstream commit, and would exceed GitHub's 100 MB per-file limit outright.

So each is declared with a pinned commit in
[`collections.lock.json`](collections.lock.json) and fetched by script. That file
is the authoritative record.

---

## Declared dependencies

| Project | Upstream | Used for | License |
| --- | --- | --- | --- |
| [gmh5225/awesome-game-security](https://github.com/gmh5225/awesome-game-security) | GitHub | ~40,871 project summaries, 4,105 wiki pages, 13 domain skills | see upstream repo |
| gmh5225/awesome-game-security (`archive/`) | GitHub tarball | 4,086 flat `<owner>/<repo>.txt` files | see upstream repo |
| [yaklang/hack-skills](https://github.com/yaklang/hack-skills) | GitHub | 103 practical security skills | see upstream repo |
| [mukul975/Anthropic-Cybersecurity-Skills](https://github.com/mukul975/Anthropic-Cybersecurity-Skills) | GitHub | 818 skills, 291 MITRE techniques | see upstream repo |
| [dsasmblr/game-hacking](https://github.com/dsasmblr/game-hacking) | GitHub | Curated game-RE tutorials and tools | MIT |
| [dsasmblr/hacking-online-games](https://github.com/dsasmblr/hacking-online-games) | GitHub | GameGuard architecture, server-side emulation, pointer scanning, 8 PDFs | MIT |
| [morluto/rea](https://github.com/morluto/rea) | GitHub | 170-tool MCP server; `docs/` provider guides | MIT |
| [affaan-m/ECC](https://github.com/affaan-m/ECC) | GitHub | Agents, commands, hooks, plugins, custom tools, 315 skills | MIT |
| [microsoft/Windows-driver-samples](https://github.com/microsoft/Windows-driver-samples) | GitHub | Driver source reference (headers, samples) | MIT |
| [mantvya/mantragram](https://github.com/mantvya/mantragram) *(LOLDrivers)* | GitHub + site API | Known-vulnerable-driver feed cache | see upstream |

> **Licenses above are as stated by each upstream project.** Check the upstream
> repository for the authoritative license text — this table is a pointer, not
> legal advice, and it can drift.

---

## MCP servers

Six are configured by this project:

| Server | Source | Tools |
| --- | --- | ---: |
| [morluto/rea](https://github.com/morluto/rea) | npm `rea-agents` | 170 |
| cheat-mcp | Built from source; local patch applied | 72 |
| js-reverse-mcp | npm | 24 |
| [@jshookmcp/jshook](https://www.npmjs.com/package/@jshookmcp/jshook) | npm | 8 |
| [@upstash/context7-mcp](https://www.npmjs.com/package/@upstash/context7-mcp) | npm | 2 |
| renderdoc-mcp | Prebuilt Windows binary | — |

`config/mcp-configs/mcp-servers.json` additionally **catalogues** 34 candidate
servers. It is a reference menu, not a configuration — nothing in it is running,
all credentials are placeholders, and those servers are not installed by this
repo. Their licenses apply to them.

---

## Analysis engines and tools

Not installed by this repo — installed by you, from their own distributors,
under their own licenses:

| Tool | Vendor |
| --- | --- |
| Ghidra | NSA / open source |
| IDA Pro | Hex-Rays (commercial) |
| WinDbg, Windows SDK, WDK | Microsoft |
| x64dbg | open source |
| radare2 / rizin | open source |
| Cheat Engine | open source |
| dnSpy | de4dec (fork) |
| dnlib, AsmResolver | open source |
| Il2CppDumper, Cpp2IL | open source |
| capa, FLOSS, LIEF, DIE | open source |
| Sysinternals Suite | Microsoft |

`D:\Programs\` containing a loose IDA 9.3 that shadows a licensed 9.4 install is
a local environment artifact and not reproduced here.

---

## Local modifications to third-party code

One, documented because a clean `git pull` will conflict with it:

**cheat-mcp** — `src/network.cpp` omits `#include <mstcpip.h>`, which breaks the
`SIO_RCVALL` call. That include is a local fix. It is not upstream code and is
not redistributed here.

---

## Trademarks and attribution

Product and project names referenced in this repository — including game titles
in `knowledge/game-lab/`, vendor names in the driver feed, and tool names
throughout — are the property of their respective owners. Use is nominative: to
identify the projects actually in use.

Collection membership is not endorsement. A project's appearance in a reference
collection is an index entry, not a recommendation and not evidence that the
tool does anything.

---

## Attribution requests

If you own work referenced here and want it corrected or removed, open an issue
or use the private channel in [SECURITY.md](SECURITY.md). Requests will be
honoured.
