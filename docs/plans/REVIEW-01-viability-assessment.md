---
review_version: "1.0"
id: "REVIEW-01"
title: "Plan review and viability assessment"
status: "recorded"
date: "2026-10-31"
source_method: "4 discovery agents + 5-judge panel + synthesis (evidence-based, file+line refs)"
---

# REVIEW-01: Plan Review and Viability Assessment

## 1. Method

A panel of 5 judges plus discovery agents inspected the repository bodies
(`docs/`, `specs/`, `lib/`, `bin/`, `test/`, `benchmark/`) and answered four
questions. Viability was judged on the project idea (deterministic local
quality harness for Flutter/Dart); hackathon rules were excluded from the
viability verdict and recorded separately in §6. Every claim below carries
its evidence location. The panel worked by static inspection only; the
runtime verification in §5 was performed during implementation on the same
date.

## 2. Verdicts

### (1) Can the project evaluate code as envisioned? PARTIALLY VIABLE

The core is technically sound and demonstrated: local parse-only AST gates
plus the golden harness (`specs/` → `benchmark/vectors/` → visitors →
`test/` → `grade`) correctly flag the `.bad` vectors and spare the `.good`
ones for both shipped rules (`FG-BLOC-001` in
`lib/src/ast/bloc_emit_guard.dart`, `FG-RIV-001` in
`lib/src/ast/riverpod_watch_guard.dart`).

The "formal proofs of whole bug classes + fail-closed blocking metrics"
layer must be re-evaluated: `parseString` without type resolution cannot
sustain interprocedural typestate/liveness (`FG-FORMAL-001`), forward
slicing with `RebuildWasteIndex > 0.80` (`FG-FORMAL-003`), restartable /
request-id detection (`FG-FORMAL-004`), whole-program single-implementation
checks, or CRAP (needs coverage). Thresholds (`CRAP >= 10`, dryer `0.8`,
depth 5, `> 7` params, tap `< 48dp`, ratio `15%`) are uncalibrated, with no
baseline or precision/recall measured. Layout collapse (`FG-FORMAL-002`)
depends on runtime sizes; the primary detector must be the Tier-1 runtime
interception of `RenderFlex overflowed`, with the static check as a
heuristic aid.

### (2) Does the plan cover all raised points? INCOMPLETE

`PLAN-01` + `PLAN-02` cover the deterministic loop (P0–P2) in real depth,
but the hardest differentiators stay as spike/deferred without
implementable criteria: stale search race, rebuild budget, main-isolate
starve, retained closures, semantic ratio, Tier-2 visual details, and
sealed-class/FSM enforcement. `PLAN-01` non-goals (MCP, CRAP/dryer, provers)
are reopened by `PLAN-02` P2/P3 with no recorded reconciliation, and six of
the ten benchmark bugs have no practical gate.

### (3) Is the harness functional and integrated, or plan-only? PARTIAL

The v0 harness is functional and integrated for 2 rules: spec contracts
(`specs/TS-01`, `TS-02`), golden pairs (`TC-01`, `TC-02`), visitors, unit
tests, and the `grade` CLI are fully wired. Everything else documented —
`check`/`init`, hooks, `validate-light`/`validate`/`commit-check`, CI,
Tier-1/2 visual, mutation, MCP, auto-heal, CRAP/dryer, sandbox — was
plan-only at review time. (`check` was implemented during the follow-up;
see §5.)

### (4) Is the documentation clear? PARTIAL

The v0 loop (spec → vectors → visitor → test → grade) is clear and
executable. The rest mixes implemented with planned without signaling, and
carries unresolved contradictions on the reader's path: README promises
(`init --mcp`, MCP server, hooks) with no code; evidence schema divergence
(`GOLDEN_EVAL` vs `DETERMINISTIC_GATE`); heal budget (2 turns + `git
restore` vs 3 attempts + snapshot); `TS-01` "BlocBase" vs a `Cubit`/`Bloc`
visitor; `TS-02` triple scope; `auto_heal_strategy` without semantics.

## 3. Technical points raised

1. `TS-01` invariant said "BlocBase subclass"; the visitor accepts only
   `Cubit`/`Bloc` by superclass name (fixed: spec now matches the visitor).
2. `TS-01` overpromised `try`-block guards and helper-call tracing; v0
   tracks top-level statements only (fixed: documented as v0 limits).
3. `TS-02` never defined "synchronous build path" and the visitor flags
   any argument callback (fixed: term defined, scope aligned, `.map`
   limitation documented).
4. `grade` emitted `phase GOLDEN_EVAL` / `action EVAL_RECORDED` /
   `recipe_injected ''` while docs required `DETERMINISTIC_GATE` /
   `AUTO_HEALING_DISPATCHED` / recipe (fixed: one schema, `DETERMINISTIC_GATE`
   phase; `EVAL_RECORDED` for evals, heal action reserved for dispatch lines).
5. Heal budget contradicted across docs (fixed: 3 attempts + snapshot +
   Attack-the-Premise, rollback via `git restore`, per ForceField §3).
6. No `check` command existed though the Blueprint mandates `check --json`
   (fixed: implemented over the shared rule registry, text + JSON).
7. The baseline was red: both visitors failed to compile (`LineInfo`
   unresolved, analyzer 6.4.1 needs `package:analyzer/source/line_info.dart`)
   — found during implementation, fixed, tests green.
8. Exit codes: the local `dart.bat` launcher swallows `main`'s return code
   (probe: `return 3` observed as 0); the CLI now calls `exit()` explicitly
   (verified: 0 clean, 1 violations, 2 usage).
9. Thresholds and latency claims (`< 40ms`, `microssegundos`, `0 tokens`)
   have no measurements; each blocking threshold needs calibration on a
   real Dart/Flutter corpus with published precision/recall first.
10. `auto_heal_strategy` values (`insert_before_invocation`,
    `replace_invocation`) have no consumer; semantics deferred to a future
    heal-dispatcher spec.
11. Golden tests cover only one pair per rule; spec §3 edges (try blocks,
    helpers, nested closures, tear-offs) have no tests.
12. No CI, no install scripts, no committed `evidence.jsonl` existed at
    review time (first green `evidence.jsonl` generated during
    implementation: 4/4 evals PASS).

## 4. Recommended scope (v0 freeze)

Keep the validated EDD methodology; cut the scope so the project fulfills
its real role — a fast, local, auditable deterministic gate:

- Ship: 2 AST rules + `grade` + `check`, golden harness, canonical
  Before/After recipes in specs.
- Blocking gates: high-precision local rules + Tier-1 runtime only.
- Advisory (baseline per repo, auditable suppression): whole-program
  analysis and all metrics.
- Reframe "formal provers" as "detectors" in documentation.
- Cut from the graded path: MCP server, mutation runner, viewport gates,
  CRAP/dryer, formal provers, playground, `init`/hooks.
- Migrate visitors to resolved AST before claiming broader coverage.

## 5. Implementation and verification status

The frozen scope was implemented and verified on 2026-10-31 (separate
working-tree change): `dart test` 7/7 green, `dart analyze` clean on
`lib`/`bin`/`test` (35 remaining issues are pre-existing, vectors-only,
unresolved Flutter imports by parse-only design), `grade` 4/4 PASS exit 0
with `evidence.jsonl` appended, `check` exit codes verified
(1/0/2 + `--json`).

## 6. Hackathon-compliance notes (excluded from the viability verdict)

Recorded because discovery surfaced them, not as viability judgments:
Stage-One Meta-API usage had no owner in the submission plan; the video
script was anchored at 120s against an official 3-minute rule;
`SEU-USER`/`YOUR-USER` placeholders remain; Meta endpoints, credits, and
the LinkedIn/story artifacts are unverified or ownerless.

## 7. Open gaps

- Runtime behavior of gates beyond the golden pairs (precision/recall).
- Threshold calibration corpus and measurements.
- Resolved-AST migration design.
- Meta API endpoints/authentication and credit claim.
- CI wiring and install path.
