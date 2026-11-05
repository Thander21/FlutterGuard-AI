---
plan_version: "2.0"
id: "PLAN-01"
title: "Full implementation plan to production use"
status: "complete"
source_docs:
  - "docs/_origem/Architecture.md"
  - "docs/_origem/FormalVerificationAlgorithms.md"
  - "docs/_origem/ProjectOverview.md"
  - "docs/_origem/DisruptiveInnovations.md"
  - "docs/_origem/SddEddWorkflow.md"
  - "docs/_origem/SpecDrivenDevelopment.md"
  - "docs/_origem/ForceFieldHarness.md"
  - "docs/_origem/CleanCodeDeterministicGates.md"
  - "docs/_origem/CanonicalRecipesCatalog.md"
  - "docs/_origem/ClientAgentsTracking.md"
  - "docs/plans/PLAN-02-functional-scope-to-working-system.md"
  - "docs/plans/REVIEW-01-viability-assessment.md"
---

# PLAN-01: Full Implementation Plan to Production Use

> **Status: complete** — all phases delivered and verified 2026-11-04;
> traceability in `docs/plans/AUDIT-01-traceability.md`.

## Goal

Ship a complete, production-usable FlutterGuard AI: a deterministic Dart AST
core with golden evals, a full CLI (`check`, `init`, pre-commit hook), an
auto-heal loop, dynamic gates (mutation + Tier-1 viewport), an MCP server,
and installable distribution. No hackathon deadline applies (missed; dropped
from scope) — delivery is ordered by dependency (Step 0 → P0 → P1 → P2 →
P3), not by date.

## Success Criteria

- `dart test` passes for every rule visitor (zero false positives on `.good`).
- `dart run bin/flutterguard.dart grade` exits 0 and appends canon-keyed
  `evidence.jsonl`.
- `flutterguard check` audits a target directory and reports violations as JSON.
- `flutterguard init` scaffolds `.flutterguard/` and installs the pre-commit
  hook; the hook blocks planted violations.
- Heal loop: fixture red → patch → green within budget, rollback on failure
  with a diagnostic report.
- Mutation gate catches a planted complacent test; honest tests pass.
- Tier-1 viewport: `flutter test` red on `.bad` layout, green after fix
  (Flutter SDK verified present).
- MCP server: stdio smoke test green per tool; `init --mcp` registers clients.
- Install from the git URL works; `flutterguard check` runs from a foreign
  directory.
- Tier-2 (SAM/Vision) verdict recorded: built if endpoints verify, otherwise
  explicitly deferred with Tier-1 standing.

## Doc Validation Decisions

Docs were read as a starting point, not truth. Binding resolutions:

- Single-package layout wins (`Architecture.md` §4); the `packages/...` path
  in `SddEddWorkflow.md` was stale and is now fixed.
- `evidence.jsonl` follows the `Architecture.md` schema (implemented); the
  `stage/test_file/result` variant in `SpecDrivenDevelopment.md` is superseded.
- CLI surface follows `Architecture.md` §3–§5 (`flutterguard init` with
  opt-in `.flutterguard/` + pre-commit hook and pollution budget, §3.1;
  `check` as the portable AST gate sibling of repo-local `grade`,
  `bin/flutterguard.dart`, §4; `--json` output shaped by the
  `evidence.jsonl` schema, §5); `fg run`, `bin/ast_guardian.dart`,
  `flutterguard analyze` (folded into `check`), and `crap`/`dryer`
  command names are superseded.
- Hackathon scope dropped: deadline missed, `docs/_rulesHackathon/` is not
  consulted, and submission artifacts (texts, demo script, scoring
  checklist) are deleted from scope, not deferred.
- REVIEW-01 §4 cuts are superseded by the full-product direction: `init` +
  hook, P2/P3 builds, and MCP are all scheduled (the review itself stays
  frozen as a historical record).
- Gates follow `ForceFieldHarness.md` (light → test → full → commit-check),
  mapped onto the tiered runner: parse-only AST first, resolved/compiled
  checks later.
- New docs and code stay in English per `AGENTS.md`; old Portuguese docs are
  kept as-is, no rewrite.
- `FG-FORMAL-001..005` (DFA/CFG provers) are research-grade: each decomposes
  into EDD rule specs or drops with a recorded reason; none builds as
  documented.
- Meta endpoints (SAM 3.1, Muse Image, Llama Stack) are unverified; Tier 2
  builds only after endpoint verification. Tier 1 native gates must work
  standalone regardless.
- Repo URL placeholders are replaced with the real URL at release time.
- Rule contracts live in `specs/` (normative, grader-read); `docs/` is the
  thinking repository (prose, plans, analyses).
- Standing non-goals: PDV fiscal/tenancy rules (reference only, never
  ported), Llama binding (deferred unless MCP proves insufficient),
  framework-mixing detection (deferred: needs a package-dependency graph),
  `FG-I18N` + `FG-YAGNI` (deferred with reason). Former stretches (P2/P3
  builds, MCP, distribution) are scheduled, not cut.
- Heal budget: 3 attempts + snapshot + Attack-the-Premise (ForceField §3)
  wins; ProjectOverview's "1–2 turns" is stale (kept: Portuguese doc
  rewrites are a non-goal).
- Language: `AGENTS.md` (new docs in English) wins over ProjectOverview §5
  (Portuguese internal docs); old PT docs kept as-is.

## Approach

EDD loop per rule (spec → vectors → visitor → test → grade), cheapest gate
first. Rule backlog comes from `docs/_origem/CanonicalRecipesCatalog.md`
(§1–§2: FG-ST-001, FG-ASYNC-002) and `docs/_origem/DisruptiveInnovations.md`
(Part 2 §2 item 4 missing-`ValueKey`, Part 3 §1 AST suite + §2 Lifecycle &
Memory Warden); live recipes live in each spec's §2. System backlog follows
PLAN-02 P0 → P3 in dependency order; research items are spike-first (spec
or recorded drop).

## Steps

### Phase 1 — Deterministic core (PLAN-02 Step 0 + P0)

1. Step 0: harden `grade` (per-file parse errors), FP-limit fields,
   `specs/system/_template.md`. (Kind-skip + `analysis` field DONE.)
2. `SYS-TELE-001` telemetry canon; `SYS-CLI-001a` `check <path> [--json]`
   with gate mapping over the `_analyzers` registry.
3. `FG-ST-001`: controllers instantiated in `build()` (Recipes §1). — DONE
   (`specs/TS-03-controller-in-build-guard.md`, `TC-03` pair, 9/9 tests,
   grade 6/6).
4. `FG-LIFE-001`: resource symmetry — `StreamSubscription`/`Timer`/
   controllers/`FocusNode`/listener-add without release in `dispose()`
   (DisruptiveInnovations Part 3 §2, Zombie Stream Detector).
5. `SYS-HEAL-001`: heal dispatcher (highest-risk spec — decides the
   agent-vs-harness boundary).
6. `SYS-CLI-001b`: `init` + pre-commit hook (running `check`) + `sandbox`
   commands + install scripts.
- Validation per rule: new spec in `specs/`, new pair in
  `benchmark/vectors/`, `dart test` green, `grade` exit 0. P0 exit: `check`
  works, heal path decided, 4 rules green, canon recorded.

### Phase 2 — Detection breadth (P1 rules + recipes)

1. `FG-ARCH-003`: layer-leak import scan (Recipes §3).
2. `FG-ASYNC-002`: `BuildContext` after `await` without `mounted` guard
   (Recipes §2), incl. the `setState`-after-unmount sub-case.
3. `FG-LAY-004`: unbounded `ListView` in `Column` (Recipes §4).
4. `FG-ST-005`: direct state mutation in Riverpod/Bloc (Recipes §5).
5. `FG-CTX-006`: no `BuildContext` outside `Widget`/`State` signatures.
6. `FG-WID-008`: StatelessWidget immutability (no `var`/non-final fields).
7. `FG-LINT-009`: no-suppression (`// ignore:`, empty `catch`).
8. `FG-KEY-001r`: stateful widgets via `.map()`/`itemBuilder` without `key`
   + `ReorderableListView` (DisruptiveInnovations Part 2 §2 item 4;
   the dataflow version is dropped as unimplementable).
9. `FG-MET-007`: depth/params advisories until `SYS-CAL-001` calibration
   (blocking on uncalibrated thresholds is barred).
10. `SYS-RECIPE-001`: every rule spec carries its §2 Canonical Auto-Heal
    Recipe; lookup key = rule id.
- Validation: 13 rules green with full recipe coverage; per-rule validation
  as in Phase 1.

### Phase 3 — Dynamic gates (P2)

1. `SYS-MUT-001`: mutation runner — sandbox copy (no in-place), 3 operators,
   8s circuit-breaker, canary-mutant milestone.
2. `SYS-VIEW-001`: Tier-1 viewport runner — fixed adversarial matrix,
   `FlutterError` wiring, evidence entries, 8s timeout.
3. `SYS-COV-001`: coverage pipeline enabling the CRAP gate (or an explicit
   CRAP deferral with reason).
4. `SYS-DRY-001`: structural duplication detector (AST normalization,
   ≥0.8 similarity / >15 lines).
- Validation: a planted complacent test is caught and honest tests pass;
  `flutter test` red on `.bad` layout, green after fix.

### Phase 4 — Distribution + MCP (P3 build subset)

1. `SYS-MCP-001`: reconciled wire contract, `bin/flutterguard_mcp.dart` +
   `lib/src/mcp/`, the 4 `SKILL.md` files, `init --mcp` client registration.
2. Packaging: `executables` stanza, `dart install <git URL>` (+ `pub global`
   fallback), install proof from a foreign directory.
3. Dogfood L0: self-`check` over `lib`/`bin`/`test` exits 0 (vectors
   excluded by design) + non-pollution properties.
- Validation: stdio smoke test green per MCP tool; install + hook e2e in a
  scratch clone; `grade` never distributed (install docs cover `check` only).

### Phase 5 — Conditional completion (P3 gated items)

1. `SYS-VIEW-002`: Tier-2 contract — build iff SAM/Vision endpoints verify
   (auth, mask→widget mapping, thresholds); otherwise a recorded deferral.
2. `SYS-CAL-001`: calibration corpus with published precision/recall per
   blocking threshold; flips MET-007 advisory → blocking.
3. Formal decompose-or-drop: `FG-MEM-011`, `FG-FSM-012`, `FG-RACE-013` each
   become EDD specs or recorded drops; remaining FORMAL-004/005 subsets and
   the FORMAL-003 waste-index get IDs at decomposition time.
4. Spikes: `SYS-PROF-001` (rebuild-counter API), `FG-PERF-010` (Main Isolate
   criteria) — each ends in a spec or a recorded drop with reason.
- Validation: every item ends built or explicitly deferred/dropped with
  reason; PLAN-02 Step 5 traceability audit shows zero orphans.

## Validation Plan

- Fast loop: `dart pub get && dart test` after every visitor change.
- Eval gate: `dart run bin/flutterguard.dart grade` (exit 0, evidence appended
  in canon keys).
- Full gate: `dart analyze --fatal-infos` before each phase closes.
- UI gate: `flutter test` for Tier-1 work (Flutter SDK verified present).
- Contract tests for every system spec per PLAN-02 (fixture red→green, stdio
  smoke, hook block, matrix red/green).
- Highest-risk step: `SYS-HEAL-001` patch-apply semantics (defines whether
  the loop is autonomous or agent-assisted).

## Risks / Open Questions

- Heal fork decides the autonomy claim; either side is acceptable if
  specified inside `SYS-HEAL-001` — the risk is leaving it ambiguous.
- Tier-2 endpoints may not exist as documented → recorded deferral with
  Tier-1 standing; no schedule impact since nothing depends on Tier-2.
- Parse-only ceiling: FP rates may force `resolved` analysis per rule; the
  `analysis` front-matter field surfaces this early by design.
- No date pressure: phases exit on validation gates, not the calendar.
- Non-goals: PDV fiscal/tenancy, Llama binding, framework-mixing detection,
  `FG-I18N`/`FG-YAGNI` (see decisions above).
