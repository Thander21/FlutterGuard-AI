# Project Skills

Project-local Muse skills live here, one directory per skill:

```text
skills/<name>/SKILL.md
```

Lifecycle commands:

- `muse skills list --source project` — show discovered project skills.
- `muse skills validate <path>` — validate a skill directory.
- `muse skills install <path> --scope user` — promote a skill to the
  personal root (`~/.agents/skills/`).

Keep this directory free of non-skill files (this README excepted) so
discovery stays clean.
