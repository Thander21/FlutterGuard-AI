---
plan_version: "1.0"
id: "PLAN-01"
title: "First implementation plan to hackathon submission"
status: "proposed"
deadline: "2026-11-04T21:00:00-04:00"
source_docs:
  - "docs/Architecture/Architecture.md"
  - "docs/Architecture/FormalVerificationAlgorithms.md"
  - "docs/Ideas/ProjectOverview.md"
  - "docs/Ideas/DisruptiveInnovations.md"
  - "docs/Rules/HackathonSubmissionBlueprint.md"
  - "docs/Rules/MetaHackathonTrack.md"
  - "docs/Methodology/SddEddWorkflow.md"
  - "docs/Methodology/SpecDrivenDevelopment.md"
  - "docs/Methodology/ForceFieldHarness.md"
  - "docs/Methodology/CleanCodeDeterministicGates.md"
  - "docs/Methodology/CanonicalRecipesCatalog.md"
  - "docs/Integrations/ClientAgentsTracking.md"
---

# PLAN-01: First Implementation Plan to Hackathon Submission

## Goal

Ship a working, demoable FlutterGuard AI prototype before the Meta hackathon
deadline (Nov 4, 2026, 21:00 ET): a deterministic Dart AST core with golden
evals, a minimal CLI, one headless visual gate, and submission artifacts.

## Success Criteria

- `dart test` passes for every rule visitor (zero false positives on `.good`).
- `dart run bin/flutterguard.dart grade` exits 0 and appends `evidence.jsonl`.
- `flutterguard check` audits a target directory and reports violations as JSON.
- One headless viewport case (keyboard-open RenderFlex) fails closed on `.bad`.
- Submission texts (Blueprint §2, Track §2) and demo inputs are ready in English.

## Doc Validation Decisions

Docs were read as a starting point, not truth. Binding resolutions:

- Single-package layout wins (`Architecture.md` §4); the `packages/...` path
  in `SddEddWorkflow.md` was stale and is now fixed.
- `evidence.jsonl` follows the `Architecture.md` schema (implemented); the
  `stage/test_file/result` variant in `SpecDrivenDevelopment.md` is superseded.
- CLI surface follows `HackathonSubmissionBlueprint.md` §4 (`init`, `check
  --json`, pre-commit hook, `.flutterguard/`); `fg run`,
  `bin/ast_guardian.dart`, and `crap`/`dryer` command names are superseded.
- Gates follow `ForceFieldHarness.md` (light → test → full → commit-check),
  mapped onto the tiered runner: parse-only AST first, resolved/compiled
  checks later.
- New docs and code stay in English per `AGENTS.md`; old Portuguese docs are
  kept as-is, no rewrite.
- `FG-FORMAL-001..005` (DFA/CFG provers) are research-grade; only their
  practical subsets (async-gap guard, dispose symmetry) enter this plan.
- Meta endpoints (SAM 3.1, Muse Image, Llama Stack) are unverified; Tier 2
  stays conditional behind interfaces. Tier 1 native gates must demo standalone.
- `SEU-USER` URLs are placeholders; replacing them is a release gate, not code.
- Rule contracts live in `specs/` (normative, grader-read); `docs/` is the
  thinking repository (prose, plans, analyses).

## Approach

EDD loop per rule (spec → vectors → visitor → test → grade), cheapest gate
first. Rule backlog comes from the Blueprint 10-bug table (§3), the AST suite
(`DisruptiveInnovations.md` Part 3.1), and `CanonicalRecipesCatalog.md`.

## Steps

### Phase 1 — AST rule core (EDD loop, highest value first)

1. `FG-ST-001`: controllers instantiated in `build()` (Recipes §1).
2. `FG-ASYNC-002`: `BuildContext` after `await` without `mounted` guard
   (Recipes §2).
3. `FG-LIFE-001`: `StreamSubscription` without `cancel()` in `dispose()`
   (Blueprint bug 01).
4. `FG-KEY-001`: mutable widget collections without `ValueKey` (Blueprint 02).
- Validation per rule: new spec in `specs/`, new pair in
  `benchmark/vectors/`, `dart test` green, `grade` exit 0.

### Phase 2 — CLI completion

1. `flutterguard check <path> [--json]`: run all visitors over a target,
   JSON output per Blueprint §4.
2. `flutterguard init`: scaffold `.flutterguard/` + install pre-commit hook
   running `grade`.
3. Fold `grade` output into the same JSON evidence shape; keep both commands.
- Validation: `check` on `benchmark/vectors/` flags every `.bad`, spares
  every `.good`; hook blocks a planted violation commit in a scratch clone.

### Phase 3 — Mutation gate v0

1. Rewrite 3 operators (`>`, `==`, `true`) in a sandbox copy (no in-place).
2. Fail closed when the suite stays green on mutated code.
- Validation: a deliberately complacent test is caught; honest tests pass.

### Phase 4 — Viewport Tier 1 (needs Flutter SDK)

1. Headless `WidgetTester` case: keyboard inset 320px over a checkout form.
2. Fail closed on `FlutterError` (`RenderFlex overflowed`); record evidence.
- Validation: `flutter test` red on `.bad` layout, green after
  `SingleChildScrollView` fix. This is the video demo anchor (Blueprint §5).

### Phase 5 — Submission artifacts

1. Freeze Blueprint §2 + Track §2 texts; replace `SEU-USER` placeholders.
2. Record inputs for the 120-second script (terminal runs, screenshots).
3. Keep `README.md` (English) and `leiame.md` (Portuguese) in sync.
- Validation: checklist against Blueprint §6 scoring map; repo installs via
  `dart pub global activate --source git <real-url>`.

## Validation Plan

- Fast loop: `dart pub get && dart test` after every visitor change.
- Eval gate: `dart run bin/flutterguard.dart grade` (exit 0, evidence appended).
- Full gate: `dart analyze --fatal-infos` before each phase closes.
- UI gate: `flutter test` for Phase 4 only.
- Highest-risk step: Phase 4 without a local Flutter SDK; verify SDK presence
  before starting it (`flutter --version`).

## Risks / Open Questions

- Only 4 days to submission: if Phase 4 slips, demo Tier 1 with a recorded
  run and keep the AST + mutation story live.
- Meta Tier 2 APIs stay out of the graded path until endpoints are verified.
- `test_fixtures/` playground (Architecture §6) is deferred; golden vectors
  cover the eval need.
- Non-goals: MCP server, auto-heal loop, CRAP/dryer metrics, formal provers,
  Portuguese doc rewrites.
