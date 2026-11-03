---
spec_version: "openspec-1.0"
id: "SYS-HEAL-001"
title: "Heal dispatcher: fast-path patches with rollback"
status: "approved"
kind: "system"
---

# 1. Problem

Detection without healing leaves every fix to chance. This contract defines
the dispatcher that turns a flagged violation plus its canonical recipe into
a verified patch — or a clean rollback with a human-readable diagnosis.
Highest-risk fork: what the harness does mechanically vs what stays with
the agent (model).

Agent-vs-harness boundary (traced from ForceField §3, Architecture §2.5,
ClientAgents gates):

| Duty | Owner |
|---|---|
| Structured-error capture, snapshot, retry loop (cap 3), rollback, diagnostic report, evidence | Harness |
| Fast-path mechanical patches (closed list in §2) | Harness |
| Semantic patches, multi-hunk refactors, ambiguous anchors | Agent (model) |
| Premise redefinition after repeated same-gate failures (Attack-the-Premise reflection) | Agent, triggered by the harness report |
| Commits | Human only — never the agent, never the harness |

Rule: the harness never invents code beyond the recipe; the agent never
edits during a harness fast-path run.

# 2. Interface / Schema

`HealDispatcher.healFile({path, recipe, analyze, maxAttempts = 3})` →
`HealResult(success, attempts, rolledBack, errors, report)`.

`HealRecipe`: rule id + strategy + payload. Strategy semantics (decided
here; values were declarative-only per REVIEW-01 finding 10):

- `insert_before_invocation {guard}`: insert `<indent>guard` immediately
  above the violation's 1-based line; indent copied from the anchor line.
  No-op (recorded, stops the run) when that exact line already sits above.
- `replace_invocation {from, to}`: replace the first occurrence of `from`
  with `to` on the violation's line. No-op (recorded, stops) when `from`
  is absent.

Fast-path classification (closed mechanical list):

| Fix | Class | Rationale |
|---|---|---|
| single-line guard insert (`isClosed`, `mounted`) | mechanical | anchor known, one hunk |
| single-token swap (`watch` → `read`) | mechanical | one line, no judgment |
| `const` / key insertion | mechanical (future, no spec yet) | same shape |
| multi-hunk (`hoist_to_init_state`: field + `initState` + `dispose` + use) | model | spans methods |
| ambiguous anchor / overlapping edits | model | needs judgment |
| anything unlisted | model | closed list |

Retry: cap 3 (ForceField). Each attempt heals the first remaining
violation, then re-verifies. A no-op patch means the premise is exhausted:
stop without burning the cap, roll back, and carry the Attack-the-Premise
prompt in the report.

Structured-error capture (JSON shape, mirrored in the report):
`{attempt, phase: detect|patch|verify, target, rule_id, error}`.

Diagnostic report (markdown, written to `<target>.heal-report.md` on
rollback only): run time, target, rule/strategy, attempts used of cap,
per-attempt error table, snapshot-restored confirmation, Attack-the-Premise
prompt block, no-auto-commit note.

# 3. File Placement

- `specs/system/SYS-HEAL-001-heal-dispatcher.md` (this contract).
- `lib/src/heal/dispatcher.dart` (dispatcher; new dir — no Architecture §4
  slot precedes MCP/tool wiring), exported from `lib/flutterguard_ai.dart`.
- `test/heal_dispatcher_test.dart` (red→patch→green on BLOC-001 and RIV
  fixtures; cap + rollback + report on persistent failure).
- Recipe lookup by rule id from spec §2 is the production wiring (jointly
  with SYS-RECIPE-001); this contract takes the recipe as input.

# 4. Evidence Wiring

The dispatcher emits no `evidence.jsonl` itself. `HealResult` feeds future
CLI wiring (heal iterations → `iteration` > 1 lines, recipe id →
`recipe_injected` per SYS-TELE-001). The `.heal-report.md` file is human
diagnostics, not evidence.

# 5. Errors and Edges

- Detect crash: recorded, immediate rollback + report, no patch attempted.
- Patch no-op: premise exhausted → stop, rollback, report (cap not burned).
- Verify still red after a real patch: next attempt, up to the cap.
- Cap exhausted: rollback via in-memory snapshot restore; run-level
  `git restore` is owned by CLI/hook wiring (Architecture §2.5).
- Already-green input: success, attempts = 1, zero writes, empty report.
- Current API heals one file per call; multi-file runs snapshot each
  touched file (future).

# 6. Contradictions Resolved

- Heal budget: ForceField (3 attempts + snapshot + Attack-the-Premise)
  wins; ProjectOverview's "1–2 turns" is stale.
- Rollback: in-run snapshot restore (implemented here) + run-level
  `git restore` (CLI/hook wiring) — two layers, reconciled per PLAN-02.
- `auto_heal_strategy` values gain the §2 semantics (were declarative).
