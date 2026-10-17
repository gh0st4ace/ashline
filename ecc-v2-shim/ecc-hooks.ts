/**
 * ECC hooks + custom tools — OpenCode v2 native plugin (Promise style).
 *
 * Ported 2026-10-16 from the v1 function plugin (ECC 2.2.3, `ECCHooksPlugin`)
 * because OpenCode >= 2.x only loads `{ id, setup() | effect() }` object
 * plugins and rejects the old function export with:
 *   "Plugin must export a default definition with an id and an effect
 *    or setup function."
 *
 * Behavior parity with the v1 plugin, hook by hook:
 *  - tool.execute.before / .after  -> ctx.tool.hook(...)              (ported)
 *  - permission.ask                 -> ctx.permission.hook("evaluate") (ported;
 *      read-only/formatter/test commands auto-allow, rest untouched)
 *  - shell.env                      -> ctx.shell.hook("create.before") (ported;
 *      injects ECC_VERSION/ECC_PLUGIN/PROJECT_ROOT/PACKAGE_MANAGER/
 *      DETECTED_LANGUAGES/CLAUDE_PLUGIN_ROOT into event.env)
 *  - session.created/deleted/idle,
 *    file.edited, file.watcher.updated, todo.updated
 *                                   -> ctx.event.subscribe(...)       (ported
 *      best-effort: matched by server event-type name; silent no-op if
 *      the server ever renames them)
 *  - experimental.session.compacting -> DROPPED: v2 exposes compaction only
 *      as a model-request hook whose `result` would REPLACE the summary.
 *      There is no context-append API, so the ECC context block is not pushed.
 *  - tool: changed-files + dependency-analyzer (+6 more tools registered here:
 *      run-tests, check-coverage, security-audit, format-code, lint-check,
 *      git-summary)                 -> ctx.tool.transform(editor.add)  (ported;
 *      old tool modules are reused as-is, only the registration is v2)
 *
 * V1 (OpenCode 1.x) `server()` compatibility is intentionally NOT included:
 * this host runs OpenCode v2.0.29, which ignores `server()`.
 *
 * No third-party imports: node builtins + relative ECC tool/store modules.
 * `export default` is a plain object literal so nothing needs resolving.
 */

import * as fs from "fs"
import * as path from "path"
import { fileURLToPath } from "url"
import { execFile } from "child_process"

// ---------------------------------------------------------------------------
// Small runtime helpers (node only, no shell => Windows-safe).
// ---------------------------------------------------------------------------

function pluginDir(): string {
  try {
    return path.dirname(fileURLToPath(import.meta.url))
  } catch {
    return process.cwd()
  }
}

const PLUGIN_DIR = pluginDir()

function runCapture(cmd: string, args: string[], cwd: string): Promise<{ stdout: string }> {
  return new Promise((resolve) => {
    execFile(cmd, args, { cwd, timeout: 120000, windowsHide: true }, (error, stdout) => {
      resolve({ stdout: error ? "" : String(stdout ?? "") })
    })
  })
}

function countMatchesInFile(file: string, re: RegExp): number {
  try {
    const text = fs.readFileSync(file, "utf-8")
    const lines = text.split("\n")
    let n = 0
    for (const line of lines) {
      re.lastIndex = 0
      if (re.test(line)) n += 1
    }
    return n
  } catch {
    return 0
  }
}

// Server captures plugin stdout into opencode.log; prefix keeps it greppable.
function log(level: "debug" | "info" | "warn" | "error", message: string): void {
  const line = `[ECC] ${message}`
  try {
    if (level === "error") console.error(line)
    else if (level === "warn") console.warn(line)
    else if (level === "debug") console.debug(line)
    else console.info(line)
  } catch {
    // Logging must never break a hook.
  }
}

// ---------------------------------------------------------------------------
// ECC root probing (same artifacts as the v1 plugin).
// ---------------------------------------------------------------------------

const ECC_ROOT_PROBES = {
  root: [path.join("scripts", "lib", "utils.js")],
  skillTracker: [path.join("scripts", "hooks", "skill-run-tracker.js")],
  resolver: [path.join("scripts", "lib", "resolve-ecc-root.js")],
} as const

function findEccRootDir(startDir: string, probes: readonly string[]): string | null {
  let current = startDir
  for (let depth = 0; depth < 5; depth += 1) {
    try {
      if (probes.every((probe) => fs.existsSync(path.join(current, probe)))) return current
    } catch {
      return null
    }
    const parent = path.dirname(current)
    if (parent === current) break
    current = parent
  }
  return null
}

function getECCVersion(eccRootDir?: string | null): string {
  const candidates = [
    eccRootDir,
    path.resolve(PLUGIN_DIR, ".."),
    path.resolve(PLUGIN_DIR, "..", ".."),
  ]
  for (const candidate of candidates) {
    if (!candidate) continue
    try {
      const pkg = JSON.parse(fs.readFileSync(path.join(candidate, "package.json"), "utf-8"))
      if (typeof pkg.version === "string" && pkg.version) return pkg.version
    } catch {
      // next candidate
    }
  }
  return "2.0.0"
}

// ---------------------------------------------------------------------------
// Hook profiles: ECC_HOOK_PROFILE=minimal|standard|strict (default standard),
// ECC_DISABLED_HOOKS=comma-separated hook ids.
// ---------------------------------------------------------------------------

type HookProfile = "minimal" | "standard" | "strict"

function normalizeProfile(value: string | undefined): HookProfile {
  if (value === "minimal" || value === "strict") return value
  return "standard"
}

// ---------------------------------------------------------------------------
// The plugin.
// ---------------------------------------------------------------------------

export default {
  id: "ecc-hooks",
  async setup(ctx: any): Promise<(() => void) | void> {
    const currentProfile = normalizeProfile(process.env.ECC_HOOK_PROFILE)
    const disabledHooks = new Set(
      (process.env.ECC_DISABLED_HOOKS || "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean)
    )
    const profileOrder: Record<HookProfile, number> = { minimal: 0, standard: 1, strict: 2 }
    const profileAllowed = (required: HookProfile | HookProfile[]): boolean => {
      if (Array.isArray(required)) return required.some((e) => profileOrder[currentProfile] >= profileOrder[e])
      return profileOrder[currentProfile] >= profileOrder[required]
    }
    const hookEnabled = (hookId: string, required: HookProfile | HookProfile[] = "standard"): boolean => {
      if (disabledHooks.has(hookId)) return false
      return profileAllowed(required)
    }

    const locationDir: string =
      ctx?.location?.directory ?? ctx?.location?.project?.directory ?? process.cwd()

    const editedFiles = new Set<string>()
    const pendingToolChanges = new Map<string, { path: string; type: "added" | "modified" }>()
    let writeCounter = 0

    const resolveAgainst = (base: string, p: string): string =>
      path.isAbsolute(p) ? p : path.join(base, p)

    const existsAt = (base: string, rel: string): boolean => {
      try {
        return fs.statSync(resolveAgainst(base, rel)).isFile()
      } catch {
        return false
      }
    }

    // -- changed-files store (lazy, best-effort; same rationale as v1) ------
    let changedFilesStore: any | undefined
    try {
      const store = await import("./lib/changed-files-store.ts")
      store.initStore(locationDir)
      changedFilesStore = store
    } catch {
      log("warn", "[ECC] changed-files tracking disabled: could not load the changed-files store.")
    }

    // -- skill-run telemetry (lazy, best-effort; same rationale as v1) ------
    let recordSkillRun: ((payload: unknown) => void) | undefined
    const trackerRoot = findEccRootDir(PLUGIN_DIR, ECC_ROOT_PROBES.skillTracker)
    const eccRoot =
      findEccRootDir(PLUGIN_DIR, ECC_ROOT_PROBES.resolver) ??
      findEccRootDir(PLUGIN_DIR, ECC_ROOT_PROBES.root)
    try {
      const trackerPath = trackerRoot
        ? path.join(trackerRoot, "scripts", "hooks", "skill-run-tracker.js")
        : null
      if (!trackerPath || !fs.existsSync(trackerPath)) throw new Error("skill-run-tracker.js not found")
      const { pathToFileURL } = await import("url")
      const loaded = (await import(pathToFileURL(trackerPath).href)) as any
      const entry = typeof loaded?.run === "function" ? loaded : loaded?.default
      if (!entry || typeof entry.run !== "function") throw new Error("skill-run-tracker.js exposes no run()")
      recordSkillRun = entry.run
    } catch {
      log("warn", "[ECC] skill-run telemetry disabled: could not load scripts/hooks/skill-run-tracker.js.")
    }

    const getFilePath = (args: any): string | null => {
      if (!args) return null
      const p = args.filePath ?? args.file_path ?? args.path
      return typeof p === "string" && p.trim() ? p : null
    };

    // -- tool.execute.before ----------------------------------------------
    try {
      await ctx.tool.hook("execute.before", async (ev: any) => {
        const toolName: string = ev?.tool ?? ev?.name ?? ""
        const args: any = ev?.input ?? ev?.args ?? {}
        const base: string = ev?.cwd ?? ev?.directory ?? locationDir
        if (toolName === "write") {
          const filePath = getFilePath(args)
          if (filePath) {
            const absPath = resolveAgainst(base, filePath)
            let type: "added" | "modified" = "modified"
            try {
              type = fs.existsSync(absPath) ? "modified" : "added"
            } catch {
              type = "modified"
            }
            const key = ev?.callID ?? ev?.id ?? `write-${++writeCounter}-${filePath}`
            pendingToolChanges.set(String(key), { path: filePath, type })
          }
        }
        if (
          hookEnabled("pre:bash:git-push-reminder", "strict") &&
          toolName === "bash" &&
          String(args?.command ?? args ?? "").includes("git push")
        ) {
          log("info", "[ECC] Remember to review changes before pushing: git diff origin/main...HEAD")
        }
        if (
          hookEnabled("pre:write:doc-file-warning", ["standard", "strict"]) &&
          toolName === "write" &&
          typeof args?.filePath === "string"
        ) {
          const fp: string = args.filePath
          if (
            /\.(md|txt)$/i.test(fp) &&
            !fp.includes("README") &&
            !fp.includes("CHANGELOG") &&
            !fp.includes("LICENSE") &&
            !fp.includes("CONTRIBUTING")
          ) {
            log("warn", `[ECC] Creating ${fp} - consider if this documentation is necessary`)
          }
        }
        if (hookEnabled("pre:bash:tmux-reminder", "strict") && toolName === "bash") {
          const cmd = String(args?.command ?? args ?? "")
          if (
            /^(npm|pnpm|yarn|bun)\s+(install|build|test|run)/.test(cmd) ||
            /^cargo\s+(build|test|run)/.test(cmd) ||
            /^go\s+(build|test|run)/.test(cmd)
          ) {
            log("info", "[ECC] Long-running command detected - consider using background execution")
          }
        }
      })
    } catch (e) {
      log("warn", `[ECC] could not register tool.execute.before: ${String(e)}`)
    }

    // -- tool.execute.after -------------------------------------------------
    try {
      await ctx.tool.hook("execute.after", async (ev: any) => {
        const toolName: string = ev?.tool ?? ev?.name ?? ""
        const args: any = ev?.input ?? ev?.args ?? {}
        const output: unknown = ev?.result ?? ev?.output
        const filePath = getFilePath(args)
        if (toolName === "edit" && filePath) changedFilesStore?.recordChange?.(filePath, "modified")
        if (toolName === "write" && filePath) {
          const key = String(ev?.callID ?? ev?.id ?? `write-${++writeCounter}-${filePath}`)
          const pending = pendingToolChanges.get(key)
          if (pending) {
            changedFilesStore?.recordChange?.(pending.path, pending.type)
            pendingToolChanges.delete(key)
          } else {
            changedFilesStore?.recordChange?.(filePath, "modified")
          }
        }
        if (
          hookEnabled("post:edit:typecheck", ["strict"]) &&
          toolName === "edit" &&
          typeof args?.filePath === "string" &&
          /\.tsx?$/.test(args.filePath)
        ) {
          const base: string = ev?.cwd ?? ev?.directory ?? locationDir
          const { stdout } = await runCapture("npx", ["tsc", "--noEmit"], base)
          if (stdout.trim()) {
            log("warn", "[ECC] TypeScript errors detected:")
            for (const line of stdout.split("\n").slice(0, 5)) log("warn", `  ${line}`)
          } else {
            log("info", "[ECC] TypeScript check passed")
          }
        }
        if (
          hookEnabled("post:bash:pr-created", ["standard", "strict"]) &&
          toolName === "bash" &&
          String(args?.command ?? args ?? "").includes("gh pr create")
        ) {
          log("info", "[ECC] PR created - check GitHub Actions status")
        }
        if (
          hookEnabled("post:skill:track", ["standard", "strict"]) &&
          typeof toolName === "string" &&
          toolName.trim().toLowerCase() === "skill"
        ) {
          try {
            recordSkillRun?.({ tool_name: "Skill", tool_input: args ?? {}, tool_response: output })
          } catch {
            // telemetry is best-effort
          }
        }
      })
    } catch (e) {
      log("warn", `[ECC] could not register tool.execute.after: ${String(e)}`)
    }

    // -- permission.evaluate (was: permission.ask) -----------------------------
    try {
      await ctx.permission.hook("evaluate", async (ev: any) => {
        const action: string = ev?.action ?? ev?.tool ?? ""
        const rawArgs: any = ev?.input ?? ev?.args ?? ev?.metadata ?? ev?.resources
        let cmd = ""
        try {
          if (typeof rawArgs === "string") cmd = rawArgs
          else if (Array.isArray(rawArgs))
            cmd = rawArgs.map((r) => (typeof r === "string" ? r : (r as any)?.command ?? "")).join(" ")
          else if (rawArgs && typeof rawArgs === "object")
            cmd = String((rawArgs as any).command ?? "")
        } catch {
          cmd = ""
        }
        log("info", `[ECC] Permission requested for: ${action}`)
        try {
          if (["read", "glob", "grep", "search", "list"].includes(action)) {
            log("debug", `[ECC] Auto-approved read-only tool: ${action}`)
            ev.effect = "allow"
            return
          }
          const toolName = (ev as any)?.tool ?? action
          if (toolName === "bash" && /^(npx )?(@biomejs\/biome|prettier|black|gofmt|rustfmt|swift-format)/.test(cmd)) {
            log("debug", `[ECC] Auto-approved formatter: ${cmd}`)
            ev.effect = "allow"
            return
          }
          if (toolName === "bash" && /^(npm test|npx vitest|npx jest|pytest|go test|cargo test)/.test(cmd)) {
            log("debug", `[ECC] Auto-approved test execution: ${cmd}`)
            ev.effect = "allow"
            return
          }
          log("debug", `[ECC] Permission requires user approval: ${action}`)
        } catch (error: unknown) {
          const msg = error instanceof Error ? error.message : String(error)
          log("error", `[ECC] Permission handling error for ${action}: ${msg}`)
          ev.effect = "deny"
          ev.message = `Error: ${msg}`
        }
      })
    } catch (e) {
      log("warn", `[ECC] could not register permission.evaluate: ${String(e)}`)
    }

    // -- shell.create.before (was: shell.env) ----------------------------------
    try {
      await ctx.shell.hook("create.before", async (ev: any) => {
        const cwd: string = ev?.cwd ?? locationDir
        const env: Record<string, string> = {
          ECC_VERSION: getECCVersion(eccRoot),
          ECC_PLUGIN: "true",
          ECC_HOOK_PROFILE: currentProfile,
          ECC_DISABLED_HOOKS: process.env.ECC_DISABLED_HOOKS || "",
          PROJECT_ROOT:
            ctx?.location?.project?.directory ?? ctx?.location?.directory ?? cwd,
        }
        const lockfiles: Record<string, string> = {
          "bun.lockb": "bun",
          "pnpm-lock.yaml": "pnpm",
          "yarn.lock": "yarn",
          "package-lock.json": "npm",
        }
        for (const [lockfile, pm] of Object.entries(lockfiles)) {
          if (existsAt(cwd, lockfile)) {
            env.PACKAGE_MANAGER = pm
            break
          }
        }
        const langDetectors: Record<string, string> = {
          "tsconfig.json": "typescript",
          "go.mod": "go",
          "pyproject.toml": "python",
          "Cargo.toml": "rust",
          "Package.swift": "swift",
        }
        const detected: string[] = []
        for (const [file, lang] of Object.entries(langDetectors)) {
          if (existsAt(cwd, file)) detected.push(lang)
        }
        if (detected.length > 0) {
          env.DETECTED_LANGUAGES = detected.join(",")
          env.PRIMARY_LANGUAGE = detected[0]
        }
        const rootAlreadySet = Boolean(
          (process.env.CLAUDE_PLUGIN_ROOT || "").trim() ||
            ((ev?.env as any)?.CLAUDE_PLUGIN_ROOT || "").trim()
        )
        if (eccRoot && !rootAlreadySet) env.CLAUDE_PLUGIN_ROOT = eccRoot
        ev.env = { ...(ev?.env ?? {}), ...env }
      })
    } catch (e) {
      log("warn", `[ECC] could not register shell.create.before: ${String(e)}`)
    }

    // -- custom tools (was: `tool:` key of the v1 return object) ----------------
    try {
      const toolModules: Array<{ file: string; name: string; input: any }> = [
        {
          file: "run-tests",
          name: "run-tests",
          input: {
            type: "object",
            properties: {
              pattern: { type: "string", description: "Test file pattern or specific test name to run" },
              coverage: { type: "boolean", description: "Run with coverage reporting (default: false)" },
              watch: { type: "boolean", description: "Run in watch mode for continuous testing (default: false)" },
              updateSnapshots: { type: "boolean", description: "Update Jest/Vitest snapshots (default: false)" },
            },
            additionalProperties: false,
          },
        },
        {
          file: "check-coverage",
          name: "check-coverage",
          input: {
            type: "object",
            properties: {
              threshold: { type: "number", description: "Minimum coverage percentage required (default: 80)" },
              showUncovered: { type: "boolean", description: "Show list of uncovered files (default: true)" },
              format: { type: "string", enum: ["summary", "detailed", "json"], description: "Output format (default: summary)" },
            },
            additionalProperties: false,
          },
        },
        {
          file: "security-audit",
          name: "security-audit",
          input: {
            type: "object",
            properties: {
              type: { type: "string", enum: ["all", "dependencies", "secrets", "code"], description: "Type of audit to run (default: all)" },
              fix: { type: "boolean", description: "Attempt to auto-fix dependency vulnerabilities (default: false)" },
              severity: { type: "string", enum: ["low", "moderate", "high", "critical"], description: "Minimum severity level to report (default: moderate)" },
            },
            additionalProperties: false,
          },
        },
        {
          file: "format-code",
          name: "format-code",
          input: {
            type: "object",
            properties: {
              filePath: { type: "string", description: "Path to the file to format" },
              formatter: { type: "string", enum: ["biome", "prettier", "black", "gofmt", "rustfmt", "swift-format"], description: "Optional formatter override" },
            },
            required: ["filePath"],
            additionalProperties: false,
          },
        },
        {
          file: "lint-check",
          name: "lint-check",
          input: {
            type: "object",
            properties: {
              target: { type: "string", description: "File or directory to lint (default: current directory)" },
              fix: { type: "boolean", description: "Enable auto-fix mode" },
              linter: { type: "string", enum: ["biome", "eslint", "ruff", "pylint", "golangci-lint"], description: "Optional linter override" },
            },
            additionalProperties: false,
          },
        },
        {
          file: "git-summary",
          name: "git-summary",
          input: {
            type: "object",
            properties: {
              depth: { type: "number", description: "Number of recent commits to include (default: 5)" },
              includeDiff: { type: "boolean", description: "Include diff stats against base branch (default: true)" },
              baseBranch: { type: "string", description: "Base branch for diff comparison (default: main)" },
            },
            additionalProperties: false,
          },
        },
        {
          file: "changed-files",
          name: "changed-files",
          input: {
            type: "object",
            properties: {
              filter: { type: "string", enum: ["all", "added", "modified", "deleted"], description: "Filter by change type (default: all)" },
              format: { type: "string", enum: ["tree", "json"], description: "Output format (default: tree)" },
            },
            additionalProperties: false,
          },
        },
        {
          file: "dependency-analyzer",
          name: "dependency-analyzer",
          input: {
            type: "object",
            properties: {
              type: { type: "string", enum: ["all", "outdated", "security", "unused"], description: "Type of analysis to run (default: all)" },
              fix: { type: "boolean", description: "Attempt to fix issues automatically (default: false)" },
              depth: { type: "number", description: "Depth of dependency analysis (default: 1)" },
            },
            additionalProperties: false,
          },
        },
      ]
      await ctx.tool.transform((editor: any) => {
        for (const t of toolModules) {
          editor.add({
            name: t.name,
            description: `ECC: ${t.name}`,
            input: t.input,
            execute: async (input: any, context: any) => {
              const mod = await import(`../tools/${t.file}.ts`)
              const def = (mod as any).default
              const cwd =
                context?.worktree ?? context?.directory ?? locationDir
              const out = await def.execute(input ?? {}, { directory: cwd, worktree: cwd })
              return typeof out === "string" ? { content: out } : { content: JSON.stringify(out) }
            },
          })
        }
      })
    } catch (e) {
      log("warn", `[ECC] custom tools not registered: ${String(e)}`)
    }

    // -- server events (was: session.*, file.*, todo.* hooks) -------------------
    // Best-effort: matched by historic v1 event-type names. If the v2 server
    // renamed them these handlers are silent no-ops (verified via [ECC] log).
    let aborter: AbortController | undefined
    try {
      if (ctx?.event?.subscribe) {
        aborter = new AbortController()
        const stream = ctx.event.subscribe({ signal: aborter.signal })
        const pump = (async () => {
          try {
            for await (const raw of stream as any) {
              try {
                const type: string = (raw as any)?.type ?? ""
                const data: any = (raw as any)?.properties ?? (raw as any)?.payload ?? (raw as any)?.data ?? raw ?? {}
                if (type === "session.created") {
                  if (!hookEnabled("session:start", ["minimal", "standard", "strict"])) continue
                  log("info", `[ECC] Session started - profile=${currentProfile}`)
                  const base: string = data?.directory ?? data?.project?.directory ?? locationDir
                  if (existsAt(base, "CLAUDE.md")) log("info", "[ECC] Found CLAUDE.md - loading project context")
                } else if (type === "session.deleted") {
                  if (!hookEnabled("session:end-marker", ["minimal", "standard", "strict"])) continue
                  log("info", "[ECC] Session ended - cleaning up")
                  editedFiles.clear()
                  changedFilesStore?.clearChanges?.()
                  pendingToolChanges.clear()
                } else if (type === "session.idle") {
                  if (!hookEnabled("stop:check-console-log", ["minimal", "standard", "strict"])) continue
                  if (editedFiles.size === 0) continue
                  log("info", "[ECC] Session idle - running console.log audit")
                  let total = 0
                  const files: string[] = []
                  for (const f of editedFiles) {
                    if (!/\.(ts|tsx|js|jsx)$/.test(f)) continue
                    const n = countMatchesInFile(f, /console\.log/)
                    if (n > 0) {
                      total += n
                      files.push(f)
                    }
                  }
                  if (total > 0) {
                    log("warn", `[ECC] Audit: ${total} console.log statement(s) in ${files.length} file(s)`)
                    for (const f of files) log("warn", `  - ${f}`)
                    log("warn", "[ECC] Remove console.log statements before committing")
                  } else {
                    log("info", "[ECC] Audit passed: No console.log statements found")
                  }
                  try {
                    if (process.platform === "darwin") {
                      await runCapture("osascript", ["-e", 'display notification "Task completed!" with title "OpenCode ECC"'], locationDir)
                    } else if (process.platform === "win32") {
                      await runCapture("powershell", ["-Command", "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Task completed!', 'OpenCode ECC', 'OK', 'Information')"], locationDir)
                    } else if (process.platform === "linux") {
                      await runCapture("notify-send", ["OpenCode ECC", "Task completed!"], locationDir)
                    }
                  } catch {
                    // notification best-effort
                  }
                  editedFiles.clear()
                } else if (type === "file.edited") {
                  const p: string = data?.path ?? ""
                  if (!p) continue
                  editedFiles.add(p)
                  changedFilesStore?.recordChange?.(p, "modified")
                  if (hookEnabled("post:edit:format", ["strict"]) && /\.(ts|tsx|js|jsx)$/.test(p)) {
                    await runCapture("npx", ["prettier", "--write", p], locationDir)
                    log("info", `[ECC] Formatted: ${p}`)
                  }
                  if (hookEnabled("post:edit:console-warn", ["standard", "strict"]) && /\.(ts|tsx|js|jsx)$/.test(p)) {
                    const n = countMatchesInFile(p, /console\.log/)
                    if (n > 0) log("warn", `[ECC] console.log found in ${p} (${n} occurrence${n > 1 ? "s" : ""})`)
                  }
                } else if (type === "file.watcher.updated") {
                  const p: string = data?.path ?? ""
                  if (!p) continue
                  const t: string = data?.type ?? ""
                  let changeType: "added" | "modified" | "deleted" = "modified"
                  if (t === "create" || t === "add") changeType = "added"
                  else if (t === "delete" || t === "remove") changeType = "deleted"
                  changedFilesStore?.recordChange?.(p, changeType)
                  if (t === "change" && /\.(ts|tsx|js|jsx)$/.test(p)) editedFiles.add(p)
                } else if (type === "todo.updated") {
                  const todos: Array<{ text: string; done: boolean }> = data?.todos ?? []
                  const done = todos.filter((t) => t?.done).length
                  if (todos.length > 0) log("info", `[ECC] Progress: ${done}/${todos.length} tasks completed`)
                }
              } catch {
                // One bad event must never kill the pump.
              }
            }
          } catch {
            // subscribe() ended (abort or server shutdown).
          }
        })()
        void pump
      }
    } catch (e) {
      log("warn", `[ECC] event subscription unavailable: ${String(e)}`)
    }

    log("info", `[ECC] hooks active - profile=${currentProfile} (v2 native port)`)
    if (aborter) return () => aborter!.abort()
  },
}
