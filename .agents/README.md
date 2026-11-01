# Agent Config (`.agents/`)

Project-local Muse configuration. Layout verified against
`muse init --dry-run` and `muse skills --help`:

- `../AGENTS.md` — project rules. Muse reads that file as the rules
  entry; there is no loadable rules directory. Never run
  `muse init --force` here: it would overwrite the curated root file
  with a generic template.
- `skills/` — project skills (`<name>/SKILL.md`). Discovered via
  `muse skills list --source project`; validate new skills with
  `muse skills validate <path>`.
- `workflows/` — saved workflow scripts (`<name>.js`), loadable by name.
- `metaai/` — Meta AI stack dossier (Spark, Code, SAM, Image/Vision,
  Llama Stack). Start at `metaai/Readme.md`; the quick
  which-model-where map lives in `../AGENTS.md`.

Deliberately absent:

- `rules/` — the loader reads `AGENTS.md`, not a directory.
- `plans/` — this repo keeps plans in `docs/plans/`.
- `memories/` — memory scopes are tool-managed, not repo files.

Keep this index accurate when the layout changes.
