---
spec_version: "openspec-1.0"
id: "SYS-CAL-002"
title: "Field calibration: ERP pilot findings and remediation"
status: "draft"
kind: "system"
---

# 1. Problem

The first field pilot ran `check` (commit `e07b523`) against the real
ERP `lib/` that originated this project: 694 files, zero ERP-side
changes, no `init`. The pilot's verdict: the tool currently brings no
net gain to the ERP, and `init` would actively harm its governance.

Measured outcome:

- 440/694 files (63%) unparseable: the ERP uses Dart 3.13 primary
  constructors while the tool pins `analyzer: ^6.0.0` (Dart 3.3-era
  grammar). No rule runs on those files; the residue is 2,587
  FG-SYN-017 findings that indicate no defect.
- FG-FMT-016 crashes on Windows: one `dart format` process carries all
  files on a single command line, exceeding the OS argument limit.
- On the 254 readable files, every sampled finding is a false
  positive across four rules (Riverpod idioms, `ref.onDispose`,
  `Notifier.build`, a `context:` String label), plus generated-file
  noise (`*.g.dart`, `generated/l10n`) on three more rules.
- The one real signal (three empty `catch (_) {}` in
  `connection_io.dart`) sits in files the tool cannot parse.
- `init` conflicts with ERP governance (hook ownership, AGENTS.md,
  MCP scope, blanket `// ignore:` ban vs 45 justified ignores).
- The mutation runner — the one component attacking a real gap
  (Backlog 113, manual mutation testing) — shares the old-analyzer
  parse path and runs `dart test` only, excluding `flutter_test`
  suites.

This spec verifies each claim against the repository (§2) and charters
the remediation program in the pilot's recommended order (§3). Nothing
here changes rule semantics until each item's acceptance bar is met;
rule-behavior changes amend their owning TS contracts.

# 2. Evidence Verification (Claim-by-Claim)

Ambient SDK at verification: Dart 3.13.7 stable on Windows x64.

## 2.1 Analyzer grammar gap — CONFIRMED

`pubspec.yaml` pins `analyzer: ^6.0.0` with `sdk: ^3.4.0`. Every guard
parses via `parseString` (e.g. `lib/src/ast/syntax_guard.dart`), so a
file using post-3.3 grammar fails to parse and
`lib/src/ast/syntax_guard.dart` (`analyzeSyntaxFile`) converts each
parser diagnostic into a FG-SYN-017 finding. The 2,587 SYN-017
findings are therefore parser-version noise, not defects, and all 17
rules silently skip those files (per-file exceptions in
`lib/src/cli/check.dart` `analyzeFilesWithRules` land in `errors`,
not `findings`).

## 2.2 FG-FMT-016 Windows crash — CONFIRMED

`lib/src/ast/format_guard.dart` `analyzeFormatBatch` spawns exactly
one `dart format --output=none --set-exit-if-changed` with `...files`,
and `lib/src/cli/check.dart` `checkPath` calls it once with the whole
file list. With hundreds of files the single command line exceeds the
Windows limit ("file name too large"); the failure lands as one
`CheckError` on the target and no file gets a format verdict.

## 2.3 FG-RIV-001 vs Riverpod idioms — CONFIRMED

`lib/src/ast/riverpod_watch_guard.dart` `visitFunctionExpression`
treats ANY function expression whose parent is an `ArgumentList` or
`NamedExpression` as an event callback
(`lib/src/ast/riverpod_watch_guard.dart:53-59`). `Provider((ref) =>
ref.watch(...))` and `overrideWith((ref) ...)` are exactly that shape,
so idiomatic provider builders are flagged. TS-02 §3 already documents
this as a known v0 limitation ("may false-positive"); the pilot
confirms it fires on normal Riverpod code (92 findings, 23 files).

## 2.4 FG-LIFE-001 vs ref.onDispose — CONFIRMED

`lib/src/ast/lifecycle_guard.dart` records releases only when the
enclosing method is literally named `dispose`
(`lib/src/ast/lifecycle_guard.dart:109,184`). `ref.onDispose(...)`
registrations inside `Notifier.build` are invisible, so Riverpod
resources with correct cleanup are flagged.

## 2.5 FG-BUILD-014 vs Notifier.build — CONFIRMED

`lib/src/ast/async_build_guard.dart` `_isMeasured` returns true for
ANY method named `build` without checking the enclosing class or
return type (`lib/src/ast/async_build_guard.dart:172-176`), and
`_invocationTrigger` flags `Future.microtask` as a trigger
(`lib/src/ast/async_build_guard.dart:145-147`). `Notifier.build` —
where deferred work is intentional — is therefore measured as widget
build scope.

## 2.6 FG-ASYNC-002 vs `context:` label — CONFIRMED (executed probe)

`lib/src/ast/async_context_guard.dart` `_SinkCollector` flags every
`SimpleIdentifier` named `context` except declarations, method names,
and `.mounted` receivers — named-argument `Label` identifiers are not
excluded. Probe (kept out of tree, `/tmp/fg_probe_async.dart`):
`await fetch(); log(context: 'sessao do usuario');` yields
`line 7: BuildContext used after async gap without mounted check`.
A `String`-valued label is indistinguishable from a `BuildContext`
read to this guard.

## 2.7 Generated-file noise — CONFIRMED

`lib/src/util.dart` `collectDartFiles`/`_walkDir` collects every
`.dart` file with no exclusion for `*.g.dart`, `*.freezed.dart`,
`generated/`, or l10n output. FG-MET-007 (advisory), FG-LINT-009, and
FG-CTX-006 findings on generated code are therefore expected.

## 2.8 Empty-catch scope — NUANCE (ERP-side, not a tool bug)

The report's `validate_catch_all` is an ERP-side validator, not a
FlutterGuard rule. FG-LINT-009 (`lib/src/ast/lint_suppression_guard.dart`
`visitCatchClause`) already flags empty catches anywhere with NO path
restriction — `catch (_) {}` (zero statements) satisfies the
`every(...)` predicate. The `connection_io.dart` catches were missed
only because those files do not parse under analyzer 6. The analyzer
upgrade (§3 P0-1) surfaces them automatically; no LINT-009 logic change
is needed for this item.

## 2.9 `init` governance conflicts — CONFIRMED with nuances

- Hook: `lib/src/cli/init.dart` always writes `.git/hooks/pre-commit`
  (refuses foreign hooks fail-closed with exit 1 — it would not
  clobber `commit-check`, but it errors and leaves the project
  half-initialized).
- AGENTS.md: written ONLY with `--init --agents` (default prints the
  mandate); the report overstates the default, but the appended mandate
  ("No task is done while `check` reports violations") still conflicts
  with ERP governance when the flag is used.
- MCP: `mcp_config.json` at repo root is written ONLY with `--mcp`
  (`lib/src/mcp/client_config.dart`); ERP policy is local-scope MCP,
  so a repo-root config file is the wrong scope by construction.
- `// ignore:` ban: FG-LINT-009 flags EVERY `ignore:` /
  `ignore_for_file:` with no justification exception, against 45 ERP
  justified ignores. Confirmed.

## 2.10 Mutation runner limits — CONFIRMED

`lib/src/mutation/runner.dart` hardcodes `dart test`
(`lib/src/mutation/runner.dart:152-159`): `flutter_test` suites
cannot run. `_siblingImport` parses the test file with the same
analyzer-6 `parseString` (`lib/src/mutation/runner.dart:168`), so
tests using newer grammar fail staging too.

## 2.11 Overlap with typed lints — ACCEPTED as positioning input

The ERP-side equivalence table (use_build_context_synchronously,
layer rules, complexity/layout validators, must_be_immutable,
format+analyze in validate) is plausible on its face: parse-only
guards cannot beat type-aware lints on their home ground. The tool's
differentiators are the canonical §2 recipes, the uniform gate, and
mutation testing — not re-implementing typed checks. Only FG-ST-001,
FG-ST-005, and FG-KEY-001r have no ERP equivalent, and none fired on
the readable corpus.

# 3. Remediation Program

Order follows the pilot's recommendation. Each item amends its owning
contract (TS or SYS) when behavior changes; each ships with golden
vectors or regression tests plus a spec diff.

## P0-1. Analyzer upgrade to a Dart 3.13 grammar (resolves 63% alone) — DONE 2026-11-05

- Bump `analyzer` to the release whose grammar covers the ERP's SDK
  (primary constructors), moving the `sdk:` constraint as required;
  re-pin `pubspec.lock`.
- Acceptance: a primary-constructor fixture
  (`new(this._ref);` shape per `setup_service.dart:29`,
  `bootstrap.dart:62`) parses with zero diagnostics; the full guard
  suite runs green on it; existing golden vectors stay green;
  `connection_io.dart`-shaped empty catches are flagged by
  FG-LINT-009 on a parseable fixture.
- Note: the upgrade may unblock `dart_style` 3.x (see the dependency
  comment in `lib/src/ast/format_guard.dart:9-10`); evaluate, do not
  assume.
  Resolution (implemented): `analyzer: ^14.0.0` (resolved
  14.7.0), `sdk: ^3.13.0` (floor forced by the analyzer). API
  migration, all mechanical, zero semantic changes:
  `NamedType.name2`→`name` (Token), `Class.members`→
  `body.members`, declaration `name`→`namePart.typeName`,
  `Extension.extendedType`→`onClause?.extendedType`,
  `NormalFormalParameter`→`FormalParameter`,
  `NamedExpression`→`NamedArgument` (Token `name` +
  `argumentExpression`), `Argument`≠`Expression` retyping,
  `errorCode.name`→`diagnosticCode.lowerCaseName` (SYN-017
  code spelling now lowercase). Primary-ctor fixture: 3
  parse errors → 0. Side effect: the language-floor move
  switched the repo to the tall formatter style; 78 files
  reformatted, golden-vector line pins re-verified
  construct-by-construct, SYS-CAL-001 re-ratified (depth key
  `:32`→`:29`, one guard-idiom DRY pair eliminated by the
  token change, 4 pairs pinned, CRAP 3/0/0 re-measured).
  `dart_style` evaluated and rejected again: a second
  formatting implementation can skew from the ambient SDK
  (TS-16, SYS-CLI-001a §6 amended).

## P0-2. Batch FG-FMT-016 invocations — DONE 2026-11-05

- Split `analyzeFormatBatch` into bounded batches (fixed file count
  per spawn, sized under the Windows command-line limit with margin),
  merging verdicts across batches; keep the `{0, 1, 65}` verdict
  semantics and the unmappable-output `StateError` per batch.
- Amends: `specs/TS-16-format-guard.md`.
- Acceptance: `check` over a 700-file fixture completes on Windows
  with per-file verdicts; a mixed clean/dirty batch maps every
  `Changed` line to the right file.
  Resolution (implemented): fixed 50 files/spawn
  (`formatBatchSize`, pinned by test), merged verdicts in
  input order, per-chunk `{0, 1, 65}` semantics; `batchSize`
  seam pins multi-chunk merging (TS-16 amended).

## P0-3. Exclude generated files from `check` — DONE 2026-11-05

- `collectDartFiles` (and the lite loop sharing it) MUST skip, by
  default: `*.g.dart`, `*.freezed.dart`, `*.gr.dart`,
  paths under `generated/` and `gen/`, and Flutter l10n output
  (`flutter_gen/`, `*.arb`-adjacent `app_localizations*.dart` —
  enumerate exactly in the owning spec).
- Add an opt-in flag (`--include-generated`) for the rare audit that
  wants them.
- Amends: `specs/system/SYS-CLI-001a-check.md`.
- Acceptance: the pilot's 103 generated-file findings class goes to
  zero on an equivalent fixture set.
  Resolution (implemented): default skip for `*.g.dart`,
  `*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`,
  `app_localizations*.dart`, and `generated/`/`gen/`/
  `flutter_gen/` subtrees (`isGeneratedDartFile`); an
  explicitly targeted single generated file also scans zero
  files; `--include-generated` / `includeGenerated: true`
  opts in (SYS-CLI-001a amended).

## P1-1. FG-RIV-001: provider builders are not event callbacks — DONE 2026-11-05

- A function expression that is the builder argument of a provider
  factory MUST NOT count as a callback: callee names
  `Provider`, `FutureProvider`, `StreamProvider`, `StateProvider`,
  `NotifierProvider`, `AsyncNotifierProvider`, `StateNotifierProvider`,
  `ChangeNotifierProvider`, `FutureProviderFamily`,
  `StreamProviderFamily`, `ProviderFamily` (exact set ratified in the
  TS-02 amendment), plus `.overrideWith(...)` / `.overrideWithValue`
  builder forms.
- Parse-only implementation: when the `FunctionExpression`'s
  `ArgumentList` parent belongs to an invocation/creation whose
  name is in the factory set, do not increment callback depth.
- Amends: `specs/TS-02-riverpod-watch-guard.md` (+ golden vectors:
  provider-builder `.good`, `onTap`-watch `.bad` stays bad).
- Acceptance: the pilot's 92-findings pattern reproduces zero on an
  idiomatic Riverpod fixture while true callback watches still flag.
  Resolution (implemented): factory set `Provider`,
  `FutureProvider`, `StreamProvider`, `StateProvider`,
  `NotifierProvider`, `AsyncNotifierProvider`,
  `StateNotifierProvider`, `ChangeNotifierProvider` (bare,
  prefixed, explicit `new`/`const`), `X.family` on a factory,
  `x.overrideWith` (any target). Corrections to the draft
  above: families construct via `.family` (no `*Family`
  callee classes exist); `overrideWithValue` takes a value,
  not a builder — no exclusion (TS-02 amended).

## P1-2. FG-LIFE-001: honor `ref.onDispose` — DONE 2026-11-05

- `ref.onDispose(() => resource.dispose()/cancel())` closures and
  `ref.onDispose(resource.dispose)` / `.cancel` tear-offs MUST count
  as releases for the named receiver, regardless of enclosing method
  name (Notifier has no `dispose()`).
- Amends: `specs/TS-04-life-symmetry-guard.md` (+ vectors).
- Acceptance: `pdv_provider.dart:90` / `boot_resolver_io.dart:47`
  shapes (onDispose-registered resources) are clean; genuinely
  unreleased fields still flag.
  Resolution (implemented): `ref.onDispose` closures run with
  full dispose semantics (nested scanner: releases + listener
  pairing, any method); `f.dispose`/`.cancel` tear-offs
  (plain and `this.`-qualified) release the receiver; bare
  `ref` target required (TS-04 amended).

## P1-3. FG-BUILD-014: measure widget builds, not `Notifier.build` — DONE 2026-11-05

- A method named `build` is EXCLUDED from build scope when its
  enclosing class extends a Riverpod notifier (`Notifier`,
  `AsyncNotifier`, family/auto-dispose variants — exact set
  ratified in the TS-14 amendment); everything else stays
  measured. Negative list (not a widget-superclass positive
  list): the ERP's intermediate widget bases would silently
  drop out of measurement under a positive match (FP→FN
  regression). Track enclosing-class context in the guard.
- Amends: `specs/TS-14-async-in-build-guard.md` (+ vectors).
- Acceptance: Notifier-build fixture clean; widget-build
  fire-and-forget still flags.
  Resolution (implemented): `build` excluded when the
  enclosing class directly extends the 8-type notifier set
  (`Notifier`, `AsyncNotifier`, `FamilyNotifier`,
  `FamilyAsyncNotifier`, 4 auto-dispose variants); scope
  stack carries the enclosing class captured at entry (local
  classes cannot shift attribution); indirect subclasses
  stay measured, documented as known FP (TS-14 amended).

## P1-4. FG-ASYNC-002: named-argument labels are not context reads — DONE 2026-11-05

- A `SimpleIdentifier` whose parent is a `Label` (named-argument
  label position, e.g. `context: '...'`) MUST NOT be a sink.
- Amends: `specs/TS-06-async-context-guard.md` (+ regression vector
  from the §2.6 probe).
- Acceptance: the probe file is clean; post-await `BuildContext`
  reads and bare-`context` identifiers still flag.
  Resolution: NO lib change needed — P0-1 resolved it. In
  analyzer 14, argument labels (`NamedArgument.name`) and
  statement labels (`Label.name`) are Tokens, not
  identifiers: no sink exists (verified empirically; a
  `_isLabel` check would be dead code). Kept as regression
  coverage: the pilot's named-arg shape in TC-06.good plus
  a statement-label unit fixture (TS-06 amended).

## P1-5. FG-LINT-009: justified suppressions — DONE 2026-11-05

- Define a "justified suppression" (trailing rationale on the
  `// ignore:` line, exact grammar ratified in the TS-11 amendment);
  bare suppressions stay errors, justified ones go clean (or
  advisory — decided in the amendment).
- Amends: `specs/TS-11-lint-suppression-guard.md` (+ vectors).
- Acceptance: the ERP's 45-ignore pattern (ignore + justification)
  is clean on fixtures; bare `// ignore: x` still flags.
  Resolution (implemented): justified = trailing `//` after
  the directive with non-blank text (same-line only);
  bare (incl. empty `//`) stays error; violation message
  points at the justified form; embedded recipe re-synced
  via `tool/embed_recipes.dart` (TS-11 amended). If the
  ERP's convention uses another separator, the re-pilot
  will surface it — grammar extends then.

## P2-1. `init` coexistence flags — DONE 2026-11-05

- `--no-hook`: skip hook installation (for `commit-check`-owned
  repos); `--hook-command=<cmd>`: wrap the project's own gate
  command instead of `check .`.
- `--agents=print|append` made explicit (print stays default);
  append keeps the marker guard.
- MCP scope: RESOLVED — keep repo-root; ERP adoption skips
  `--mcp` (no code change).
- Amends: `specs/system/SYS-CLI-001b-init-hook.md`,
  `specs/system/SYS-MCP-001-mcp-server.md`.
- Acceptance: `init --no-hook` on a `commit-check`-owned repo exits
  0, writes only `flutterguard.yaml`, touches neither the hook nor
  AGENTS.md nor MCP configs.
  Resolution (implemented): `--no-hook` skips the hook step
  (no `.git` required, exit 0); `--hook-command=<cmd>` writes
  a marker-guarded delegating hook (`exec <cmd>` verbatim,
  idempotent reinstall); `--no-hook` + `--hook-command` and
  empty `--hook-command` are usage errors (exit 2, nothing
  written). Deviation: `--agents` stays boolean (append) —
  print-by-default/append-opt-in already matches the draft;
  explicitness delivered via usage text (SYS-CLI-001b
  amended).

## P2-2. Mutation runner: `flutter test` path — DONE 2026-11-05

- Detect `flutter_test` imports in the staged test and run
  `flutter test` for those pairs (keeping `dart test` for pure-Dart
  pairs); make the test command overridable; the analyzer bump
  (P0-1) fixes `_siblingImport` staging for newer grammar.
- Amends: `specs/system/SYS-MUT-001-mutation-runner.md`.
- Acceptance: a `flutter_test`-based pair judges mutants end to end;
  pure-Dart pairs keep the `dart test` path. This is the Backlog-113
  adoption wedge: land it before any AST-rule rollout.
  Resolution (implemented): per-suite detection
  (`usesFlutterTest`, AST-sited) → `flutter test` vs `dart
  test`; `testCommand` override seam (empty resolves to
  fail-fast `StateError`); flutter path proven without a
  Flutter SDK via a capturing fake executable; constraint
  documented: flutter staging must point `sandboxRoot`
  inside a flutter-capable package (SYS-MUT-001 amended,
  v1 out-of-scope bar lifted).

## P3-1. Overlap positioning and selective adoption — DONE 2026-11-05

- Publish the rule↔typed-lint equivalence table (from §2.11) in the
  README/docs; add per-rule toggles to `flutterguard.yaml` so a
  project can enable only the non-overlapping rules (FG-ST-001,
  FG-ST-005, FG-KEY-001r) plus the gate it lacks.
- Amends: `specs/system/SYS-CLI-001a-check.md` (config schema v2).
- Acceptance: a config enabling only the three novel rules runs
  clean-or-actionable on the ERP corpus.
  Resolution (implemented): schema v2 (`version: 2`, flat
  `rules:` id→bool map + `all` default for allow-listing;
  absent/non-bool/unknown/broken all default to enabled so
  the gate never silently shrinks); walk-up discovery from
  the target; `check` (immediate + batched paths), lite
  loop, and the MCP check tool honor toggles; `grade`
  always runs the full registry. `init` writes v2 with a
  commented example. Equivalence table (17 rules, verified
  ids) published in README + LEIAME (SYS-CLI-001a §2/§5
  and SYS-CLI-001b §2 amended; `yaml` added as a direct
  dependency).

# 4. Open Questions (for review before implementation)

1. Analyzer target: exact `analyzer` + `sdk` floor (whatever release
   covers Dart 3.13 grammar; verify guard-API compatibility —
   `parseString`, `RecursiveAstVisitor`, `errorCode.name` — and the
   `precedingComments` dynamic walk in FG-LINT-009).
   RESOLVED 2026-11-05: analyzer ^14.0.0 (14.7.0), sdk
   ^3.13.0; full API map verified by trial upgrade (see the
   P0-1 resolution).
2. MCP scope: is a user/local-scope registration acceptable to
   SYS-MCP-001 ("never written outside the root"), or does ERP
   adoption simply skip `--mcp`?
   RESOLVED 2026-11-05: keep repo-root; ERP adoption skips
   `--mcp` (no code change; decided with user).
3. FG-LINT-009 justified form: clean or advisory? Exact justification
   grammar (trailing `// reason`, `, reason:` — pick one).
   RESOLVED 2026-11-05: justified (trailing text on the
   line) = clean; bare = error (decided with user; exact
   grammar ratified in the TS-11 amendment at P1 time).
4. FMT batch size: fixed file count (e.g. 50) or command-line byte
   budget? Byte budget is robust to long paths; count is simpler.
   RESOLVED 2026-11-05: fixed 50 (implemented, P0-2).
5. Pilot re-run access: who re-runs `check` on the ERP corpus after
   P0+P1, and is a redacted finding sample available for FP review?
   OPEN — needed before the §5 re-run.

# 5. Acceptance (pilot re-run bar)

After P0+P1 land, re-run the identical pilot (`check` on ERP `lib/`):

- Parse coverage: unparseable-file rate < 1% (from 63%).
- FG-FMT-016: completes on Windows with per-file verdicts.
- False positives: sampled findings review at ≈ 0 FP on the
  previously-failing patterns (§2.3–§2.7); any residual FP opens a
  named amendment here before adoption is reconsidered.
- True positive: the three `connection_io.dart` empty catches are
  flagged (FG-LINT-009).
- Adoption order on green: mutation runner tied to Backlog 113
  first; AST rules only after, and only the non-overlapping set
  (§3 P3-1) unless the ERP asks for more.

Until that bar is met, the pilot's recommendation stands: do not
install, do not run `init` on the ERP; fix the three empty catches
out of band.

# 6. Implementation Status (2026-11-05)

- P0-1 DONE: analyzer 14.7.0, sdk ^3.13.0; tall-style reformat;
  SYS-CAL-001 re-ratified; suite 233 green at P0-1 close.
- P0-2 DONE: bounded FMT batches, 50 files/spawn (TS-16 amended).
- P0-3 DONE: generated exclusion + `--include-generated`
  (SYS-CLI-001a amended).
- P0 close: full suite 237/237 green, `dart analyze
  --fatal-infos` clean on the CI scope, `grade` golden-eval
  loop all-pass (evidence restored, tree unpolluted).
- P1–P3 OPEN: specified and clarified (Q1–Q4 resolved, P1-3
  switched to a negative list); Q5 (re-run access) still
  open. Recommended next: P1 rule fixes, then the §5 re-run.
- P1 DONE 2026-11-05: all five rule fixes landed, each RED→GREEN
  with vector + test + TS amendment (P1-4 needed no lib change:
  resolved by P0-1). P1 close: full suite 239/239 green,
  `dart analyze --fatal-infos` clean, `grade` all-pass.
- P2–P3 OPEN: `init` coexistence flags (MCP: no change per Q2),
  mutation `flutter test` path, overlap positioning + per-rule
  toggles. Recommended next: P2, then the §5 re-run (needs Q5).
- P2 DONE 2026-11-05: `init` coexistence flags + mutation
  `flutter test` path, each with tests + spec amendment.
  SYS-CAL-001 re-ratified again (P1+P2 growth dissolved 2
  DRY pairs, surfaced 1 runner-pipeline FP; 3 pairs pinned).
  P2 close: full suite 247/247 green, `dart analyze
  --fatal-infos` clean, `grade` all-pass (34 evidence lines,
  9 canon keys verified, tree restored).
- P3 OPEN: rule↔lint equivalence table + per-rule
  `flutterguard.yaml` toggles. Then the §5 re-run (needs Q5:
  ERP corpus access + redacted FP sample).
- P3 DONE 2026-11-05: schema v2 + toggles + equivalence
  table (README/LEIAME). P3 close: full suite 254/254
  green, `dart analyze --fatal-infos` clean, `grade`
  all-pass (34 evidence lines, tree restored).
- SYS-CAL-002 IMPLEMENTATION COMPLETE (P0+P1+P2+P3). §5
  re-run is the remaining step: needs Q5 (ERP corpus access
  + redacted FP sample). Bar: <1% unparseable, ≈0 FP on
  the pilot patterns, 3 connection_io catches flagged,
  mutation-first adoption via Backlog 113.
