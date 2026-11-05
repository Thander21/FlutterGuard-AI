---
name: fg-use
description: Daily FlutterGuard loop in a target project (check, heal via recipe, re-check, escalate). Use after any Dart/Flutter edit.
---

# fg-use — Daily Use Loop (`*use`)

Runs the deterministic gate loop in a target project via MCP (CLI
fallback) until clean. Assumes the official setup: global install +
`flutterguard init --mcp` (tools) + pre-commit hook (enforcement).

## Inputs

- A target path (file or directory), default `.`.

## Steps

1. Run the gate: MCP `analyze_ast` over the target (CLI fallback:
   `flutterguard check <path>`).
2. On findings: MCP `get_canonical_recipe(rule_id)` per error-severity
   finding (CLI: read the spec §2 via the finding's `recipe` field),
   apply the Before/After patch in one turn.
3. Re-run the gate until `PASSED` (warnings-only is clean).
4. Escalate on demand: `run_mutation_check` for suspect tests,
   `verify_viewport` for layout edits (lite: `PASS` never claims
   rendered-clean), `get_telemetry` to audit recent evidence.
5. Never finish with error-severity findings open; the pre-commit
   hook blocks the commit regardless.

## MCP tools / CLI fallback

- MCP: `analyze_ast`, `get_canonical_recipe`, `verify_viewport`,
  `run_mutation_check`, `get_telemetry`.
- CLI: `check` (plus `--json` for machine-readable findings).

## Done criteria

- Gate `PASSED` (zero error-severity findings) on the target.
