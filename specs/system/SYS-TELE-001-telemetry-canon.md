---
spec_version: "openspec-1.0"
id: "SYS-TELE-001"
title: "Telemetry canon for evidence.jsonl"
status: "approved"
kind: "system"
---

# 1. Problem

Every gate (grade today; heal, MCP, runners later) appends telemetry to
`evidence.jsonl`. Without a fixed key table, producers drift (renamed keys,
missing fields) and consumers break. This contract freezes the exact keys,
order, types, and semantics every line must carry.

# 2. Interface / Schema

`evidence.jsonl`: UTF-8, one JSON object per line, appended only, trailing
newline. Keys in emission order:

| # | key | type | semantics |
|---|-----|------|-----------|
| 1 | timestamp | string | UTC ISO-8601 of the eval moment |
| 2 | phase | string | gate phase; today always `DETERMINISTIC_GATE` |
| 3 | rule_id | string | spec id graded (e.g. `FG-BLOC-001`) |
| 4 | file | string | graded vector path as declared in the spec, resolved against the grade root |
| 5 | status | string | gate verdict: `FAILED` when the visitor flagged, `PASSED` when clean |
| 6 | error_message | string | first violation message, or `""` when clean |
| 7 | recipe_injected | string | heal recipe id injected; `""` until SYS-HEAL-001 populates it |
| 8 | iteration | int | heal attempt number; `1` until the heal loop increments it |
| 9 | action | string | `EVAL_RECORDED` for grade evals |

Gate semantics read inverted from intuition: a `.bad` vector that IS flagged
records `FAILED` (the gate caught a violation); a `.good` vector that stays
clean records `PASSED`.

No new dependencies.

# 3. File Placement

- `specs/system/SYS-TELE-001-telemetry-canon.md` (this contract; the grader
  skips `specs/system/` non-recursively and `kind: system` explicitly).
- `evidence.jsonl` (repo root; append-only telemetry log).
- Producer: `grade()` in `bin/flutterguard.dart` (`_gradeVector` builds the
  line).
- Contract test: `test/telemetry_canon_test.dart` (a fixture grade run
  asserts the exact keys).

# 4. Evidence Wiring

`grade()` collects one line per graded vector and appends once per run
(never per-vector streaming, never rewrite). Future producers (SYS-HEAL-001
iterations, SYS-MCP-001 tool calls) MUST reuse these keys and amend this
spec before adding any.

# 5. Errors and Edges

- Zero parseable rule specs: no lines appended, exit 1 ("No rule specs
  found").
- Malformed spec / missing visitor: recorded on stderr only, no evidence
  line (nothing attributable ran); the run continues, exit 1.
- Analyzer crash on a vector: the line IS appended with status `FAILED` and
  `error_message` "analyzer crashed on this file" (fail-closed eval).
- `recipe_injected` / `iteration` are inert today (`""` / `1`); any other
  value before SYS-HEAL-001 lands is a contract violation.

# 6. Contradictions Resolved

- Evidence schema: Architecture §5
  (`timestamp`/`phase`/`rule_id`/`file`/`status`/`error_message`/
  `recipe_injected`/`iteration`/`action`) wins — implemented. The
  `stage`/`test_file`/`result` variant in SpecDrivenDevelopment §3 is
  superseded.
