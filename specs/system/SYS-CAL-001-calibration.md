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

v2 (2026-11-04, TS-13 data-holder exemption): `ClonePair`
verified clean (finals-only + `toString` only); sole flag is
`TC-13_met.bad:7` (TP, labeled positive by design). Precision on
emitted flags 1/1; the immutable-data-holder FP pattern is
CLOSED. HOLD reaffirmed: N=1 < 5 (flip bar), and real-code
precision is vacuously 1.0 on a trivial sample.

M1 (2026-11-06, R2-5 medium): `rules.dart:42`
(M2 re-key: `:43`, import shift)
`RuleAnalyzer` (8 params) judged FP — declarative
config-ctor class: named, defaulted, finals-only knobs with
one predicate method, so grouping the scope knobs into a
sub-object would churn 32 call sites for zero behavioral
gain; the flag pins instead of healing. Precision on
emitted flags 1/3; HOLD reaffirmed (N=1 < 5 flip bar; open
FP pattern: declarative config ctors).

## Depth > 5 — HOLD advisory (precision 1/2)

| flag | judgment |
|---|---|
| `TC-13_met.bad:29` (6-deep) | TP (labeled positive by design) |
| `good_layout.dart:18` (6-deep) | FP — idiomatic `MaterialApp>Scaffold>scroll>Row>Box>SizedBox`; every real screen carries 2–3 scaffold levels |

Recall 1.0 by exhaustiveness; 5-deep boundary clean. Open FP
pattern: app scaffolding counts toward the budget. No retune is
fitted to N=2 (that would be overfitting, not calibration).

v2 (2026-11-04, TS-13 scaffold transparency): `good_layout.dart:18`
verified clean (`MaterialApp`/`Scaffold` discounted, 4
non-scaffold levels); sole flag is `TC-13_met.bad:29` (TP,
labeled positive by design). Precision on emitted flags 1/1; the
scaffolding FP pattern is CLOSED for the observed closed set.
HOLD reaffirmed: N=1 < 5 (flip bar).

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

v2 MET growth (2026-11-04): +1 pair —
`MetricGuard.visitConstructorDeclaration` ~=
`WidgetImmutableGuard.visitFieldDeclaration` @0.802 (the MET
method grew past 15 lines). Judged FP, guard-idiom class (2nd
of class — same deliberate per-rule visitor shape as the
`ArchLayerGuard` ~= `ControllerBuildGuard` pair; extraction
across node/violation types is forced, not actionable). 13
pairs pinned, precision on the remainder still 0/13; HOLD
reaffirmed.

v2 exclusion (2026-11-04, SYS-DRY-001 §2): data-holder
class-likes are never units. All ten data-class pairs verified
gone (no member pairs surfaced — data-holder members are
sub-threshold); survivors are exactly the 3 previously judged
FPs (guard-idiom ×2, thin-wrapper ×1; one key shifted +1 line
from a shared-predicate import insertion, similarity
unchanged). The data-holder FP class is CLOSED. HOLD
reaffirmed: 0 actionable of 3.

REL-001 R3 (2026-11-04, CLI layering `bin/` → `lib/`): +1 pair —
`init` ~= `CoverageRunner.run` @0.803 (the moved `init()` now scans
as `lib/`). Judged FP, new procedural-flow-twin class: CLI
scaffolding (arg parsing, file writes, hook install, MCP
registration) vs coverage pipeline (validation, subprocess runs,
lcov parsing, scoring) share only sequential-procedure shape
(guards, loops, file I/O, error strings); no shared domain, no
extractable unit. 4 pairs pinned, 0 actionable; HOLD reaffirmed.
MET set unchanged (moved code MET-clean).

Wave 2 (2026-11-05, thin `heal` CLI, SYS-VAL-001 F6): +1 pair —
`heal` ~= `init` @0.828 (the new `heal()` arg scaffolding twins the
`init()` scaffolding). Judged FP, procedural-flow-twin class (2nd
of class — same CLI-scaffolding shape as the R3 pair: ArgParser
setup, parse, help, positional checks; each command's surface
diverges after the scaffold, so extraction is forced, not
actionable). 5 pairs pinned, 0 actionable; HOLD reaffirmed. MET
set unchanged (new files MET-clean; corpus at 118 files). `bin/`
and `tool/` verified 0 pairs. CRAP observation unchanged in
counts (detector 3 OVER, metric/tools 0; detector file untouched).

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

v2 (2026-11-04, CC-floor decision + slow lane): `overBudget`
now requires `cov < 1.0` (SYS-COV-001 §6). Re-measured:
detector trio 3 OVER (`findDuplication` CC35/cov0.99, TP;
extension-visitor CC3/cov0, TP; `_bagOf` CC10/cov0.93, TP —
uncovered lines exist to look at, unlike the absolved floor
cases); `bagJaccard` CC10/cov1.00 verified clean. Metric trio
0 OVER (`_checkDepth` CC13/cov1.00 absolved). `mcp/tools`
trio MEASURED via the 180s slow lane (11 methods, 0 OVER —
first measurement ever; the UNMEASURED era ends, sharding
deferred per SYS-COV-001 §2). Precision on emitted flags
3/3; the CC-floor FP pattern is CLOSED. HOLD reaffirmed:
N=3 < 5 (flip bar).

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
- Re-ratifications: 2026-11-04 — MET v2 refinement (TS-13
  scaffold transparency + data-holder params): both open FP
  patterns closed, 2 flags left, both labeled TPs, HOLD
  reaffirmed (N=1 per threshold < 5). DRY: one new pair from
  MET growth, judged FP (guard-idiom class), 13 pairs pinned.
  CRAP observation (design re-judgment deferred to the U3
  CC-floor decision): detector trio unchanged (5 OVER, same
  methods); metric trio now 2 OVER (`_checkDepth` CC13/cov1.00,
  `_isDataHolderCtor` CC11/cov0.91); `mcp/tools` still
  UNMEASURED. Corpus at 110 files (roots-based growth).
- Re-ratifications: 2026-11-04 — DRY v2 exclusion (data-holder
  class-likes never units, shared `isDataHolderClass` with
  TS-13): ten data-class pairs eliminated, 3 survivors
  re-judged same-FP, HOLD reaffirmed. MET set unchanged
  (refactor behavior-preserving). CRAP observation (design
  re-judgment in U3): detector trio now 4 OVER (new tests
  cover `_UnitCollector.visitConstructorDeclaration`;
  `bagJaccard`/`findDuplication`/`_bagOf`/extension-visitor
  unchanged); metric trio now 1 OVER (`_isDataHolderCtor`
  moved to `data_holder.dart`, outside trio files);
  `mcp/tools` still UNMEASURED.
- Re-ratifications: 2026-11-04 — CRAP v2 (CC-floor decision:
  coverage absolves, `overBudget` requires `cov < 1.0`; slow
  lane 180s/hop for the mcp/tools trio): floor FPs eliminated
  (2 verified clean), 3 OVER re-judged all-TP, tools trio
  measured 0 OVER, HOLD reaffirmed (N=3 < 5, fully sound
  measurement). MET/DRY sets unchanged.
- Re-ratifications: 2026-11-04 — TS-07 v3 growth: one new TP pair
  (`_childArgument` ~= `_hasShrinkWrapTrue` @0.812, twin named-arg
  scans) HEALED into a shared `_namedArgumentValue` helper with
  behavior pinned by the TS-07 suite — the pair is gone. Same
  3 survivors, same judgments, HOLD reaffirmed. No pin changes.
- Re-ratifications: 2026-11-04 — REL-001 R3 CLI layering (`bin/` →
  `lib/src/cli/`): one new DRY pair (`init` ~= `CoverageRunner.run`
  @0.803), judged FP (procedural-flow-twin class); 4 pairs pinned,
  HOLD reaffirmed. MET set unchanged (moved code MET-clean; corpus
  at 114 files). `bin/` verified 0 pairs post-thinning. CRAP
  observation unchanged (detector 3 OVER, same methods; metric/tools
  0).
- Re-ratifications: 2026-11-05 — Wave 2 thin `heal` CLI: one new
  DRY pair (`heal` ~= `init` @0.828), judged FP
  (procedural-flow-twin class, 2nd of class); 5 pairs pinned, HOLD
  reaffirmed. MET set unchanged (new files MET-clean; corpus
  at 118 files). `bin/`/`tool/` verified 0 pairs. CRAP counts
  unchanged (3/0/0).
- Flip evaluation: 2026-11-05 — Wave 3 F4 (fresh pass, corpus
  118 files, every flag re-judged): params 1/1 N=1 (labeled TP),
  depth 1/1 N=1 (labeled TP), DRY 0/5 actionable (all FP, known
  classes), CRAP 3/3 N=3 (same v2 methods); sound measurement, no
  FP pattern reopened, no new SKIPs. Flip bar (1.0 + N≥5)
  unmet on all four → NO flips, HOLD reaffirmed everywhere. No
  pin changes. No field corpus exists; repo+vectors fallback per
  SYS-VAL-001.
- Re-ratifications: 2026-11-05 — SYS-CAL-002 P0-1 analyzer
  6→14 migration + tall-style reformat (language floor
  3.4→3.13): MET depth key `TC-13_met.bad:32` → `:29` (same
  6-deep TP, formatter collapsed the tree); params key
  unchanged. DRY: 3 pair keys shifted by reformat reflows
  (`init.dart:59` → `:60` ×2, `tools.dart:189/210` →
  `:196/218`; same pairs, same FP judgments, similarities
  0.824/0.805/0.818); the `metric:82~widget:74` guard-idiom
  pair (@0.802) fell below threshold after the `name2`→`name`
  token change — re-judged eliminated-FP (was FP, still 0
  actionable). 4 pairs pinned, 0 actionable, HOLD reaffirmed.
  `bin/`/`tool/` verified 0 pairs; skip set unchanged
  (TC-17 still the designed negative); corpus still 118
  files. CRAP re-measured on green: 3/0/0, same methods
  (line shifts only).
- Re-ratifications: 2026-11-05 — SYS-CAL-002 P1+P2 growth: two
  DRY pairs dissolved, one surfaced. The `heal`~=`init` and
  `init`~=`CoverageRunner.run` procedural-flow twins fell below
  threshold after the P2-1 `init` growth (`--no-hook`,
  `--hook-command`) — re-judged eliminated-FP (were FP, still
  0 actionable). New pair `CoverageRunner`~=`MutationRunner`
  @0.807 (whole-class units): judged FP, runner-pipeline
  class — both are validate→stage→breaker→classify pipelines
  in different domains (coverage capture vs mutation
  judging); the shared breaker already lives in
  `lib/src/util.dart`, the rest is domain logic, extraction
  forced. 3 pairs pinned, 0 actionable, HOLD reaffirmed.
  MET set unchanged (same 2 TPs); `bin/`/`tool/` 0 pairs;
  skip set unchanged; corpus still 118 files. CRAP
  re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-05 — SYS-CAL-003 R2-1
  (ASYNC-002 scope + closure threading): new pair
  `AsyncContextGuard`~=`ListKeyGuard` @0.847 (whole-class
  units, async:47-197 ~= listkey:77-221), judged FP,
  guard-idiom class (3rd of class — same deliberate
  per-rule visitor skeleton as the pinned arch~controller
  pair and the eliminated metric~widget pair; different
  rules and domains, extraction across node/violation
  types forced, not actionable). 4 pairs pinned, 0
  actionable, HOLD reaffirmed. MET set unchanged (same 2
  TPs); `bin/`/`tool/` 0 pairs; skip set unchanged;
  corpus at 120 files. CRAP re-measured: 3/0/0, same
  methods.
- Re-ratifications: 2026-11-05 — SYS-CAL-003 R2-2
  (adoption scope: baseline/diff/counts): new pair
  `check`~=`init` @0.837 (whole-function units,
  check:221-362 ~= init:75-194), judged FP,
  procedural-flow-twin class (3rd of class — same CLI
  scaffolding shape as the `heal`~=`init` and
  `init`~=`CoverageRunner.run` pairs: ArgParser setup,
  parse, help, usage exits; each command's surface
  diverges after the scaffold, so extraction is forced,
  not actionable). 5 pairs pinned, 0 actionable, HOLD
  reaffirmed. MET set unchanged (same 2 TPs); `bin/`/
  `tool/` 0 pairs; skip set unchanged; corpus at 122
  files (+2: `baseline.dart` + `baseline_test.dart`).
  CRAP re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-05 — SYS-CAL-003 R2-3
  (CTX-006 stored-only rewrite): new pair
  `_StoredTypeCollector`~=`_RootCollector` @0.840
  (private-collector units, ctx:91-107 ~=
  listkey:223-243), judged FP, guard-idiom class (4th
  of class — same private visitor-collector skeleton
  as the whole-guard pairs; different collection
  targets — BuildContext offsets vs creation
  expressions — in different rules, extraction forced,
  not actionable). 6 pairs pinned, 0 actionable, HOLD
  reaffirmed. MET set unchanged (same 2 TPs); `bin/`/
  `tool/` 0 pairs; skip set unchanged; corpus still
  122 files (R2-3 edited in place). CRAP re-measured:
  3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-4
  (KEY-001r v3 scope + MET holder v3): the R2-1
  `AsyncContextGuard`~=`ListKeyGuard` guard-idiom FP
  fell below threshold after the ListKeyGuard rewrite
  (scope facts, state-bearing/foreign branches) —
  re-judged eliminated-FP (was FP, still 0
  actionable). The `ctx:91`~=`listkey:223` collector
  pair shifted to `:306` (same pair, same FP
  judgment, similarity 0.840). 5 pairs pinned, 0
  actionable, HOLD reaffirmed. MET set unchanged
  (same 2 TPs — the holder widening moves nothing on
  this corpus); `bin/`/`tool/` 0 pairs; skip set
  unchanged; corpus still 122 files (R2-4 edited in
  place). CRAP re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  1 (FG-BAN-018 banned symbols): new pair
  `BannedSymbolGuard`~=`MetricGuard` @0.801
  (whole-class units, banned:160-219 ~=
  metric:53-140), judged FP, guard-idiom class (5th
  of class — same deliberate per-rule visitor
  skeleton as the pinned whole-guard pairs;
  different rules and domains, extraction across
  node/violation types forced, not actionable). The
  `check:221`~=`init:75` procedural-flow twin
  shifted to `:80` (same pair, same FP judgment,
  similarity 0.837 — the init template gained a
  commented example). 6 pairs pinned, 0 actionable,
  HOLD reaffirmed. MET set unchanged (same 2 TPs —
  new code MET-clean); `bin/`/`tool/` 0 pairs;
  skip set unchanged; corpus at 127 files (+5: the
  new guard, 2 tests, 2 tc18 vectors). CRAP
  re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  2 (FG-LOG-019 print/logger + shared `rule_params`
  extraction): new pair `analyzeBannedSymbolFile`~=
  `analyzeLogFile` @0.851 (entry-function units,
  banned:107-128 ~= log:103-123), judged FP,
  runner-pipeline class (2nd of class — both are
  load→except→parse→visit pipelines in different
  rules; the shared section-load/except already
  lives in `rule_params.dart`, the rest is rule
  logic, extraction forced — merging across
  different config shapes trades clarity for
  indirection). The `banned:160`~=`metric:53`
  guard-idiom pair shifted to `:130` (same pair,
  same FP judgment, similarity 0.801 — the BAN
  refactor into `rule_params` removed 30 lines);
  the `check:221`~=`init:80` twin shifted to `:85`
  (same pair, same FP judgment, similarity 0.837 —
  the init template gained the print_logger
  example). 7 pairs pinned, 0 actionable, HOLD
  reaffirmed. MET set unchanged (same 2 TPs);
  `bin/`/`tool/` 0 pairs; skip set unchanged;
  corpus at 132 files (+5: the log guard, the log
  test, `rule_params`, 2 tc19 vectors). CRAP
  re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  3 (FG-TOK-020 theme tokens): two new pairs, both
  judged FP, runner-pipeline class (3rd/4th of
  class): `LogConfig`~=`TokConfig` @0.839
  (config-class units, log:23-86 ~= tok:52-103 —
  both are section-parse pipelines with different
  schemas, extraction across field sets forced)
  and `analyzeLogFile`~=`analyzeTokFile` @0.854
  (entry-function units, log:103-123 ~=
  tok:120-138 — same load→except→parse→visit
  pipeline reasoning as gate 2). The
  `check:221`~=`init:85` twin shifted to `:90`
  (same pair, same FP judgment, similarity 0.837
  — the init template gained the theme_tokens
  example). 9 pairs pinned, 0 actionable, HOLD
  reaffirmed. MET set unchanged (same 2 TPs);
  `bin/`/`tool/` 0 pairs; skip set unchanged;
  corpus at 136 files (+4: the tok guard, the tok
  test, 2 vectors). CRAP detector+metric trios
  UNMEASURED (8s breaker under load — known
  load-sensitivity, method constraint, unpinned
  by design); tools trio 0 OVER.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  4 (FG-I18N-021 i18n + FlatRuleConfig heal): the
  i18n landing first fanned the config/entry
  family to 16 pairs (two at ≥0.99 — structural
  clones), which re-judged the gate-2/gate-3
  runner-pipeline FPs as TPs: the per-rule
  config classes and entry functions were
  HEALED into a shared `FlatRuleConfig` +
  `runFlatRule` in `lib/src/rule_params.dart`
  with behavior pinned by the 20 guard tests —
  all 8 config/entry twins verified gone. Two
  whole-guard pairs survive the heal:
  `BannedSymbolGuard`~=`I18nGuard` @0.842 and
  `I18nGuard`~=`ThemeTokenGuard` @0.831, both
  judged FP, guard-idiom class (6th/7th of
  class — deliberate per-rule visitor skeletons,
  extraction across node/violation types forced,
  not actionable). The `check:221`~=`init:90`
  twin shifted to `:95` (same pair, same FP
  judgment, similarity 0.837 — the init template
  gained the i18n example). 8 pairs pinned, 0
  actionable, HOLD reaffirmed. MET set unchanged
  (same 2 TPs); `bin/`/`tool/` 0 pairs; skip set
  unchanged; corpus at 140 files (+4: the i18n
  guard, the i18n test, 2 tc21 vectors). CRAP
  re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  5 (FG-ENC-022 encoding): no movement — the
  byte-level guard twins nothing (no visitor
  skeleton, no config class) and the init
  template is untouched (no config section), so
  all 8 pairs re-verified identical, 0
  actionable, HOLD reaffirmed. No pin changes.
  MET set unchanged (same 2 TPs); `bin/`/`tool/`
  0 pairs; skip set unchanged; corpus at 144
  files (+4: the enc guard, the enc test, 2
  vectors). CRAP re-measured: 3/0/0, same
  methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  6 (FG-ORP-023 orphans): no movement — the tiny
  path-oracle guard twins nothing and the init
  template is untouched (no config section), so
  all 8 pairs re-verified identical, 0
  actionable, HOLD reaffirmed. No pin changes.
  MET set unchanged (same 2 TPs); `bin/`/`tool/`
  0 pairs; skip set unchanged; corpus at 149
  files (+5: the orp guard, the orp test, 3 tc23
  files). CRAP re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 gate
  7 (FG-LYR-024 layers + list-rule heal): the
  landing first fanned to 11 pairs with three
  BAN~=LYR twins at up to 0.984, re-judged TP
  and HEALED in two passes — shared
  `loadRuleList`/`stringListField`/`scanTarget`
  plus a generic `RuleListConfig<T>` replacing
  both config shells, with behavior pinned by
  the 10 BAN+LYR tests; the `_scanTokFile` loop
  twin dissolved via an idiomatic
  map/whereType cleanup. Residual
  `analyzeBannedSymbolFile`~=`analyzeLayerFile`
  @0.919 judged FP, runner-pipeline class: every
  line of load/parse/scan logic now lives once
  in `rule_params.dart` — the residual is
  per-rule wiring (load-or-inject, gating
  predicate, guard closure) with rule-specific
  cores, and a 2-type-param generic over it
  would trade clarity for indirection.
  Recorded precedent: twins at ≥0.95 sharing
  logic heal; twins at ≤0.95 sharing only wiring
  shape rate FP (a third list-rule reopens the
  question). The BAN-guard pairs re-keyed to
  `:97` (config deletion moved the class),
  `I18nGuard`~=`ThemeTokenGuard` to `tok:98`
  (scan shrink), `check:221`~=`init:95` to
  `:100` (init template gained the layer_rules
  example); the gate-6 BAN-entry~LOG-entry twin
  dissolved (BAN entry reshaped). 9 pairs
  pinned, 0 actionable, HOLD reaffirmed. MET
  set unchanged (same 2 TPs); `bin/`/`tool/` 0
  pairs; skip set unchanged; corpus at 153
  files (+4: the lyr guard, the lyr test, 2
  tc24 vectors). CRAP re-measured: 3/0/0, same
  methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 tail
  T1 (FG-CC-025 complexity ceiling): no movement — the
  flat AST counter twins nothing (no visitor skeleton
  growth, no config class) and the init template is
  untouched (fixed ceiling, no config section), so
  all 9 pairs re-verified identical, 0
  actionable, HOLD reaffirmed. No pin changes.
  MET set unchanged (same 2 TPs); `bin/`/`tool/`
  0 pairs; skip set unchanged; corpus at 157
  files (+4: the cc guard, the cc test, 2
  vectors). CRAP re-measured: 3/0/0, same
  methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 tail
  T2 (FG-RIV-026 provider naming): new pair
  `ContextScopeGuard`~=`ProviderNamingGuard`
  @0.870 (whole-class units, ctx:43-89 ~=
  prov:60-107), judged FP, guard-idiom class
  (8th of class — same deliberate per-rule
  visitor skeleton as the pinned whole-guard
  pairs; different rules and domains,
  extraction across node/violation types
  forced, not actionable). 10 pairs pinned, 0
  actionable, HOLD reaffirmed. MET set
  unchanged (same 2 TPs); `bin/`/`tool/` 0
  pairs; skip set unchanged; corpus at 161
  files (+4: the prov guard, the prov test, 2
  vectors). CRAP re-measured: 3/0/0, same
  methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 tail
  T3 (FG-LAY-004 v4 Text-in-Row): no movement —
  the `_textName` ladder twins nothing (near
  `_scrollableName` in shape, below threshold
  in tokens) and the shared `_flag` emit kept
  the message block single, so all 10 pairs
  re-verified identical, 0 actionable, HOLD
  reaffirmed. No pin changes. MET set
  unchanged (same 2 TPs — the TC-13.good:32
  Row→Column maintenance preserves the
  depth-5 boundary exactly); `bin/`/`tool/` 0
  pairs; skip set unchanged; corpus still 161
  files (T3 edited in place). CRAP
  re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 tail
  T4 (FG-ARB-027 arb metadata + file scopes): the
  `check:221`~=`init:100` procedural-flow twin
  re-keyed to `:233` (same pair, same FP
  judgment, similarity 0.837→0.832 — the
  check() doc growth plus the batch-filter
  lines). New pair `checkFiles`~=
  `_siblingImport` @0.810 (check:111-146 ~=
  mutation:229-274), judged FP,
  procedural-flow-twin class (4th of class —
  the checkFiles growth pushed a near-miss
  over the line; CLI fan-out vs mutation
  import-rewriting share only
  sequential-procedure shape — loops, a sort,
  guards — with no shared logic and no
  extractable unit, far below the 0.95-heal
  bar). 11 pairs pinned, 0 actionable, HOLD
  reaffirmed. MET set unchanged (same 2 TPs);
  `bin/`/`tool/` 0 pairs; skip set unchanged;
  corpus at 163 files (+2: the arb guard +
  test — the `.arb` vectors sit outside the
  Dart-only MET/DRY walks by construction).
  CRAP re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 tail
  T5 (FG-PII-028 PII in logs): the
  `check:233`~=`init:100` procedural-flow twin
  re-keyed to `:107` (same pair, same FP
  judgment, similarity 0.832 — the init
  template gained the pii example). New pair
  `BannedSymbolGuard`~=`_ArgScanner` @0.807
  (whole-visitor units, banned:97-156 ~=
  pii:182-254), judged FP, guard-idiom class
  (9th of class — the PII argument scanner's
  multi-override skeleton twins the deliberate
  per-rule visitor shape; different rules and
  domains, extraction across node/violation
  types forced, not actionable). 12 pairs
  pinned, 0 actionable, HOLD reaffirmed. MET
  set unchanged (same 2 TPs); `bin/`/`tool/`
  0 pairs; skip set unchanged; corpus at 167
  files (+4: the pii guard, the pii test, 2
  tc28 vectors). CRAP re-measured: 3/0/0,
  same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 tail
  T6 (FG-ENV-029 env parity + prefix scopes): the
  `check:111`~=`_siblingImport` and
  `check:233`~=`init:107` twins re-keyed to
  `:112`/`:234` (same pairs, same FP judgments;
  the check() call-site growth nudged its
  similarity 0.832→0.829). New pair
  `analyzeEncFile`~=`analyzeEnvFile` @0.814
  (entry-function units, enc:39-82 ~=
  env:30-72), judged FP, runner-pipeline class
  (6th of class — byte-decode-plus-marker
  scan vs key-set parity share only the
  oracle-entry skeleton — read, guard, loop,
  collect, sort — with disjoint cores and
  opposite failure modes (fail-closed vs
  fail-open); no extractable unit, far below
  the 0.95-heal bar). 13 pairs pinned, 0
  actionable, HOLD reaffirmed. MET set
  unchanged (same 2 TPs); `bin/`/`tool/` 0
  pairs; skip set unchanged; corpus at 169
  files (+2: the env guard + test — the
  `.env` vectors sit outside the Dart-only
  MET/DRY walks by construction). CRAP
  re-measured: 3/0/0, same methods.
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 medium
  M1 (FG-ASSET-030/VER-031/DOC-032 package gates +
  exact-name scopes): new MET flag `rules.dart:42` (8
  params on the RuleAnalyzer entry ctor), judged FP,
  declarative config-ctor class (named, defaulted,
  finals-only knobs, one predicate — the §2 M1 note
  records the judgment; pinned, not healed). New DRY
  pair `analyzeAssetFile`~=`analyzeEnvFile` @0.808
  (entry-function units, asset:30-67 ~= env:30-72),
  judged FP, runner-pipeline class (7th of class —
  YAML-span asset resolution vs KEY= parity share
  only the oracle-entry skeleton with disjoint
  cores; no extractable unit, far below the
  0.95-heal bar). The two check twins re-keyed
  `:112`→`:113` and `:234`→`:235` (same pairs,
  same FP judgments — the `names:` call-site
  lines). 14 pairs pinned, 0 actionable, HOLD
  reaffirmed. `bin/`/`tool/` 0 pairs; skip set
  unchanged; corpus at 175 files (+6: 3 guards +
  3 tests — all 11 non-Dart M1 vectors sit
  outside the Dart-only MET/DRY walks by
  construction). CRAP: tools.dart 0 over budget,
  2 trios UNMEASURED (8s breaker timeouts under
  load — the known slow-suite flake,
  tripwire-excluded by design).
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 medium
  M2 (FG-TST-033 presence + select-tests + `--analyze`):
  the `check:235`~=`init:107` procedural-flow twin
  dissolved (eliminated-FP — the check() analyze block
  plus the init template growth pushed it below
  threshold; same judgment class, no longer
  measurable). Re-keys: MET `rules:42`→`:43` and DRY
  `checkFiles:113`→`:114` (same flags/pairs, same
  judgments — single import-line shifts). No new twins
  from the 9 new files (selection/analyzer/presence
  units all twin-clean). 13 pairs pinned, 0 actionable,
  HOLD reaffirmed. MET set otherwise unchanged (2 TPs
  + the pinned config-ctor FP); `bin/`/`tool/` 0
  pairs; skip set unchanged; corpus at 184 files (+9:
  3 lib + 3 tests + 3 tc33 vectors). CRAP: detector
  trio measured 3 over-budget this pass
  (findDuplication CC=35 cov=0.99 — reads as
  near-timeout partial coverage, same known flake
  family as M1's UNMEASURED pass;
  tripwire-excluded by design).
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 medium
  M3–M5 (dep/license audits + heal pre-step + per-gate
  report): the `checkFiles:114`~=`_siblingImport` twin
  dissolved (eliminated-FP — the msByRule threading
  reshaped checkFiles below threshold; 2nd check-family
  elimination, no check.dart pair remains). New pair
  `_git`~=`runDepAudit` @0.805 (baseline:169-186 ~=
  deps:87-108), judged FP, runner-pipeline class (8th of
  class — sync spawn + ArgumentError-cause + stdout shape
  share only the subprocess-invocation skeleton across
  disjoint commands; below the 0.95-heal bar). New pair
  `heal`~=`init` @0.844 (heal:76-218 ~= init:113-232),
  judged FP, procedural-flow-twin class (5th of class —
  CLI entry fan-out over disjoint domains). 14 pairs
  pinned, 0 actionable, HOLD reaffirmed. MET set
  unchanged (2 TPs + the pinned config-ctor FP);
  `bin/`/`tool/` 0 pairs; skip set unchanged; corpus at
  189 files (+5: deps/licenses lib + deps/licenses/
  gate-report tests). CRAP: same 3-over detector trio
  as M2 (stable across passes; tripwire-excluded).
- Re-ratifications: 2026-11-06 — SYS-CAL-003 R2-5 ledger
  (`--evidence` + `ledger.dart`): verified, no movement
  — MET set and 14 DRY pins unchanged (no check.dart
  pair remains to re-key; ledger units twin-clean).
  Corpus at 191 files (+2: ledger lib + test).
- Re-ratifications: 2026-11-06 — SYS-MUT-001 shadow staging
  (flat-pair + shadow-package strategies + compile canary):
  the `CoverageRunner`~=`MutationRunner` twin dissolved
  (eliminated-FP — the shadow lifecycle reshaped
  MutationRunner below threshold; was FP, runner-pipeline
  class). Re-key: `_viewport`~=`_mutation` `:196`/`:218` →
  `:197`/`:219` (same pair, same FP judgment — one
  tool-description line). 13 pairs pinned, 0 actionable,
  HOLD reaffirmed. MET set unchanged (2 TPs + the pinned
  config-ctor FP); `bin/`/`tool/` 0 pairs; skip set
  unchanged; corpus still 191 files. CRAP: detector trio
  UNMEASURED this pass (8s coverage timeout under load),
  metric/mcp trios 0 over budget (tripwire-excluded).
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
