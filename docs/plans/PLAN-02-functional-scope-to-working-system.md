---
plan_version: "3.0"
id: "PLAN-02"
title: "Functional scope closure to working system"
status: "proposed"
source_docs:
  - "docs/_origem/Architecture.md"
  - "docs/_origem/FormalVerificationAlgorithms.md"
  - ".agents/metaai/Readme.md"
  - ".agents/metaai/MuseSpark.md"
  - ".agents/metaai/MuseCode.md"
  - ".agents/metaai/SamSegmentAnything.md"
  - ".agents/metaai/MuseImageVision.md"
  - ".agents/metaai/LlamaStack.md"
  - "docs/_origem/ProjectOverview.md"
  - "docs/_origem/DisruptiveInnovations.md"
  - "docs/_origem/ReferencePdvDMais.md"
  - "docs/_origem/ClientAgentsTracking.md"
  - "docs/_origem/SddEddWorkflow.md"
  - "docs/_origem/SpecDrivenDevelopment.md"
  - "docs/_origem/ForceFieldHarness.md"
  - "docs/_origem/CleanCodeDeterministicGates.md"
  - "docs/_origem/CanonicalRecipesCatalog.md"
  - "docs/plans/PLAN-01-implementation-to-submission.md"
  - "docs/plans/PLAN-03-architecture-conformance-and-distribution.md"
  - "docs/plans/REVIEW-01-viability-assessment.md"
excluded_docs:
  - "docs/_rulesHackathon/* (hackathon track; dropped project-wide — PLAN-01 v2.0)"
  - "docs/_rulesHackathon/SelfPromotion/* (outreach; out of functional scope)"
---

# PLAN-02: Functional Scope Closure to Working System

## Goal

Close the functional-scope gaps so the documented ideas are sufficient for the
project to really work in code for production use: every subsystem gets an
identified spec (rule or system contract), all doc contradictions get a
recorded resolution, non-goals are explicit — so the plan is complete and
validated before implementation starts.

## Success Criteria

- Every subsystem/rule/metric named in the 17 in-scope docs maps to one spec
  ID, one explicit deferral, or one non-goal — zero orphans.
- Each of the 6 known doc contradictions has a recorded resolution owned by a
  spec.
- Each spec has an implementation guide (inputs, code surfaces, validation
  command) sufficient for an implementer to build without inventing scope.
- Grade tooling accepts the new spec kinds without breaking (`grade` exits 0
  on the existing suite throughout).

## Approach

Two spec kinds, two placements, one loop each:

- **RULE specs** follow the proven EDD pattern (verified in `specs/TS-01`,
  `TS-02`, `TS-03`, `TC-01`/`TC-02`/`TC-03` pairs, `test/`, `lib/src/ast/`,
  `grade` registry): spec → vectors → visitor → test → grade registration.
  Next numbers: `TS-04`/`TC-04` onward.
- **SYSTEM specs** (CLI, heal, MCP, runners, telemetry) are interface/protocol
  contracts. They must NOT land as top-level `specs/*.md`:
  `bin/flutterguard.dart` `_readSpec` throws on any `.md` without
  `failing:`/`passing:` front-matter. They go in `specs/system/SYS-NN-*.md`
  (grade's non-recursive `listSync` already skips subdirectories; grade gets
  hardened to skip `kind: system` explicitly).
- New required rule front-matter (closes the parse-vs-resolved gap):
  `analysis: parse-only | resolved`, plus a mandatory FP-limits section.
  Default is `parse-only` (matches both proven visitors).
  `specs/_template.md` exists and will be updated (verified).
- Contradiction resolutions (reversible assumptions, recorded in the owning
  spec): evidence schema = Architecture §5 (implemented; SDD §3 variant
  superseded); heal budget = ForceField (3 attempts + snapshot +
  Attack-the-Premise), rollback = `git restore` (reconciles both docs);
  Tier-1 keyboard inset = 320px; benchmark layout = `benchmark/vectors/` wins
  (`cases/` + `run_benchmark.dart` deferred); MCP = one reconciled contract
  decided inside SYS-MCP-001; Llama = deferred unless MCP proves insufficient;
  scope boundary = hackathon scope dropped entirely (deadline missed;
  production use only — PLAN-01).
- Priority order is loop-closure-first: deterministic loop (P0) → detection
  breadth (P1) → dynamic gates (P2) → AI/multimodal/research (P3).
- Build order (no freeze; full product for real use): Step 0 → P0 → P1 →
  P2 → P3 build in dependency order. P2 builds fully; P3 builds MCP +
  distribution while Tier-2 stays endpoint-gated, Llama stays deferred, and
  profiler/perf/formal items stay spike-first (spec or recorded drop).
  REVIEW-01 §4 cuts are superseded.

## Steps

**Step 0 — Ground rules (do first, unblocks everything).** Harden `grade`:
skip `kind: system` (DONE in `bin/flutterguard.dart`), per-file parse-error
handling so one bad vector can't kill the run (TODO). Update
`specs/_template.md`: `analysis` field (DONE via PLAN-03 D3), FP-limits
fields (TODO; §3 prose covers them today). Create
`specs/system/_template.md` (TODO; problem, interface/schema, file
placement, evidence wiring, errors/edges, contradictions resolved). Add
`mocktail` dev-dep when contract tests need mocks. Validate: `dart test` +
`dart run bin/flutterguard.dart grade` green, exit 0.

**Step 1 — P0: close the deterministic loop.**
- `SYS-TELE-001` (system, missing): record the telemetry canon (Architecture
  §5 wins). One-page spec + key table. Validate: `grade`-appended lines match
  the table exactly.
- `SYS-CLI-001a` `check` (system, missing): `check <path> [--json]` over the
  existing `_analyzers` registry (adds `args` dep). Must include the
  **gate-mapping section**: `validate-light`/`validate`/`test`/`commit-check`
  definitions, rule→gate assignment (incl. formal light/full mapping),
  evidence-presence enforcement. Gate contents and latency budgets come
  from ForceField §2 (imports/format/syntax → light; changed-file unit
  tests → test; full `analyze` + cross-regression → validate;
  evidence/temp-files/clean-diff → commit-check); budgets validated by
  measurement per REVIEW-01 §3.9. Test invocation is deterministic
  (concurrency/seed flags per ClientAgents §2 Gate 3). Notes:
  `ast_guardian` superseded by `check`.
  Validate: flags every `.bad`, spares every `.good` in `benchmark/vectors/`.
- `FG-ST-001` (rule, recipe exists): controllers in `build()`. EDD:
  `specs/TS-03` → `TC-03` pair →
  `lib/src/ast/controller_build_guard.dart` (parse-only, controller
  type-name allowlist) → test → register. Validate: unit test + `grade`
  green. — DONE (grade 6/6; implemented filename kept per PLAN-03 D5).
- `FG-LIFE-001` (rule, missing, **widened scope**): resource symmetry —
  `StreamSubscription`/`Timer`/controllers/`FocusNode`/listener-add without
  release in `dispose()`, with per-type table (keeps the Timer Leak Slicer
  covered; listener row = `addListener` without paired `removeListener`).
  EDD, parse-only per-class field map; FP-limits must cover `deactivate`,
  composite subscriptions, delegated ownership, removeListener pairing.
- `SYS-HEAL-001` (system, missing — highest-risk spec): heal dispatcher. §1
  declares the **agent-vs-harness boundary** (from the traced agent-assumed
  list); decides `auto_heal_strategy` semantics (`insert_before_invocation`,
  `replace_invocation`); **fast-path classification** (which fixes are
  mechanical/local zero-token vs model-dispatched); structured-error capture
  format; retry cap; rollback mechanism; **human diagnostic report** emission
  on rollback. Validate: contract test red→patch→green on a BLOC-001 fixture.
- `SYS-CLI-001b` `init` + hook (system, missing): scaffold `.flutterguard/`,
  write `flutterguard.yaml` (schema in spec), install pre-commit hook running
  `check` (not `grade`, per PLAN-01 Phase 2 + PLAN-03), inject
  AGENTS.md/CLAUDE.md/GEMINI.md mandate text, add
  `sandbox load/reset/check` commands, ship install scripts. Notes: hook
  blocks, human commits (no-auto-commit). Validate: hook blocks a planted
  violation commit in a scratch clone.

**Step 2 — P1: detection breadth (all EDD unless noted).**
- `FG-ARCH-003` (recipe exists): layer-leak import scan + project layer-map
  config note.
- `FG-ASYNC-002` (recipe exists): context-after-await; guard-form allowlist
  (`mounted`, `context.mounted`, early returns) + mandatory FP-limits;
  vectors must include the `setState`-after-unmount sub-case.
- `FG-LAY-004` (recipe exists): unbounded `ListView` in `Column`.
- `FG-ST-005` (recipe exists): direct state mutation in Riverpod/Bloc.
- `FG-CTX-006` (new ID): no `BuildContext` outside `Widget`/`State`
  signatures. Parse-only.
- `FG-WID-008` (new ID): StatelessWidget immutability — no `var`/non-final
  fields. Parse-only.
- `FG-LINT-009` (new ID): no-suppression — flag `// ignore:` and empty
  `catch` (enforces "Root Cause Only"). Parse-only.
- `FG-KEY-001r` (RESCOPED, supersedes the as-stated rule): only stateful
  widgets built via `.map()`/`itemBuilder` without `key` +
  `ReorderableListView`; the "mutable collection" dataflow version is dropped
  as unimplementable.
- `FG-MET-007` (partial): widget depth ≤ 5 + constructor params > 7 ship as
  advisory findings until `SYS-CAL-001` calibration exists (blocking on
  uncalibrated thresholds is barred per REVIEW-01 §3.9); Semantic Ratio 15%
  becomes a spike — drop if no node classifier is defined.
- `SYS-RECIPE-001` (system, missing): recipe-per-rule coverage — every rule
  spec carries its §2 Canonical Auto-Heal Recipe (`specs/_template.md`
  mandates it; proven in TS-01/02/03); lookup key = rule id. The
  methodology catalog is archived at
  `docs/_origem/CanonicalRecipesCatalog.md` (frozen reference, do not
  extend); MuseCode.md points injection at the spec §2. Consultation
  sources: the 7 PDV D+ rule files mapped in
  `docs/_origem/ReferencePdvDMais.md` §1.

**Step 3 — P2: dynamic gates (all system specs; full build).**
- `SYS-MUT-001`: mutation runner — sandbox layout (records the
  `test_fixtures/` resolution: `vectors/` = golden evals, `fixtures/` =
  agent playground), source-rewriter API, test invocation with 8s
  circuit-breaker timeout, green-on-mutant comparator; first milestone =
  canary-mutant test. Validate: catches a planted complacent test; honest
  tests pass.
- `SYS-VIEW-001`: Tier-1 viewport runner — harness file/API (resolves
  `takeScreenshot` vs `golden_toolkit`), fixed matrix config (Compact
  320x480 POS, keyboard inset 320px, accessibility zoom textScaleFactor
  2.0, landscape split ratio — unioned with the PDV D+ adversarial
  resolutions 1024x768 / 800x600 from uilayout.md; membership decided
  here), screenshot path `build/test_snapshots/`, `FlutterError.onError`
  wiring, evidence entries, 8s timeout; Flutter-SDK dependency confirmed
  (3.47.9 present); fallback = Tier-1-lite AST heuristic where the SDK is
  absent (CI). Validate: `flutter test` red on bad layout, green after fix.
- `SYS-COV-001`: coverage pipeline (`test --coverage` → lcov → `cov(m)`)
  enabling the CRAP gate — or record an explicit deferral of CRAP. Note: CC
  counter is parse-only; only `cov` needs the pipeline.
- `SYS-DRY-001` (new): structural duplication detector — AST normalization,
  subtree enumeration, hashing, complexity strategy; thresholds ≥0.8
  similarity / >15 lines from docs.

**Step 4 — P3: distribution + gated completion (MCP builds; Tier-2/Llama conditional; profiler/perf/formal spike-first).**
- `SYS-MCP-001`: reconcile the three documented tool contracts into one wire
  contract; JSON-RPC schemas; `bin/flutterguard_mcp.dart` + `lib/src/mcp/`
  (+ `json_rpc_2`/`stream_channel` deps); `init --mcp` writes; **chat-skills
  reconciliation** (`*spec/*vector/*visitor/*grade` ↔ MCP tools ↔ CLI mapping
  table) + author the 4 `SKILL.md` files under `.agents/skills/` per the
  AGENTS.md placement convention. Validate: stdio smoke test per tool.
- `SYS-VIEW-002` (blocked on verified endpoints): Tier-2 contract — real
  SAM/Vision endpoints + auth, mask→widget identity mapping (render-tree
  dump/debug keys — SAM labels as documented are invalid), overlap/tap-target
  thresholds, margin-drift-vs-grid scope-or-defer, IoU-heatmap scope-or-defer,
  offline behavior, local-vision (OpenCV) fallback note.
- `SYS-LLAMA-001` (deferred by default): Llama binding only if MCP proves
  insufficient.
- `SYS-PROF-001` (spike, no code): research a real per-Element
  rebuild-counter API before any profiler spec exists. Spike acceptance:
  either a defined budget contract (per-flow limits, Element counting
  points, evidence keys) feeding a future `SYS-PROF-002` gate, or a
  recorded drop with reason.
- `FG-FORMAL-001..005` (research): decompose each prover into EDD rule
  spec(s) following the Step 0 template, or drop; none is directly
  implementable as documented. Backlog reserves: `FG-MEM-011` (retained
  closures, FORMAL-001), `FG-FSM-012` (sealed-class/FSM enforcement,
  spike-first, FORMAL-005), `FG-RACE-013` (stale async race / request-id /
  cancellation tokens, spike-first, FORMAL-004). Named subsets: ST-001
  (FORMAL-003 purity, done), ASYNC-002 + LIFE-001 (FORMAL-001), LAY-004
  (FORMAL-002); remaining FORMAL-004/005 subsets and the FORMAL-003
  waste-index get IDs at decomposition time.
- `FG-PERF-010` (new ID, spike-first): Main Isolate Starve — define "heavy
  sync work" detection criteria before speccing.
- `SYS-CAL-001` (backlog, scheduled after P1): threshold calibration corpus —
  real Dart/Flutter corpus with published precision/recall per blocking
  threshold (depth, params, similarity, ratio, tap-target); gates the
  MET-007 advisory→blocking flip.

**Step 5 — Traceability audit.** Map each of the 17 docs' named ideas to its
spec ID, deferral, or non-goal. The 6 contradictions each cite their owning
spec (`SYS-TELE-001`, `SYS-HEAL-001`, `SYS-MCP-001`, `SYS-RECIPE-001`,
`SYS-CLI-001` + `SYS-VIEW-001` for paths/matrices, audit itself for benchmark
layout). Validate: zero orphans.
Non-goals recorded: `uml-viewer`-style viz (deferred), PDV domain rules —
tenancy/fiscal (reference only, never ported), `FG-I18N` + `FG-YAGNI`
(deferred with reason), framework-mixing detection (deferred: needs a
package-dependency graph + cross-file framework census; low precision
parse-only), MetaAi study checklists (not spec material). Hackathon
submission artifacts are dropped (deadline missed), not deferred.

## Validation Plan

- Per RULE spec: `dart test test/<guard>_test.dart` (flags `.bad`, spares
  `.good`, zero false positives) + `dart run bin/flutterguard.dart grade`
  exit 0 with `evidence.jsonl` appended in canon keys.
- Per SYSTEM spec: its contract test (fixture red→green, stdio smoke test,
  hook block test, or matrix red/green as specified above).
- Phase exits: P0 = `check` works, heal path decided, 4 rules green (2
  existing + ST-001 + LIFE-001), canon recorded; P1 = 13 rules green with
  full recipe coverage; P2 = mutation + Tier-1 + coverage/duplication built
  with fixture proofs; P3 = MCP built (stdio smoke green), Tier-2
  built-or-deferred with recorded reason, calibration corpus built, formal
  provers decomposed-or-dropped.
- Highest-risk validation: `SYS-HEAL-001` patch-apply semantics (defines
  whether the loop is autonomous or agent-assisted) and `SYS-VIEW-002`
  endpoint verification (may force Tier-2 to a declared manual step).

## Pre-Execution Analysis (plan audit, run before starting)

- **ID/collision check:** all IDs unique. Noted pre-existing wart: `ST-`
  prefix is used twice in docs (`FG-ST-001` controllers-in-build,
  `FG-ST-005` state-mutation). Kept as documented — lookup key is the full
  ID, so no functional clash; do not renumber (recipes and docs already cite
  them).
- **Numbering convention:** rule specs continue `TS-03`/`TC-03` upward in
  P0→P1 implementation order (ST-001=03, LIFE-001=04, ARCH-003=05,
  ASYNC-002=06, LAY-004=07, ST-005=08, CTX-006=09, WID-008=10, LINT-009=11,
  KEY-001r=12, MET-007=13). System specs numbered as listed; files
  `specs/system/SYS-<NN>-<slug>.md`.
- **Dependency soundness:** Step 0 → P0 → P1 → P2 → P3 holds, with one
  feedback arrow: if `SYS-HEAL-001` decides agent-owned healing,
  `SYS-MCP-001`/chat-skills priority rises from P3 to P2 (they become the
  execution interface). No other cross-phase blockers: P1 rules need only
  Step 0; P2 runners need P0's `check` + canon; P3 needs P2 evidence paths.
- **Dependency declarations per spec:** `SYS-CLI-001a` adds `args`;
  `SYS-MCP-001` adds `json_rpc_2` + `stream_channel`; Step 0 adds `mocktail`
  (dev); Tier-1 specs add the Flutter-SDK decision. No other new deps
  allowed without amending the owning spec.
- **Prerequisites re-verified this run:** `grade` throws on non-conforming
  `specs/*.md` (placement rule stands); `specs/system/` is ignored by
  grade's non-recursive listing; `specs/_template.md` exists (update, don't
  create); `pubspec.yaml` carries only `analyzer` + `test`; BLOC/RIV/ST-001
  + vectors + tests are green (`grade` 6/6, `dart test` 9/9).
- **Residual risks (ranked):** (1) HEAL-001 fork decides the system's
  autonomy claim — wrong call here re-scopes P3; (2) VIEW-002 endpoints may
  not exist as documented — Tier-2 could collapse to manual; (3)
  LIFE-001/ASYNC-002 FP rates may force `resolved` analysis, breaking the
  parse-only default and the <50ms narrative — the `analysis` field surfaces
  this per rule by design.
- **First actions on `go` (not started):** edit `bin/flutterguard.dart`
  (kind-skip + per-file errors) → update `specs/_template.md` → create
  `specs/system/_template.md` → run `dart test` + `grade` → write
  `SYS-TELE-001`. No P0 spec work begins until Step 0 validation is green.

## Risks / Open Questions

- Parse-only ceiling: several P1 rules may need resolved analysis (`analyzer`
  Element model) if FP rates fail — each rule spec states its `analysis`
  choice up front so this surfaces early, not mid-implementation.
- `SYS-HEAL-001` is the architectural fork: code-owned dispatcher
  (recommended assumption) vs agent-following-instructions (current reality).
  Either is acceptable if specified; the risk is leaving it ambiguous.
- Tier-1 SDK confirmed present (Flutter 3.47.9; otherwise pure-Dart
  `pubspec`); Tier-2 endpoints are unverified. Tier-2 carries an explicit
  go/no-go decision.
- Open questions: none blocking P0 — the two forks above (heal ownership,
  MCP-vs-Llama) carry reversible defaults and are decided inside their own
  specs.
