---
spec_version: "openspec-1.0"
id: "SYS-CAL-003"
title: "Field calibration round 2: re-pilot findings and remediation"
status: "draft"
kind: "system"
---

# 1. Problem

The second field pilot re-ran `check` (`fb61306`, clean clone,
same method as round 1) against the real ERP `lib/`: 694 files,
Dart 3.13.7, Windows x64, no config, no `init`, zero ERP-side
changes. Full report, with per-rule samples checked against
the code, archived as-received (Portuguese) at
`docs/pilots/RELATORIO_FlutterGuard_reteste_ERP.md`,
2026-11-05.

Round 1's blockers are gone — the tool now reads all 694 files
with zero parse errors — but whole-project visibility surfaced
new false-positive-heavy rules. Verdict: still not gate-ready.

Measured outcome:

| | `e07b523` (pilot 1) | `fb61306` (pilot 2) |
|---|---|---|
| Files read clean | 254 / 694 | **694 / 694** |
| Parse errors (FG-SYN-017) | 2,587 | **0** |
| FG-FMT-016 on Windows | crashed | **runs** (50-file batches, zero findings) |
| Generated-file findings | 103 | **0** |
| Total findings | 2,836 | 2,355 |

Findings by rule (pilot 2): FG-MET-007 1,913 (advisory),
FG-ASYNC-002 209, FG-CTX-006 71, FG-LINT-009 64, FG-KEY-001r 35,
FG-LIFE-001 34, FG-RIV-001 19, FG-BUILD-014 5, FG-ARCH-003 5 —
plus 76 exact duplicates (same file, line, rule).

Prior criticisms: 6 resolved (parse, FMT crash, generated noise,
`context:` label shape, init conflicts, mutation `flutter test`
in code), 4 partial (RIV factories, LIFE cascade, BUILD
indirect subclass, LINT same-line-only justification),
plus the README table error (§2.8).
`init` and the mutation runner were code-reviewed, not executed.

New criticisms: FG-ASYNC-002 is the trust killer (209 findings,
6/6 FPs sampled — any identifier named `context`, no
`if (mounted)` block recognition in try/closures); FG-MET-007
drowns everything (1,913 warnings, depth ceiling 5, primary-ctor
models not exempt); FG-KEY-001r flags non-Flutter targets
(`pw.*`, String methods); no baseline/ratchet and no diff mode,
so legacy adoption means disabling rules.

Real signals (worth ERP-side fixes with or without the tool):
FG-ARCH-003 caught Drift queries inside two search widgets that
the ERP's own layer audit misses (package, not layer);
FG-LIFE-001 caught an undisposed `TextEditingController`;
FG-LINT-009 caught 13 fully-empty `catch (_) {}`.

Interim ERP position (until the §5 bar is met): do not gate.
Selective `flutterguard.yaml` v2: FG-ARCH-003, FG-ST-001,
FG-ST-005 on; FG-LIFE-001 advisory-only; everything else off.

Scope note: the ERP is calibration corpus #1, not the mold.
§7 binds every R2 item to multi-project generality — config
over hardcode, framework packs, fixtures from 2+ shapes.

This spec verifies each claim against the repository (§2) and
charters the round-2 remediation in the pilot's recommended
order (§3). Rule-behavior changes amend their owning TS
contracts; each ships with golden vectors or regression tests
plus a spec diff.

# 2. Evidence Verification (Claim-by-Claim)

Ambient SDK at verification: Dart 3.13.7 stable on Windows x64,
repo at `fb61306`.

## 2.1 FG-RIV-001 residue — CONFIRMED

`_isFactoryCall`
(`lib/src/ast/riverpod_watch_guard.dart:105-116`) covers bare
factories, `X.family`, and `x.overrideWith` — no `.autoDispose`
chains (`FutureProvider.autoDispose(.family)`), no
`Consumer.builder` build scope. The report's three sampled
patterns fall exactly in these gaps.

## 2.2 FG-LIFE-001 cascade, close, ownership — CONFIRMED

`_isRefOnDispose` requires a bare `ref` target, so cascade
`ref..onDispose(...)` (a `CascadeExpression`, e.g.
`boot_resolver_io.dart:47` — the P1-2 acceptance case) is
missed. Release names are `dispose`/`cancel` only: provider
`close()` is not a release. Ownership (constructor-received
controllers) and non-`State` release methods (`stop`/`close`)
are not modeled — accepted from the field sample, fixtures at
implementation time.

## 2.3 FG-BUILD-014 indirect subclass — CONFIRMED (known FP)

TS-14 documents indirect notifier subclasses as a known FP, and
the ERP case (`BootResolverImpl extends BootResolver`) is
exactly that. Exclusion is direct-superclass only. The
report's return-type proposal (exclude `build` whose declared
return type is not `Widget`) is implementable parse-only —
`_isWidgetType` already reads the declaration — but needs the
edge grammar (§4 Q5).

## 2.4 FG-LINT-009 same-line-only — CONFIRMED

`_isJustified` accepts rationale only as trailing `//` text on
the `// ignore:` line itself (P1-5, as specified). The ERP
convention justifies on the line above (28 of 39 sampled) —
precisely the case SYS-CAL-002 §P1-5 said the re-pilot would
surface.

## 2.5 FG-ASYNC-002 scope and block gaps — CONFIRMED

Sinks are any `SimpleIdentifier` named `context` (TS-06 §1), so
`FiscalContext` locals and `SecurityContext` properties flag —
55 findings in widgetless `data/`/`engine/`/`service` files.
The `if (mounted)` scan-fresh rule EXISTS (guard doc,
TS-06 §3:68-70), but the report shows it failing inside `try`
and closures — first implementation step is failing fixtures
from `printer_page.dart:70` / `open_pdv_page.dart:115` before
any guard change.

## 2.6 FG-MET-007 budgets and exemption — CONFIRMED, mechanism corrected

`maxWidgetDepth = 5`, `maxConstructorParams = 7`, documented in
code as "uncalibrated guesses". The report's mechanism
hypothesis (a P0-1 AST change hides primary ctors from the
exemption) is REFUTED by probe: primary ctors parse as
ordinary `ConstructorDeclaration`s, and pure primary-ctor
models are exempt exactly like classic ones. The 86 param
findings point to companion methods — any method beyond
`toString`/`==`/`hashCode` (`toJson`, `copyWith`, `props`, …)
fails `isDataHolderClass`, so real-world models flag. R2-4
characterizes the exact breaker set from ERP-shaped fixtures
and fixes the doctrine (likely widening past value-identity,
exact rule ratified in the TS-13 amendment), not a
primary-ctor special case — and re-verifies SYS-CAL-001 DRY
pins, since the doctrine is shared with the DRY collector.

CORRECTION 2026-11-06 (R2-4 re-probe): the REFUTED claim
above is itself wrong — true primary ctors
(`class C(final x, …)`) parse as
`PrimaryConstructorDeclaration`, which no visitor observes,
so they are already clean. The 86 ERP param findings are
classic-ctor models (including `.new` named ctors) with
companions. The fix direction STANDS (holder widening, no
primary-ctor special case); primary ctors stay unmeasured
by design (TS-13 carves them out explicitly).

## 2.7 FG-KEY-001r scope — CONFIRMED

`_simpleName` strips import prefixes (`pw.Padding` →
`Padding`), so foreign-package widgets are indistinguishable
from Flutter ones; scope covers `.map()`→`children:` and every
`itemBuilder`, with no reorderable/stateful restriction and no
import awareness. Matches the sampled FPs.

## 2.8 FG-ARCH-003 signal + README row — CONFIRMED

Drift queries inside widgets are invisible to a
package-direction audit by construction (drift is a package,
not a layer) — the two search widgets are true positives the
ERP gate structurally misses. The README row ("a layer
validator: disable", `README.md:197`) is therefore wrong: the
two checks complement each other.

## 2.9 FG-CTX-006 — CONFIRMED (both mechanisms located)

Method parameters flag via `visitNamedType`: any
`BuildContext` reference inside a non-UI class flags
(`lib/src/ast/context_scope_guard.dart:119-127`), so
`NotificationService.showSuccess(BuildContext, …)` is the
expected outcome. Builder-signature fields flag via
`_flagStored` → `_StoredTypeCollector`, which collects the
nested `BuildContext` inside the function type
(`context_scope_guard.dart:130-141,153-164`).

## 2.10 Catch severity split — ACCEPTED from field sample

13 fully-empty vs 12 comment-only catches (incl. the three
`connection_io.dart` cases SYS-CAL-002 §5 required — that bar
item is MET). Empty-without-comment → error, comment-only →
warning depends on the warn channel (R2-2).

## 2.11 Duplicates — CONFIRMED

`checkPath` sorts findings (`_byFileRuleLine`) but never
dedups — `unawaited(Future.microtask(...))` yielding two
FG-BUILD-014 on one line is the expected outcome.

## 2.12 Baseline, diff mode, exits — CONFIRMED absent (exits corrected, see note)

No finding baseline/ratchet exists ("baseline" hits are the
mutation clean-baseline run and perf docs — different
concepts). `check` flags are `--json`/`--include-generated`
only; exits are 0 clean-or-warnings / 1 errors / 2 usage.

CORRECTION 2026-11-05 (Q3 triage): the warn channel exists —
warnings render with a `warning:` prefix, carry JSON
`severity`, and never fail the gate (`check.dart:216,225`,
approved CLI-001a §2). The report's "no separation" is stale.
What is absent is a distinct WARN exit code (deliberately:
exit 2 is usage errors) plus error/warning counts. Baseline
and diff mode remain absent as stated.

## 2.13 Prior resolutions holding — CONFIRMED by the re-run

694/694 parse, FMT completes on Windows, zero generated
findings, init coexistence flags (code-read). Mutation
`flutter test` path likewise code-read, still not executed
end to end.

## 2.14 Campodeforca gap list — ACCEPTED as positioning input

The 12 high-priority generic gates (plus the medium list
and engine items) are ERP-side inventories (like SYS-CAL-002
§2.11): plausible, not repo-verifiable. They enter §3 as
backlog, not design.

# 3. Remediation Program

Order follows the pilot's §4 recommendation. Each item amends
its owning contract when behavior changes; each ships with
golden vectors or regression tests plus a spec diff.

## R2-1. FG-ASYNC-002: scope `context`, fix block protection

- Parse-only scoping: `context` counts only as a `build`
  parameter or `State` getter receiver, never when redeclared
  in scope (`final context =`, foreign-typed parameters) —
  exact grammar in §4 Q1. Recognize `if (mounted)` /
  `if (context.mounted)` blocks including inside `try` and
  closures (failing fixtures from §2.5 first).
- Strengthen the README/LEIAME row to "disable when running
  `use_build_context_synchronously`" (docs, ships here).
- Broadening: the scoping rule is framework-blind (any
  redeclared `context` passes); fixtures pair ERP shapes
  (FiscalContext) with non-ERP ones (generic service +
  Bloc-style handler).
- Amends: `specs/TS-06-async-context-guard.md`.
- Acceptance: the fiscal-service shapes are clean,
  `printer_page`/`open_pdv_page` block shapes are clean,
  label shapes stay clean, true post-await `BuildContext`
  uses still flag.

## R2-2. Adoption engine: dedup, baseline, diff, warn channel

- Deduplicate `check` output on (file, line, rule), joining
  messages; duplicates class goes to zero.
- Finding baseline with ratchet (per-file counts vs a
  committed baseline that only descends) + diff mode
  (merge-base/worktree scope for the hook and agent loop) —
  design in §4 Q2.
- Severity visibility (the warn channel already exists per
  CLI-001a — `severity`, `warning:` prefix, warnings-never-fail):
  error/warning counts in the human summary + JSON, exit codes
  unchanged — semantics in §4 Q3.
- Broadening: the engine stays framework-blind (no
  framework knowledge in dedup/baseline/diff/output); diff
  v1 may assume git (merge-base), noted as a v1 boundary.
- Amends: `specs/system/SYS-CLI-001a-check.md` (+ a baseline
  contract if the design needs one).
- Acceptance: the 76-duplicate class is empty; a legacy tree
  adopts with baseline green and only-new-findings red;
  warn-only runs exit 2.

## R2-3. Partial remainder + FP classes

- RIV-001 (TS-02): any `Factory(.autoDispose|.family)*`
  chain is a factory; `Consumer`'s `builder:` argument
  is build scope (`ConsumerWidget`/`HookConsumerWidget`
  `build()` methods already sit outside callbacks — verify
  while there).
- LIFE-001 (TS-04): cascade `ref..onDispose` counts;
  `close` joins the release names; only self-instantiated
  fields flag (constructor-received is borrowed); outside
  `State`/`Notifier`, `close`/`stop`/`cancel`/`dispose`
  all release (§4 Q7 for the exact sets).
- BUILD-014 (TS-14): exclude `build` whose declared return
  type is not `Widget` (§4 Q5), keeping the negative-list
  design.
- LINT-009 (TS-11): accept a preceding-line `//` rationale
  (non-doc, non-ignore) besides the trailing form (§4 Q4).
- LINT-009 severity (TS-11): fully-empty catch stays error,
  comment-only catch warns — needs the R2-2 warn channel.
- CTX-006 (TS-09): restrict to fields + globals only —
  builder signatures and method parameters pass. Retires
  the `visitNamedType` scope rule (dead once only stored
  positions flag); `_flagStored` stays with a function-type
  carve-out. Fixture-first per repo flow.
- README/LEIAME: ARCH-003 complements layer validators
  (fix the row); no ARCH-003 code change.
- Broadening: RIV/BUILD Riverpod knowledge stays inside
  those rules (pack-local); the builder-scope doctrine is
  checked against `BlocBuilder.builder` (extend now if
  trivial, else follow-up); LIFE ownership/release sets
  must fit hand-rolled + Bloc + Riverpod styles, config
  for the rest; LINT/CTX grammars are already generic.
- Acceptance: every named case in §2.1–§2.4 and §2.9 is
  clean on fixtures; the §1 real signals still flag.

## R2-4. FG-MET-007 and FG-KEY-001r scope

- MET-007 (TS-13): fix the data-holder exemption for
  companion-carrying models (characterize the exact breaker
  set from ERP-shaped fixtures; likely widening past
  value-identity,
  ratified in the TS-13 amendment — not a primary-ctor
  special case); re-verify SYS-CAL-001 DRY pins (shared
  doctrine); calibrate depth on field data per SYS-CAL-001;
  default handling per §4 Q3 (off by default vs warn
  channel vs calibrated-on).
- KEY-001r (TS-12): require keys only where reorder or
  state makes them load-bearing, and ignore foreign
  targets (§4 Q6).
- Broadening: the holder doctrine must fit hand-rolled,
  Equatable, freezed, and json_serializable model styles
  (fixtures from 2+ styles; Q9 ratifies the set); KEY stays
  import-aware and framework-agnostic.
- Acceptance: the 29-field primary-ctor model is clean;
  depth ceiling re-pinned with field-data justification
  (method settled in Q3 closure); `pw.*` and
  String-returning builders are clean;
  `ReorderableListView` keyless children still flag.

## R2-5. Generic gates backlog (campodeforca §3.1–§3.3)

Ordered head: banned symbols, print/logger, theme tokens,
i18n literals, encoding/mojibake, orphan generated files,
configurable layers. Then: complexity-on-diff, `.arb`
metadata, Text-in-Row layout, provider naming, plus the
medium list (optional `analyze` step, new-file tests,
changed-tests selection, assets/version/deps/licenses/
links/`.env`/PII, `dart fix` pre-step) and engine items
(parallel gate report, per-run evidence ledger). Each gate
is a future TS contract with vectors via the `fg-spec`
flow — recorded here, designed there. Mapping notes: the
CatchAllGuard row is owned by R2-2 (generic baseline);
TestDoubles/SerialTags stay report-marked optional;
AsyncSafety is Drift-conditional. Every gate ships its
project-varying surface (symbols, logger, theme location,
thresholds) as config, never as literals.

## R2-6. Mutation runner end to end on a fiscal rule

Execute the Backlog-113 wedge in the field: judge mutants
of one ERP fiscal rule with the `flutter test` path. Needs
ERP access (§4 Q8). Still the largest isolated win.

# 4. Open Questions (for review before implementation)

1. ASYNC-002 scope grammar: exact parse-only rule for
   "build parameter or State getter, not redeclared" —
   file heuristic, declaration tracking, or both? And the
   mounted-block gap: which `try`/closure shapes fail?
   RATIFIED 2026-11-05 (owner approved; R2-1 unblocked):
   (a) Sink scoping via shadowing + receiver, no file gate: a
   `context` read counts iff the nearest enclosing declaration
   binding `context` is absent (the `State` getter) or is a
   formal parameter typed `BuildContext` (covers both
   `build(BuildContext context)` and helpers like the §2
   recipe's `submitOrder`); a nearer local, loop-variable,
   catch-variable, or other-typed parameter passes.
   `x.context` passes unless `x` is `this` (kills
   `SecurityContext`-style properties); bare and
   `this.context` reads are subject to shadowing. All
   name-based, parse-only. The file-gate alternative
   (Widget/State declaration or Flutter import) is REJECTED:
   it false-negatives on `BuildContext`-parameter helpers in
   widgetless files, and shadowing alone kills the sampled
   classes. Residual risk: a same-class non-`BuildContext`
   `context` getter still flags (fail-closed); watched in
   pilot-3 samples.
   (b) Mounted blocks in closures: sink collection stops
   descending into `FunctionExpression` bodies; instead each
   closure body found in the statement is scanned with the
   inherited armed state, so an inner `if (mounted)` disarms
   while unguarded deferred uses still flag. Retires the
   TS-06 §3 closure-FP bullet.
   (c) Mounted blocks in `try`: no code change proposed —
   `try`/`catch`/`finally` bodies already thread through the
   statement scanner (`async_context_guard.dart:142-151`), so
   a plain `if (mounted)` inside `try` is recognized;
   fixture-first reproduction from the `printer_page:70` /
   `open_pdv_page:115` shapes discriminates (i)
   closure-inside-try (fixed by (b)), (ii) `&&`-combined
   guards (out of scope v0, stays documented), (iii)
   `if (mounted) { await; use }` re-arm (doctrine STANDS: the
   check is stale across the await, correctly flagged).
   `setState` sinks and `.mounted` recognition unchanged.
2. Baseline/diff design: baseline format, location,
   fingerprint vs counts, ratchet rule, allowlist
   interplay; diff base (merge-base with what?) and flag
   shape. RATIFIED 2026-11-05 (owner approved;
   R2-2 unblocked):
   Dedup: collapse on (file, line, rule) in `checkPath` after
   the sort, joining distinct messages with `; `. `grade` is
   untouched (it validates rules, not output).
   Baseline: JSON `{file: {rule_id: count}}` (counts, not
   fingerprints — campodeforca-shaped); `--baseline <path>`
   reads it, `--update-baseline` rewrites it and exits 0 with
   a delta note. Ratchet: only findings ABOVE the per-(file,
   rule) count report; files/rules absent from the baseline
   fail on any finding (fail-closed for new code); stale
   entries prune on update. Disabled rules are never counted
   and baseline entries for them are ignored silently. No
   walk-up discovery in v1 (explicit flag only — predictable,
   foreign-target safe); `.flutterguard/baseline.json` is the
   suggested conventional path, not mandated.
   Diff: `--diff` + `--diff-base <ref>` (default
   `origin/main`); the file set is `git diff --name-only` of
   the merge-base with HEAD intersected with the target walk;
   a non-git worktree is exit 2 with the cause named.
   File-level v1 (line-level deferred). The hook keeps
   whole-tree `check .` (the baseline makes legacy green);
   `--diff` is for the agent loop and CI. Amends CLI-001a
   §2/§3/§5; no hook change in R2-2.
3. Severity/exit semantics: warn channel shape (human +
   JSON), exit 2 mapping, MET-007 default (off / warn /
   calibrated-on), catch comment-only → warn mapping.
   RATIFIED 2026-11-05 (owner approved; R2-2
   and the severity landings unblocked):
   (a) Exit codes UNCHANGED (0 clean-or-warnings, 1 errors,
   2 usage). The report's "exit 2 WARN" is REJECTED: 2 is
   usage errors, and a third findings-level breaks hook/CI
   contracts.
   (b) Counts replace the bare total: the human summary
   becomes `N violation(s) (E errors, W warnings) in
   <target>.` and JSON gains top-level
   `summary: {errors, warnings}` (no existing test pins the
   old line).
   (c) MET-007 stays warn (advisory). Off-by-default is
   REJECTED: it would starve CAL-001/F4 calibration of field
   data; legacy quiet comes from the baseline, visibility
   from the counts. The calibrated-on flip stays owned by
   CAL-001's bar.
   (d) Comment-only catch → warn lands via an optional
   `RuleAnalyzer.severityFor(violation)` (default: the rule
   severity); LINT-009 returns `warning` for comment-only
   catches. The `RuleViolation` interface stays untouched —
   zero changes to the other 16 rules. Doctrine owned by the
   TS-11 amendment.
4. LINT-009 above-line grammar: immediately preceding
   line only? Blank lines allowed? `///` excluded?
   Stacked rationale lines? RESOLVED 2026-11-05
   (item-turn decision, TS-11 amended; owner reviews
   at the §5 re-run): the rationale must sit on the
   immediately preceding own-line `//` — non-doc,
   non-ignore, non-blank, no blank gap. `///`, empty
   `//`, and blank-gap lines do NOT justify (flagged).
   A stack justifies iff its last line meets the rule.
5. BUILD-014 return-type rule: non-`Widget` excludes —
   what about `void`, `dynamic`, `Future<X>`, typedefs?
   RESOLVED 2026-11-05 (item-turn decision, TS-14
   amended; owner reviews at the §5 re-run): any
   DECLARED return type other than `Widget` excludes —
   `void`, `Future`, `Future<X>`, `dynamic`,
   typedef-named, `Future<Widget>` (typedefs are
   unresolvable parse-only, so the name alone
   decides). Untyped `build()` stays measured
   (fail-closed).
6. KEY-001r scope: reorderable-only, or reorderable plus
   stateful/controller items? Foreign detection via
   imports or prefix heuristic?
   RESOLVED 2026-11-06 (item-turn decision, TS-12
   amended; owner reviews at the §5 re-run):
   (a) Reorderable-strict + proven-stateful.
   Reorderable-only is REJECTED (it drops the
   deletion-transposition signal the rule exists for).
   `ReorderableListView` children + `itemBuilder`
   under it stay strict (runtime asserts, no leaf
   exemption). Other `.map()`→`children:` and
   `itemBuilder` roots flag only when state-bearing:
   (i) the type matches a same-file
   `class X extends StatefulWidget` (cross-file
   unknowns pass — v0 fail-closed INVERTED to
   fail-open: parse-only cannot resolve cross-file
   statefulness); (ii) the creation carries a
   `controller`/`focusNode` named argument (closed
   v0 set). The 23-leaf allowlist is RETIRED
   (subsumed: leaves are never state-bearing).
   (b) Foreign via file gate + prefix rule. No
   `package:flutter/` import → the rule is silent
   (kills pdf-service and pure-Dart files). A
   prefixed `p.X` is in scope only when `p` maps to
   a Flutter or relative import; other-`package:`
   or unmapped prefixes are foreign → skip
   (unknown-prefix fail-open; watched in pilot-3
   samples).
   (c) `_isCapitalized` ignores leading underscores
   (`_getNomeCfop` is not a creation, `_Tile`
   still is) — kills the String-method class
   generally, not just `_get*`.
7. LIFE-001 sets: instantiation-detection rule
   (initializer or `= C()` assignment — what about
   `late`?); non-`State` release-method set.
   RESOLVED 2026-11-05 (item-turn decision, TS-04
   amended; owner reviews at the §5 re-run):
   borrowed = proven constructor-received only
   (`C(this.c)`, `C(c) : _c = c`, body `_c = param`);
   `late` + construction assignment is owned;
   opaque acquires fail-closed (flag). Release
   methods: `dispose` always, plus `close`/`stop`/
   `cancel` outside `State`/`Notifier` subclasses;
   `State` keeps the dispose-only rule.
8. Field access: who executes R2-6 on the ERP fiscal rule
   and the round-3 re-run, and is a redacted sample
   available? RESOLVED 2026-11-05: owner re-runs from a
   clean clone and brings per-rule samples checked against
   the code (round-2 shape, confirmed for R2-6 + round 3).
9. Scope matrix ratification: is the §7 matrix (Riverpod /
   Bloc / vanilla / pure-Dart + future packs) the right R2
   boundary? In particular: `BlocBuilder` scope inside R2-3
   or follow-up? Equatable/freezed in the MET doctrine now
   or later? RATIFIED 2026-11-05: the §7 matrix stands as
   the R2 boundary; `BlocBuilder` scope and Equatable/freezed
   coverage are decided at their item's turn (R2-3/R2-4).
   R2-4 ITEM-TURN CALL 2026-11-06 (TS-13 amended; owner
   reviews at the §5 re-run): Equatable (`props`,
   `stringify`) + json_serializable (`toJson`/`fromJson`,
   `toMap`/`fromMap`) + `copyWith` join the holder
   doctrine NOW; freezed is verified already-exempt
   (factory-only source → vacuously holder, fixture
   proves, no code); hand-rolled display getters stay
   fail-closed, deferred to pilot-3 samples. Depth HOLDS
   at 5 (CAL-001 §5 bars a retune without a fresh corpus
   pass; the cited ERP 6-level shape is verified clean
   under v2 scaffold transparency — cited pattern
   CLOSED, full retune awaits pilot-3 counts).

# 5. Acceptance (pilot-3 bar)

After R2-1–R2-4 land, re-run the identical pilot (`check`
on ERP `lib/`):

- Parse coverage stays 694/694 with zero errors.
- ASYNC-002: ≈0 FP on services/data/engine files; the
  mounted-block fixtures are clean.
- Every §2.1–§2.4 and §2.9 named case is clean on its report
  shape; no new FP class appears in samples.
- MET-007 noise resolved per Q3; duplicates at zero.
- Baseline + diff mode demo green on a legacy-shaped
  tree.
- Real signals retained: the 2 Drift-in-widget findings,
  the undisposed controller, the 13 empty catches (still
  errors); comment-only catches warn.
- Generality: no R2 rule hardcodes an ERP-only idiom without
  a config path; packs fire only on their framework; bars
  hold on vectors + dogfood as well as ERP.
- R2-6 executed if Q8 access exists.

Until then: ERP stays off-gate on the §1 selective yaml;
the three real-signal classes are fixed out of band.

# 6. Implementation Status (2026-11-05)

- R2-1 IMPLEMENTED 2026-11-05 (TS-06 amended per ratified
  Q1; TC-06 vectors extended with a top-level-helper TP plus
  4 near-miss shapes; visitor gains shadowing,
  foreign-property, and closure-inheritance scans; 15/15
  async tests, full suite 261/261, `grade` green; CAL-001
  re-ratified +1 guard-idiom FP pair). Field acceptance
  pending the §5 re-run.
- R2-2 IMPLEMENTED 2026-11-05 (CLI-001a §2/§3/§5 amended per
  ratified Q2/Q3; new `lib/src/cli/baseline.dart`: JSON
  baseline with ratchet, worktree+untracked diff scope,
  absolute-normalized keys; `check` gains dedup, `--baseline`
  / `--update-baseline` / `--diff` / `--diff-base`, and
  error/warning counts with unchanged exits; 17 new tests,
  full suite 278/278, `grade` green; CAL-001 re-ratified +1
  procedural-flow-twin FP pair). Legacy-adoption demo
  pending a legacy-shaped tree (§5 bar, field-adjacent).
- R2-3 IMPLEMENTED 2026-11-05 (TS-02/04/14/11/09
  amended per resolved Q4/Q5/Q7; TS-02 gains Factory
  chains + `Consumer`/`BlocBuilder` `builder:` scope —
  the Q9 BlocBuilder item-turn call landed inside
  R2-3; TS-11 gains the preceding-line rationale +
  `severityFor` warn landing; TS-09 rewritten
  stored-only with the `visitNamedType` scope rule
  retired; README/LEIAME ARCH-003 row fixed per §2.8 —
  no ARCH-003 code change; full suite 295/295,
  `grade` green, analyzer clean; CAL-001 re-ratified
  +1 guard-idiom FP pair, 6 pinned). Fixture
  acceptance per §2.1–§2.4 + §2.9 green; field
  acceptance pending the §5 re-run.
- R2-4 IMPLEMENTED 2026-11-06 (TS-12 v3 + TS-13 v3
  amended per resolved Q6 and the Q9 Equatable/
  json_serializable item-turn call; TC-12 pair
  rewritten to the narrowed invariant; ListKeyGuard
  gains the file gate, prefix-aware foreign rule,
  and state-bearing scope with the leaf allowlist
  retired; `isDataHolderClass` gains serialization/
  `copyWith`/Equatable companions; §2.6 corrected —
  true primary ctors are `PrimaryConstructor-
  Declaration`, unmeasured by design; depth HOLDS
  at 5 with the cited ERP shape verified clean;
  full suite 301/301, `grade` green, analyzer
  clean; CAL-001 re-ratified — async~listkey twin
  eliminated-FP, collector key 223→306, 5 pinned).
  Field acceptance pending the §5 re-run.
- R2-5 IN PROGRESS 2026-11-06 — head gates 7/7
  DONE. Gate 1: FG-BAN-018 banned symbols (TS-18
  + tc18 golden pair with fixture config;
  self-loading rule via shared walk-up discovery
  in `util.dart`; v1 glob for `except`; CLI-001a
  rule-parameters §2).
  Gate 2: FG-LOG-019 print/logger (TS-19 + tc19
  golden pair; section-presence opt-in — settled
  TC-02/TC-11 prints force silent-by-default over
  a universal ban; shared `rule_params.dart`
  self-load extraction).
  Gate 3: FG-TOK-020 theme tokens (TS-20 + direct
  golden pair; default-ON `Color` unnamed +
  channel ctors — no `Color(` in settled goldens
  or dogfood roots; `Type`/`Type.ctor` extras;
  bare/dotted creations decode without
  resolution).
  Gate 4: FG-I18N-021 i18n literals (TS-21 + tc21
  golden pair; opt-in — `Text('x')` saturates
  settled goldens; non-blank literal-text rule
  with pure-interpolation carve-out) + the
  FlatRuleConfig heal (the landing fanned
  config/entry twins to 16 pairs at up to 1.00,
  re-judged TP and healed into `runFlatRule`;
  all 8 twins verified gone).
  Gate 5: FG-ENC-022 encoding (TS-22 + direct
  golden pair; byte oracle — strict UTF-8 +
  U+FFFD/U+00C3/U+00C2 markers, one finding per
  line; the rule caught its own §2 recipe in the
  embed on first dogfood — rewritten with
  codepoint escapes).
  Gate 6: FG-ORP-023 orphans (TS-23 + tc23 golden
  trio; path oracle over generated suffixes;
  invisible to default scans by design — a
  dedicated includeGenerated test pins the
  interplay).
  Gate 7: FG-LYR-024 layers (TS-24 + tc24 golden
  tree; v1 file-scoped import/export denylists —
  allow-graph deferred with documented identity
  questions; list-rule heal into
  `RuleListConfig<T>` + `scanTarget`, residual
  entry twin FP at 0.919 with the ≥0.95-heal
  precedent recorded). Registry + recipes +
  README/LEIAME + init template wired
  throughout. Tail T1: FG-CC-025 complexity
  ceiling (TS-25 + direct golden pair, CC86
  .bad vs CCall<=80 .good; fixed ceiling 80 via
  SYS-COV-001 `analyzeComplexity`, warn-20 out —
  severity is per-rule, advisories stay with
  MET). Tail T2: FG-RIV-026 provider naming
  (TS-26 + direct golden pair, 15-finding
  .bad; warning severity — a name never breaks
  a build; positional-closure discriminator
  kills provider-package widgets without
  import resolution). Full suite 344/344,
  `grade` green, analyzer clean, dogfood 0/0;
  CAL-001 re-ratified — +1 guard-idiom FP
  (ctx~=prov @0.870, 8th of class), 10
  pinned. Tail T3: FG-LAY-004 v4 Text-in-Row
  (TS-07 amended; TC-07 pair extended
  append-only, 16 findings; 8-cell runtime
  probe on Flutter 3.47.9 — bare/rich/
  ellipsis/softWrap/maxLines/padded throw,
  Expanded/Column clean; strict, no arg
  exemption — short labels flag by design) +
  the TC-13.good:32 item-turn call (incidental
  Row+Text re-hung on Column, MET role
  preserved exactly — the narrowing floor is
  barred overfit, the single-child exemption
  is probe-contradicted, opt-in has no
  project-varying surface). Full suite
  345/345, `grade` green, analyzer clean,
  dogfood 0/0; CAL-001 re-ratified — no
  movement, 10 pinned. Tail T4: FG-ARB-027
  arb metadata (TS-27 + `.arb` golden pair,
  3 findings; quote-naive top-level-head
  scan — strict quoting would miss real
  placeholders after a `don't`; malformed
  JSON fails closed) + engine file scopes
  (`RuleAnalyzer.extensions` default
  `.dart`, per-rule gate in the check loop,
  batch filter, `collectScannableFiles`
  with registered-union collection;
  CLI-001a §2 amended). Full suite 353/353,
  `grade` green (grade needed no change —
  extension-agnostic by front-matter),
  analyzer clean, dogfood 0/0; CAL-001
  re-ratified — check~=init re-keyed
  221→233 plus +1 procedural-flow-twin FP
  (checkFiles~=_siblingImport @0.810, 4th
  of class), 11 pinned. Tail T5: FG-PII-028
  PII in logs (TS-28 + tc28 golden pair with
  fixture config, 6 findings; default-ON —
  probe-justified, no e-mail-shaped literal
  in repo and no PII sink args in settled
  vectors/dogfood; findings never echo
  literal spans; quote/adjacent runs never
  joined — no phantoms; arg labels probed
  safe). Full suite 359/359, `grade` green,
  analyzer clean, dogfood 0/0; CAL-001
  re-ratified — check~=init re-keyed
  100→107 plus +1 guard-idiom FP
  (banned~=_ArgScanner @0.807, 9th of
  class), 12 pinned. Tail T6: FG-ENV-029
  env parity (TS-29 + tc29 golden quads,
  2 findings; symmetric parity, values never
  read or echoed, missing-oracle fail-open,
  oracle never judged) + basename-prefix
  scopes (`RuleAnalyzer.namePrefixes`,
  union collection; CLI-001a §2 amended).
  Full suite 367/367, `grade` green,
  analyzer clean, dogfood 0/0; CAL-001
  re-ratified — check twins re-keyed
  111→112/233→234 plus +1 runner-pipeline
  FP (enc~=env @0.814, 6th of class), 13
  pinned. Tail T1–T6 COMPLETE (29 rules).
  Remaining: the medium list (optional
  analyze step, new-file tests,
  changed-tests selection, assets/version/
  deps/licenses/links, dart fix pre-step)
  and engine items (parallel gate report,
  per-run evidence ledger).
- R2-6 OPEN: specified (mutation wedge, needs ERP
  access per Q8).
- Recommended next: R2-5 medium list or R2-6 (needs ERP access).
- Scope broadened 2026-11-05 (§7 + Broadening notes): ERP is
  corpus #1, not the mold. Ratified 2026-11-05 (Q9).

# 7. Multi-Project Scope

FlutterGuard reads any Dart/Flutter project: the ERP is
calibration corpus #1, not the mold. No R2 item may hardcode
an ERP-only idiom without either generalizing it or hanging
it on config.

Covered project types (R2 boundary, pending Q9):

| Type | Example shape | Coverage |
|---|---|---|
| Riverpod Flutter apps | ERP-class | Full set incl. RIV/LIFE-Notifier/BUILD-Notifier packs |
| Bloc/Cubit Flutter apps | `BlocBuilder`/`BlocListener` | FG-BLOC-001 + generic core; builder scope checked in R2-3 |
| Vanilla Flutter apps | setState, no framework | Generic core only; framework rules find no targets |
| Pure Dart packages | CLIs, servers, this repo | Parse-only core (LINT/MET/imports/dup/coverage/mutation) |
| Other frameworks | GetX/Provider/MobX | Generic core in R2; packs are future work |

Standing overfit guards for R2 implementation:

- Config over hardcode: project-varying surfaces (release
  methods, banned symbols, logger, theme location, layer
  graph, thresholds) ship as `flutterguard.yaml` knobs,
  never as literals.
- Framework knowledge stays pack-local (inside the rule);
  the engine (`check`, baseline, diff, output) is
  framework-blind.
- Every new grammar ships fixtures from 2+ shapes (the ERP
  shape plus one non-ERP shape).
- §5 bars must hold on the golden vectors + dogfood (corpus
  #2: this repo) as well as on the ERP re-run.
