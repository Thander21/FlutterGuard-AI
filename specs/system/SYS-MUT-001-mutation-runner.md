---
spec_version: "openspec-1.0"
id: "SYS-MUT-001"
title: "Mutation runner (chaos gate)"
status: "approved"
kind: "system"
---

# 1. Problem

AI-written tests can be complacent: green on broken code, asserting
nothing. Coverage cannot catch them; only sabotage can. This contract
pins the mutation runner that stages a source+test pair in a volatile
sandbox (flat pair or shadow package), applies one surgical operator
mutation at a time, re-runs the test, and fails closed when the test
stays green on mutated code
(fraudulent test). Without it the `test` gate trusts whatever the agent
asserts.

# 2. Interface / Schema

Library API (`lib/src/mutation/`, exported from the package root).
No CLI command in v1; the MCP `run_mutation_check(test_file)` tool
(SYS-MCP-001) calls this API. No new dependencies.

```dart
/// One surgical mutation site (single operator or literal).
class Mutant {
  final int offset;      // 0-based offset of the site in the source
  final int line;        // 1-based line number of the site
  final String operator; // e.g. '>', '>=', '==', 'true'
  final String original;
  final String replacement;
}

/// AST-sited rewrite: every site of the 3 operators, ordered by offset.
List<Mutant> findMutants(String source, {String? path});
/// [source] with [mutant] applied (single-site replacement).
String applyMutant(String source, Mutant mutant);
/// True when [testSource] imports `package:flutter_test`.
bool usesFlutterTest(String testSource);

enum MutantStatus { killed, survived, timeout }

class MutantResult {
  final Mutant mutant;
  final MutantStatus status;
  final int exitCode; // -1 when killed by the circuit breaker
}

class MutationVerdict {
  final bool passed; // true only when every mutant was killed
  final List<MutantResult> results;
}

class MutationRunner {
  MutationRunner({
    this.timeout = const Duration(seconds: 8),
    this.pubGetTimeout = const Duration(minutes: 2),
    this.sandboxRoot = 'fixtures/mutation',
    this.testCommand,
  });
  final Duration timeout;
  final Duration pubGetTimeout;
  final String sandboxRoot;
  final List<String> Function({required bool usesFlutterTest})? testCommand;
  static List<String> defaultTestCommand({required bool usesFlutterTest});
  static List<String> defaultPubGetCommand({required bool usesFlutter});
  static const String canarySnippet;
  static const String shadowDirPrefix;
  /// Stages the pair (flat or shadow), runs the resolved test
  /// command per mutant, and classifies the outcome.
  Future<MutationVerdict> run({
    required String sourcePath,
    required String testPath,
    String? runId,
  });
}

/// Deletes abandoned shadow packages; see §2 staging.
int sweepStaleShadows({Duration olderThan = const Duration(hours: 24)});
```

The 3 operators (Architecture §2.3), AST-sited so strings, comments,
and generic type arguments are never touched:

| # | original | replacement | AST node |
|---|----------|-------------|----------|
| 1 | `>` | `<` | `BinaryExpression` |
| 1 | `>=` | `<=` | `BinaryExpression` |
| 2 | `==` | `!=` | `BinaryExpression` |
| 3 | `true` | `false` | `BooleanLiteral` (value `true` only) |

One mutant per site; mutants run independently (never combined).
Test invocation is deterministic: the resolved command over
`<sandboxTest>` plus `--concurrency=1` (ClientAgents §2 Gate 3
via SYS-CLI-001a), mutants ordered by offset, run dirs
zero-padded (`mutant_00`, …). Resolution is per staged suite:
`flutter test` when the test imports `package:flutter_test`
(AST-sited), else `dart test`; `testCommand` overrides it.

Staging is routed by package context. A source outside any package
(bare fixtures) stages as a flat sibling pair: per-mutant copies
under `<sandboxRoot>/<runId>/mutant_<nn>/`, the test copy's relative
import(s) resolving to the source rewritten to the source basename
(offset-precise, AST-sited), so every mutant dir stays self-contained.
Pair sandboxes are kept after the run for inspection (volatile,
gitignored, never cleaned automatically). A source with an enclosing
`pubspec.yaml` stages as a shadow package instead: the working tree
is copied to `<systemTemp>/fg_mut_shadow_<runId>/` (pruning `build/`,
`.dart_tool/`, `.git` at every level, skipping symlinks), `pub get`
runs once (`flutter` when the pubspec or test needs the SDK, else
`dart`), and each mutant is written in place at the source's real
shadow path — no import is ever rewritten, so relative, `package:`,
and mixed layouts all load the mutant, and the originals are never
touched. Shadows are removed after verdicts; staging failures keep
the shadow for inspection. `sweepStaleShadows` reaps abandoned
shadows (incomplete-run marker, or marker-less mid-flight copies, at
least `olderThan` old — live runs heartbeat the marker per mutant);
every shadow run sweeps first. The `dart`/`flutter` executables are
`Platform.resolvedExecutable` (`dart` fallback) and bare `flutter`
so `.bat` launchers are never spawned and the breaker can kill the
real process; test and `pub get` children run with cwd scoped to the
shadow plus package-relative paths.

Before any mutant runs, the unmutated code runs once (clean baseline:
`<runId>/baseline/` for pairs, the pristine shadow for packages). A
non-zero baseline — including a breaker timeout — aborts with
`StateError`: mutants are never judged against a red suite, and
suites the sandbox cannot load (missing `part` files, bad imports,
unresolved packages) fail fast instead of minting false `killed`
verdicts. Shadow runs add a compile canary as mutant zero
([canarySnippet], a guaranteed compile error): the test MUST fail;
a passing canary proves the mutant is not loaded and aborts with
`StateError`. After every mutant run the original is restored and
read back byte-identical; a restore mismatch aborts with
`StateError` before the next mutant.

Green-on-mutant comparator (fail-closed):

| test on mutant | status | gate |
|----------------|--------|------|
| exit 0 | `survived` | FAIL (complacent test) |
| non-zero (incl. stillborn/compile error) | `killed` | contributes to PASS |
| breaker kills the run | `timeout` | FAIL (unproven, never trusted) |

`passed` is true only when every mutant is `killed`. Zero mutants is
honest PASS with empty `results` (nothing to kill, nothing claimed).

# 3. File Placement

- `specs/system/SYS-MUT-001-mutation-runner.md` (this contract).
- `lib/src/mutation/mutant.dart` (sites + rewriter, pure, sync).
- `lib/src/mutation/runner.dart` (sandbox copy + `dart test`
  invocation + comparator; the only async unit in the package).
- `lib/flutterguard_ai.dart` (re-export both).
- `test/mutation_runner_test.dart` (contract test: rewriter units,
  canary pair complacent→FAIL / honest→PASS, timeout breaker, pair
  import guard, shadow honest→killed / complacent→survived (fake
  command) plus one real `dart test` end-to-end, canary fail-closed,
  cross-package and pubspec-less rejections, stale sweep,
  zero-mutant PASS, flutter command resolution + override seam).
- Generated at runtime: `fixtures/mutation/<runId>/mutant_<nn>/`
  (volatile, gitignored via `fixtures/`; kept after the run for
  inspection, never cleaned automatically) and
  `<systemTemp>/fg_mut_shadow_<runId>/` (removed after verdicts;
  kept on staging failure, reaped stale by `sweepStaleShadows`).

# 4. Evidence Wiring

Emits no `evidence.jsonl` in v1: the verdict object is the record,
consumed by the caller (contract test today, MCP tool in P3). Any
future `MUTATION_GATE` lines MUST amend SYS-TELE-001 before the first
emission (canon rule §4).

# 5. Errors and Edges

- Missing source/test file, or `sourcePath == testPath`: `ArgumentError`
  before any sandbox write. Non-positive `timeout`/`pubGetTimeout`:
  `ArgumentError`.
- Pair routing (no enclosing pubspec): test without a relative import
  resolving to the source: `ArgumentError` — flat copies would never
  take effect, so running would mint false `survived` verdicts.
- Shadow routing (enclosing pubspec found): test reaching the source
  neither relatively nor via `package:<name>/<lib-relative-path>`
  (a `package:` import for another file, an unparseable or nameless
  pubspec, or a source outside `lib/` never matches): `ArgumentError`.
  Test outside the source's package root: `ArgumentError` (the test
  must stage inside the shadow).
- Shadow `pub get` failure (non-zero or `pubGetTimeout` trip):
  `StateError`, shadow kept. Passing canary: `StateError`, shadow
  kept. Restore mismatch: `StateError`, shadow kept.
- Unparseable source: the analyzer yields a partial AST; valid sites
  are still mutated (same tolerance as the rule visitors).
- Breaker: `Process.start` + watchdog kill at `timeout` (default 8s,
  injectable for tests). Exit code is reported as -1, status
  `timeout`, verdict FAIL.
- Non-zero exit for any reason (assertion, exception, stillborn
  mutant): `killed`. Stillborn mutants are NOT discarded in v1
  (documented simplification: a test that cannot even load the
  mutant proved nothing either way, and counting it killed is the
  lenient side — recorded here so v2 can tighten it).
- Concurrent runs: `runId` defaults to a UTC-timestamp slug; callers
  needing isolation pass an explicit id (tests do).
- Flutter suites (`package:flutter_test` imports) run via
  `flutter test` (SYS-CAL-002 P2-2); the v1 pure-`dart test`
  bar is lifted for command selection. Widget-harness
  semantics are unchanged (exit-code comparator only).
  Shadow `pub get` uses `flutter` when the pubspec or test needs
  the SDK, so Flutter packages stage self-sufficiently.

# 6. Contradictions Resolved

- Playground resolution (PLAN-02): Architecture §6 `test_fixtures/`
  is superseded — never created. `vectors/` = golden evals
  (read-only), `fixtures/` = volatile playground (extends the
  SYS-CLI-001b §6 resolution with `fixtures/mutation/`).
- Circuit breaker (Architecture §2.5): the documented
  `Process.run(timeout:)` does not exist in the Dart API — resolved
  as `Process.start` + watchdog kill, same 8s default.
- Sandbox discipline (PLAN-01 Phase 3): mutation NEVER edits in
  place — pair mutants run on copies under `fixtures/mutation/`,
  shadow mutants on copies under the system temp dir.
- Flutter invocation (SYS-CAL-002 P2-2): the runner resolves its
  own `flutter test` per staged suite — the v1 "belongs to
  SYS-VIEW-001" bar is lifted; Backlog-113 adoption stages
  inside a flutter-capable package.
- Shadow staging (field R2-6): rewriting a `package:` import to a
  flat sibling copy is REJECTED — the rest of `lib/` would keep
  loading the original, double-loading the library and minting
  false verdicts on connected graphs (sound only for leaf files).
  Real packages stage as full working-tree copies mutated in
  place, so every import style loads the mutant.
- Worktree staging (field R2-6): a detached worktree at HEAD is
  REJECTED — agent edits are uncommitted by definition, so HEAD
  would stage stale code. The working tree itself is copied
  (including uncommitted edits), which also keeps staging
  git-independent and crash-orphans to inert temp files.
