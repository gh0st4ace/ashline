/**
 * Inert entry plugin (OpenCode v2 native shape).
 *
 * OpenCode auto-loads every file in this directory AND the `./plugins`
 * directory entry from opencode.json. The real ECC hooks live in
 * ecc-hooks.ts — this barrel intentionally registers nothing so hooks
 * are never initialized twice. It must still be a valid v2 definition
 * (`{ id, setup }`), otherwise the loader marks it failed (red in TUI).
 */
export default {
  id: "ecc-entry",
  setup() {
    // Intentionally empty: ecc-hooks.ts owns all hooks and tools.
  },
}
