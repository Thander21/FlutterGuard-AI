---
spec_version: "openspec-1.0"
id: "SYS-CLI-001b"
title: "init, pre-commit hook, and sandbox"
status: "approved"
kind: "system"
---

# 1. Problem

A gate nobody installs audits nothing. This contract pins project
onboarding (`init`), the commit-blocking hook, and the volatile agent
playground (`sandbox`), with the pollution budget enforced: `init` never
writes tracked files by default — `.flutterguard/` and agent-file writes
require explicit flags.

# 2. Interface / Schema

`init [--scaffold] [--agents] [--mcp] [--no-hook]
[--hook-command=<cmd>] [--help]` (parsed with `package:args`):
hook install + `flutterguard.yaml` + mandate print by default;
`--scaffold` also creates `.flutterguard/`; `--agents` also appends the
mandate to `AGENTS.md` (default prints it); `--no-hook` skips the
hook (hook-owned repos: only `flutterguard.yaml` lands);
`--hook-command=<cmd>` writes a delegating hook that execs the
project's own gate command verbatim. Exit 0 when every
applicable step lands, 1 when a step fails, 2 on bad arguments.
`init --mcp` registers IDE clients per SYS-MCP-001 §2.

Pre-commit hook (`.git/hooks/pre-commit`, marker
`# FlutterGuard pre-commit hook (SYS-CLI-001b)`):

```sh
#!/bin/sh
# FlutterGuard pre-commit hook (SYS-CLI-001b): blocks commits with violations.
# Override the CLI checkout for tests and custom installs:
# FLUTTERGUARD_ROOT="/path/to/flutterguard-ai" (quoted: spaces safe).
if [ -n "$FLUTTERGUARD_ROOT" ]; then
  exec dart run "$FLUTTERGUARD_ROOT/bin/flutterguard.dart" check .
elif command -v flutterguard >/dev/null 2>&1; then
  exec flutterguard check .
else
  exec dart run bin/flutterguard.dart check .
fi
```

A `--hook-command` install writes the delegating variant instead
(same marker guard; reinstall idempotent):

```sh
#!/bin/sh
# FlutterGuard pre-commit hook (SYS-CLI-001b): delegates to the project's own gate.
exec <cmd, verbatim>
```

The hook runs `check`, never `grade` (PLAN-01 Phase 2, PLAN-03). Exit 1
blocks the commit; humans commit (no-auto-commit, ForceField principle 3).
`chmod +x` is applied best-effort (needed on Unix; no-op where `chmod`
is unavailable).

`sandbox <load|reset|check>` over `fixtures/sandbox/` (volatile,
gitignored; vectors stay pristine — only copies enter):

- `load`: wipe + copy `benchmark/vectors/*.bad.dart` in. Exit 1 when the
  vectors source is missing.
- `reset`: wipe the sandbox.
- `check`: run `check` over the sandbox; exit follows `check` (1 =
  violations present, the expected state right after `load`).

`flutterguard.yaml` schema v1 (written once, never overwritten):

```yaml
version: 1
gates:
  validate-light: true
  test: true
  validate: true
  commit-check: true
```

Toggles are declared here; enforcement lands with the gate runner.
Unknown keys are ignored for forward compatibility.

Agent mandate (printed by default; appended to `AGENTS.md` only with
`--agents`, marker-guarded and idempotent):

```markdown
<!-- FLUTTERGUARD MCP HARNESS CONTRACT -->
## FlutterGuard engineering contract
1. After editing Dart/Flutter code, run the static gate (`check`); never ignore findings.
2. If the gate fails, apply the spec §2 canonical recipe for the flagged rule id.
3. No task is done while `check` reports violations.
```

Client-specific files (`CLAUDE.md`, `GEMINI.md`) and `init --mcp`
registration belong to SYS-MCP-001. Global install has two methods:
`dart install '<pkg>@{git:{url:...}}'` (primary, PLAN-01 Phase 4) and
`dart pub global activate --source git` (fallback for SDKs without
`dart install`). `install.sh` / `install.ps1` (root, one-liner global
install from the git URL) try the primary and fall back automatically;
both verify with `flutterguard check --help`. The `executables` stanza
and the live install proof stay in distribution (PLAN-03 U2); the
proof record lives in §6.

# 3. File Placement

- `bin/flutterguard.dart` `init()` / `sandbox()` (thin CLI).
- `test/init_test.dart` (init steps, flags, clobber guards, sandbox
  cycle, install scripts, scratch-clone hook block).
- Generated: `.git/hooks/pre-commit` (default or `--hook-command`
  delegating; skipped with `--no-hook`), `flutterguard.yaml`,
  `.flutterguard/` (opt-in), `AGENTS.md` (opt-in),
  `fixtures/sandbox/` (volatile).
- `install.sh`, `install.ps1` at root.

# 4. Evidence Wiring

`init`, the hook, and `sandbox` emit no `evidence.jsonl`. The hook
executes `check`, which is read-only by SYS-CLI-001a.

# 5. Errors and Edges

- No `.git/hooks` (not a repo): hook skipped with an error message,
  exit 1; yaml/scaffold steps still land.
- Foreign hook (exists without the marker): refused, never overwritten,
  exit 1. Ours: reinstall is idempotent.
- `--no-hook` with `--hook-command`, or an empty `--hook-command`:
  usage error, exit 2 (nothing is written).
- Hook infrastructure failure (CLI missing or crashing) aborts the commit
  — fail-closed; fix the install, never bypass.
- Existing `flutterguard.yaml`: left untouched, never overwritten.
- `AGENTS.md` already carrying the marker: skipped (idempotent).
- `sandbox load` with no vectors source: exit 1. `sandbox check` on a
  missing sandbox: exit 2 via `check`.
- `--mcp`: registers IDE clients per SYS-MCP-001 §2 (shipped in P3;
  formerly reserved). Registration errors fail the run (exit 1);
  unwritable/out-of-root clients are never attempted.

# 6. Contradictions Resolved

- Hook runs `check`, not `grade` (grade-vs-check doctrine, PLAN-03).
- Pollution budget (Architecture §3.1): default `init` writes only the
  hook (untracked, in `.git/`) and `flutterguard.yaml`; `.flutterguard/`
  and `AGENTS.md` need `--scaffold` / `--agents`. `--no-hook`
  writes `flutterguard.yaml` alone (SYS-CAL-002 P2-1).
- Playground resolution (PLAN-02 SYS-MUT-001): `vectors/` = golden evals
  (read-only source), `fixtures/` = agent playground (volatile copies).
- Live install proof (2026-11-04, SDK 3.13.7, post-push): the primary
  `dart install 'flutterguard_ai@{git: {url: <repo>}}'` (spaced
  descriptor — the compact `{git:{url:...}}` form fails to parse)
  installed both exes; `flutterguard check` flagged a fresh BLOC-001
  file from a foreign directory (exit 1) and `flutterguard_mcp`
  answered `initialize` with `serverInfo flutterguard/0.1.0`. The
  `pub global activate --source git` fallback was verified the same
  way under an isolated `PUB_CACHE` (`dart install` ignores
  `PUB_CACHE` and targets `<user>/AppData/Local/Dart/install/`).
  All install artifacts were uninstalled after verification
  (`dart uninstall flutterguard_ai`).
