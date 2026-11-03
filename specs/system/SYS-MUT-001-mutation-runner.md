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
pins the mutation runner that copies a source+test pair into a volatile
sandbox, applies one surgical operator mutation at a time, re-runs the
test, and fails closed when the test stays green on mutated code
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
    this.sandboxRoot = 'fixtures/mutation',
  });
  final Duration timeout;
  final String sandboxRoot;
  /// Copies [sourcePath]+[testPath] per mutant into the sandbox, runs
  /// `dart test --concurrency=1` on each, and classifies the outcome.
  Future<MutationVerdict> run({
    required String sourcePath,
    required String testPath,
    String? runId,
  });
}
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
Test invocation is deterministic: `dart test <sandboxTest>
--concurrency=1` (ClientAgents §2 Gate 3 via SYS-CLI-001a), mutants
ordered by offset, run dirs zero-padded (`mutant_00`, …).

Before any mutant runs, the unmutated pair runs once in
`<runId>/baseline/` (clean baseline). A non-zero baseline — including a
breaker timeout — aborts with `StateError`: mutants are never judged
against a red suite, and fixtures the sandbox cannot load (missing
`part` files, bad imports) fail fast instead of minting false
`killed` verdicts. Sandbox copies are siblings: the test copy's
relative import(s) resolving to the source are rewritten to the source
basename (offset-precise, AST-sited), so any relative layout works and
every mutant dir stays self-contained. The test executable is
`Platform.resolvedExecutable` (`dart` fallback) so `.bat` launchers
are never spawned and the breaker can kill the real process.

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
  canary pair complacent→FAIL / honest→PASS, timeout breaker,
  relative-import guard, zero-mutant PASS).
- Generated at runtime: `fixtures/mutation/<runId>/mutant_<nn>/`
  (volatile, gitignored via `fixtures/`; kept after the run for
  inspection, never cleaned automatically).

# 4. Evidence Wiring

Emits no `evidence.jsonl` in v1: the verdict object is the record,
consumed by the caller (contract test today, MCP tool in P3). Any
future `MUTATION_GATE` lines MUST amend SYS-TELE-001 before the first
emission (canon rule §4).

# 5. Errors and Edges

- Missing source/test file, or `sourcePath == testPath`: `ArgumentError`
  before any sandbox write.
- Test does not relatively import the source (only `package:` or no
  import): `ArgumentError` — sandbox copies would never take effect,
  so running would mint false `survived` verdicts.
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
- Flutter widget tests are out of scope in v1 (pure `dart test`
  only); `flutter test` invocation belongs to SYS-VIEW-001.

# 6. Contradictions Resolved

- Playground resolution (PLAN-02): Architecture §6 `test_fixtures/`
  is superseded — never created. `vectors/` = golden evals
  (read-only), `fixtures/` = volatile playground (extends the
  SYS-CLI-001b §6 resolution with `fixtures/mutation/`).
- Circuit breaker (Architecture §2.5): the documented
  `Process.run(timeout:)` does not exist in the Dart API — resolved
  as `Process.start` + watchdog kill, same 8s default.
- Sandbox discipline (PLAN-01 Phase 3): mutation NEVER edits in
  place — every mutant runs on copies under `fixtures/mutation/`.
