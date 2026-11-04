---
name: fg-grade
description: Run golden evals and drive the heal loop to green with evidence. Use after fg-visitor, or to re-verify the suite.
---

# fg-grade — Eval + Heal Loop (`*grade`)

Runs the deterministic eval, heals failures in one turn each, and
lands canon-keyed evidence. Row 4 of the SYS-MCP-001 chat-skills
table.

## Inputs

- A rule id (single-rule loop) or nothing (whole suite).

## Steps

1. Run the eval: CLI `dart run bin/flutterguard.dart grade`
   (repo-local dev loop), or MCP `analyze_ast` over
   `benchmark/vectors/` + `get_telemetry` to audit.
2. On FAIL: MCP `get_canonical_recipe(rule_id)` (or CLI: read the
   spec §2), apply the Before/After patch in ONE turn —
   fast-path mechanical when the strategy is
   `insert_before_invocation`/`replace_invocation` (SYS-HEAL-001),
   model patch otherwise.
3. Re-run the eval. Budget: 3 attempts + snapshot (ForceField §3);
   on exhaustion roll back and emit the diagnostic report with the
   Attack-the-Premise prompt — never burn attempts on a dead premise.
4. Confirm `evidence.jsonl` appended exactly the 9 canon keys
   (SYS-TELE-001), one line per vector.

## MCP tools / CLI fallback

- MCP: `analyze_ast`, `get_canonical_recipe`, `get_telemetry`.
- CLI: `grade`, `check`.

## Done criteria

- `grade` exits 0; every vector PASS with gate-correct status
  (`.bad` → FAILED/caught, `.good` → PASSED/clean).
