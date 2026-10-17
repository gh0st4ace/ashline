# ECC v2 plugin shim — зачем эта папка

Апстрим ECC 2.2.3 (`D:\opencode\ecc`, `.opencode/plugins/`) поставляет плагины
в v1-формате (функция `(input: PluginInput) => hooks`). OpenCode >= 2.x такой
формат отклоняет: `Plugin must export a default definition with an id and an
effect or setup function` — плагины красные в TUI.

Здесь лежат v2-нативные замены (формат `{ id, setup() }`, без внешних
импортов — только node builtins + соседние модули ECC):

- `ecc-hooks.ts` — порт 1:1: tool.execute.before/after, permission.evaluate
  (авто-аппрув read-only/форматтеров/тестов), shell.create.before (env:
  ECC_VERSION/PROJECT_ROOT/CLAUDE_PLUGIN_ROOT/...), 8 кастомных тулзов
  (run-tests, check-coverage, security-audit, format-code, lint-check,
  git-summary, changed-files, dependency-analyzer), best-effort подписка на
  session/file/todo-события. Выпало только `experimental.session.compacting`
  (в v2 нет API дописать контекст — только заменить саммари).
- `index.ts` — инертная заглушка `{ id: "ecc-entry", setup(){} }`, чтобы баррель
  не инициализировал хуки дважды и был зелёным.

Применение: `D:\opencode\update-ecc.ps1` копирует эти файлы поверх
`~/.config/opencode/plugins/` после каждой переустановки ECC (иначе апстрим
вернёт v1-файлы и плагины снова покраснеют). Ручное применение: скопировать
оба файла в `%USERPROFILE%\.config\opencode\plugins\`, сервер подхватит сам.

Связанное: удаление легаси-ключа `"plugin": ["./plugins"]` из opencode.json
(делает тот же update-ecc.ps1) — ключ дублирует файловый автодискавери v2,
`index.ts` грузился дважды и второй инстанс падал с дублирующимся id.
