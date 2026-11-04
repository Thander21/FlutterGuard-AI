---
spec_version: "openspec-1.0"
id: "SYS-CAL-001"
title: "Threshold calibration corpus and verdicts"
status: "approved"
kind: "system"
---

# 1. Problem

Blocking on uncalibrated thresholds is barred (REVIEW-01 §3.9):
MET-007 (depth/params), SYS-DRY-001 (similarity), and SYS-COV-001
(CRAP) all ship advisory with their blocking flip owned by this
contract. This spec defines the calibration corpus, publishes
precision per threshold with per-flag judgments, and records the
verdict: every threshold HOLDS advisory — the evidence actively
argues against the current forms (real false positives, not
borderline calls). Negative results are results: calibration did
its job by preventing bad flips.

# 2. Interface / Schema

Corpus v1 (defined by roots; 92 files at ratification):

- MET depth/params: `lib/`, `bin/`, `test/`, `tool/`,
  `viewport/lib/`, `viewport/test/`, `samples/`,
  `benchmark/vectors/` (golden vectors are labeled
  positives/negatives by construction).
- DRY similarity: `lib/`, `bin/`, `tool/`, `viewport/` (real code
  only — `benchmark/` twins and `test/` fixtures are intentional
  near-copies, not smell candidates).
- CRAP: trios (`test/duplication_test.dart` →
  `lib/src/duplication/detector.dart`,
  `test/metric_guard_test.dart` →
  `lib/src/ast/metric_guard.dart`, `test/mcp_server_test.dart` →
  `lib/src/mcp/tools.dart`).

Harness: `dart tool/calibrate.dart` (re-runnable; prints the flag
tables below). Tripwire: `test/calibration_test.dart` pins the
ratified MET flag set and DRY pair membership — any detector or
codebase change that moves the numbers fails the suite and forces
re-calibration (re-judge, re-ratify, update this spec).
Unparseable corpus files are skipped by the harness (printed as
`SKIP (unparseable)`) and the tripwire — they cannot be measured;
the tripwire pins the skip set to exactly
`benchmark/vectors/TC-17_syn.bad.dart`, intentionally unparseable
as TS-17's golden negative.

Flip bar (defined here, applied below): a threshold flips
advisory→blocking iff precision == 1.0 AND N ≥ 5 judged flags AND
no open FP pattern AND the measurement is sound (no breaker
timeouts). Rationale: a blocking gate stops developers — anything
less than unanimous evidence on a non-trivial sample keeps the
threshold advisory.

Published measurements (ratified 2026-11-03):

## Params > 7 — HOLD advisory (precision 1/2)

| flag | judgment |
|---|---|
| `TC-13_met.bad:7` (9 params) | TP (labeled positive by design) |
| `detector.dart:47` `ClonePair` (9 params) | FP — pure immutable data holder; a config object adds indirection without benefit |

Recall 1.0 by exhaustiveness (every ctor visited); 7-param
boundary clean (`TC-13.good` + unit fixtures). Open FP pattern:
immutable data holders. Only one real >7 ctor in 92 files — the
threshold barely fires on real code.

## Depth > 5 — HOLD advisory (precision 1/2)

| flag | judgment |
|---|---|
| `TC-13_met.bad:32` (6-deep) | TP (labeled positive by design) |
| `good_layout.dart:18` (6-deep) | FP — idiomatic `MaterialApp>Scaffold>scroll>Row>Box>SizedBox`; every real screen carries 2–3 scaffold levels |

Recall 1.0 by exhaustiveness; 5-deep boundary clean. Open FP
pattern: app scaffolding counts toward the budget. No retune is
fitted to N=2 (that would be overfitting, not calibration).

## DRY ≥ 0.8 / > 15 lines — HOLD advisory (was 3/13; TPs healed)

TP at ratification (blocking-worthy, extraction-actionable):
`checkPath` ~= `runTier1Lite` @0.823;
`CoverageRunner._runCapture` ~= `MutationRunner._runTest` @0.850;
`resolvesOnPath` ~= `isFlutterSdkAvailable` @0.882. All three
were HEALED into `lib/src/util.dart` (`collectDartFiles`,
`runWithBreaker` + `breakerTimeoutExit`, `resolvesOnPath`, with
the per-file loop shared as `analyzeFilesWithRules`) with
behavior pinned by the existing suites — the pairs are gone.

Remaining 12 pairs, all FP (known classes): ten
small-immutable-data-class pairs (prior eight plus two new
`BreakerResult` pairings — the new result type joins the same
FP class), one rule-guard-idiom pair (`ArchLayerGuard` ~=
`ControllerBuildGuard` — the deliberate per-rule pattern), one
thin-wrapper pair (`_viewport` ~= `_mutation` — shared try/catch
shape, different domains, extraction forced). Precision on the
remainder is 0/12: the detector flags nothing actionable left
in this corpus. Plus `BadLayout` ~= `GoodLayout` @0.857 over
`viewport/` (intentional fixture twins — excluded from the
corpus, recorded as an FP class: detectors cannot tell fixture
twins apart).

Recall: exhaustive pairwise → 1.0 w.r.t. the metric; near-miss
band (0.5–0.8) top-8 spot-check found only more data-class/idiom
shapes, no missed actionable clone.

## CRAP ≥ 10 — HOLD advisory (precision 4/6, method-constrained)

`detector.dart` trio (20 methods, one clean run): OVER =
`findDuplication` CC35/cov0.99 (TP — genuinely complex),
`bagJaccard` CC10/cov1.00 (FP — fully-tested 15-line pure
function flagged by the formula's CC floor),
`_bagOf` CC10/cov0.93 (FP — same floor),
`visitExtensionDeclaration` CC3/cov0 (TP — untested code, the
gate's purpose), `visitConstructorDeclaration` CC3/cov0 (TP).
`metric_guard.dart` trio: OVER = `_checkDepth` CC11/cov1.00 (TP —
formula working as designed, but see the design question).
`mcp/tools.dart` trio: UNMEASURED (8s breaker vs a 24s suite).

Open items: the CC-floor design question (is cov=1/CC≥10
blocking-worthy?) and the slow-suite strategy (hop budget vs
sharding). A repeat `detector.dart` run tripped the breaker under
load — CRAP measurement itself is load-sensitive at 8s/hop.

## Out of measurement

- Tap-target (< 48dp): moot — Tier-2 deferred (SYS-VIEW-002), no
  geometry source exists. Re-entry with Tier-2 re-entry.
- Semantic Ratio 15%: already DROPPED in P1 (TS-13 §1, no
  parse-only classifier) — prior drop, no action.

# 3. File Placement

- `specs/system/SYS-CAL-001-calibration.md` (this contract).
- `tool/calibrate.dart` (measurement harness; `tool/` is dev-only,
  never distributed).
- `test/calibration_test.dart` (tripwire: pins MET flag set + DRY
  pair membership; CRAP excluded — slow suites trip the breaker).
- Consumers (read-only): TS-13, SYS-DRY-001, SYS-COV-001 (their
  "flip owned by SYS-CAL-001" pointers resolve HERE — all hold).

# 4. Evidence Wiring

Emits no `evidence.jsonl`: calibration publishes in this spec, not
in telemetry. Any future calibration-gate lines MUST amend
SYS-TELE-001 first (canon rule §4).

# 5. Errors and Edges

- Re-calibration trigger: the tripwire test fails (numbers moved)
  → re-run `dart tool/calibrate.dart`, re-judge every flag, amend
  this spec's tables, update the test pins. Never update pins
  without re-judging.
- Re-ratifications: 2026-11-03 — FG-BUILD-014 landing shifted one
  DRY pair key (`rules.dart:21` → `:22`, import insertion); same
  13 pairs, same judgments, precision still 3/13, HOLD reaffirmed.
  MET set unchanged (new files MET-clean).
- Re-ratifications: 2026-11-03 — util-heal removed the 3 TP pairs
  (verified gone, behavior pinned by suites) and added 2
  `BreakerResult` data-class FPs; 12 pairs re-judged all-FP,
  precision on remainder 0/12, HOLD reaffirmed. MET set
  unchanged (`util.dart` MET-clean).
- Re-ratifications: 2026-11-04 — light-gate trio (TS-15/16/17)
  plus the repo format pass: 3 DRY pair keys shifted
  (`rules.dart:22` → `:25` ×2 from registry import insertions;
  `tools.dart:190/212` → `189/210` from formatter reflows);
  same 12 pairs, same FP classes, precision on remainder still
  0/12, HOLD reaffirmed. MET set unchanged (new files
  MET-clean). Corpus scans now skip unparseable files (see §2);
  the skip set is pinned to the designed TC-17 negative.
- Threshold retunes are new claims: changing 5/7/0.8/10 needs a
  fresh corpus pass meeting the flip bar — fitting to the
  ratified sample is barred (same overfitting rule as §2).
- v2 directions (recorded, not scheduled): scaffold-aware depth
  counting; data-holder-aware params (exclude pure finals-only
  classes); data-holder exclusion for class-like DRY units
  (`build()`-method pairs unaffected); CRAP CC-floor decision;
  slow-suite CRAP strategy.
- The DRY calibration crash (doc-comment `beginToken` off the
  `.next` chain — every real file crashed collection) was fixed
  under this contract: walk from
  `firstTokenAfterCommentAndMetadata`, null-safe advance,
  per-file collect tolerance (SYS-DRY-001 §2/§5 amended,
  regression test added). Calibration on a crashing detector
  would have measured nothing.
- Corpus drift: new first-party code joins the corpus
  automatically (roots, not file lists); third-party code never
  does (only this repo + its vectors).

# 6. Contradictions Resolved

- Blocking vs calibration (REVIEW-01 §3.9 vs Gate A/B/MET
  FAIL-CLOSED rules): the bar wins again — this contract is the
  evidence it demanded, and the evidence says hold. The
  enforcement deferrals in TS-13, SYS-DRY-001, and SYS-COV-001
  all resolve to this record.
- Precision/recall split: precision is measured per flag above;
  recall is 1.0-by-exhaustiveness for all three deterministic
  detectors (every declaration visited / every pair compared)
  plus boundary negatives (MET) and a near-miss band check
  (DRY) — no hidden-false-negative hunt beyond that is claimed.
