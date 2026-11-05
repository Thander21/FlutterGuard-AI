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

## Thin CLI (`heal`, Wave 2, SYS-VAL-001 F6)

`flutterguard heal <file.dart> --rule <RULE-ID> [--attempts N]
[--json] [--help]` — a thin wrapper: resolves rule → recipe →
analyzer, runs one `HealDispatcher.healFile`, prints the outcome.
Zero heal logic in the CLI layer.

- Target: exactly one existing `.dart` file (directories, missing
  paths, and non-Dart files exit 2 — the dispatcher heals one file
  per call).
- `--rule` (required): must name a registry rule with a fast-path
  recipe (`FG-BLOC-001`, `FG-RIV-001`, `FG-ASYNC-002`). Unknown id →
  exit 2; known-but-mechanical-less rule → exit 2 with the spec §2
  pointer (agent-dispatched). Strict ids, no case normalization.
- Missing `--rule`: guided exit — lists the target's mechanical
  violations and re-prompts for `--rule` (exit 2), or reports clean
  and exits 0 when none exist.
- `--attempts` (default 3, ForceField cap): override in 1..10;
  anything else exits 2. Above 10 is a runaway budget, refused.
- Exit codes: 0 healed (including already-green, zero writes);
  1 rolled back (violations remain; report at `<file>.heal-report.md`);
  2 bad arguments / unknown or non-mechanical rule.
- Text output: one summary line (`healed:` / `clean:` /
  `rolled back:` with rule, attempts, report path) plus one line per
  recorded error on rollback. Errors and usage go to stderr.
- `--json`: prints the result object (`success`, `attempts`,
  `rolled_back`, `rule_id`, `target`, `errors` in `HealError` shape,
  `report`); exit codes unchanged.

# 3. File Placement

- `specs/system/SYS-HEAL-001-heal-dispatcher.md` (this contract).
- `lib/src/heal/dispatcher.dart` (dispatcher; new dir — no Architecture §4
  slot precedes MCP/tool wiring), exported from `lib/flutterguard_ai.dart`.
- `test/heal_dispatcher_test.dart` (red→patch→green on BLOC-001 and RIV
  fixtures; cap + rollback + report on persistent failure).
- Recipe lookup by rule id from spec §2 is the production wiring (jointly
  with SYS-RECIPE-001); this contract takes the recipe as input.
- Thin CLI (Wave 2): `lib/src/cli/heal.dart` (arg parsing, registry +
  recipe lookup, outcome printing; exported from
  `lib/flutterguard_ai.dart`), `heal` branch in `bin/flutterguard.dart`,
  `test/heal_cli_test.dart` (exit codes, red→green per fast-path rule,
  rollback + report, guided no-rule behavior, JSON map).

# 4. Evidence Wiring

The dispatcher emits no `evidence.jsonl` itself. The v1 CLI reports on
stdout only and emits no lines either: a HEAL producer needs
`phase`/`action` values the canon does not have, so emission waits
for a SYS-TELE-001 amendment (canon rule §4) — until then the
inert-keys rule (TELE-001 §5) holds. `HealResult` still feeds that
future wiring (`iteration` > 1, `recipe_injected`). The
`.heal-report.md` file is human diagnostics, not evidence.

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
- CLI-vs-lib boundary (Wave 2): the CLI resolves, runs, and prints —
  all patch/verify/rollback logic stays in `HealDispatcher`
  (SYS-VAL-001 F6). Needed lib additions land in `lib/src/heal/`;
  v1 needed none (public fields + `HealError.toJson` suffice).
- Evidence now vs later (Wave 2): stdout-report now wins over
  emission — coining `phase`/`action` values without a consumer is
  canon churn; the amendment lands with the first real HEAL
  consumer.
