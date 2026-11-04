---
spec_version: "openspec-1.0"
id: "SYS-COV-001"
title: "Coverage pipeline and advisory CRAP gate"
status: "approved"
kind: "system"
---

# 1. Problem

Complexity alone doesn't kill changes; untested complexity does.
`CC(m)` is parse-only and cheap, but `cov(m)` — the fraction of a
method exercised by tests — needs a real runtime pipeline
(`test --coverage` → lcov → per-method mapping). Without it the
CRAP gate from CleanCodeDeterministicGates Gate A cannot exist.
This contract pins the pipeline and ships CRAP scoring as
advisory verdicts until calibration owns the blocking flip.

# 2. Interface / Schema

Library API (`lib/src/coverage/`, exported from the package root).
No CLI command (`crap` is a superseded name, PLAN-01). One new
dev-dependency, named here per the dependency rule: `coverage`
(`format_coverage` binary).

```dart
// complexity.dart (pure, sync): McCabe CC per declaration.
class MethodComplexity {
  final String name; // Class.method or bare function name
  final int line;    // 1-based first line
  final int endLine; // 1-based last line (inclusive)
  final int complexity;
}
List<MethodComplexity> analyzeComplexity(String source, {String? path});

// lcov.dart (pure, sync): minimal SF/DA parser.
class LcovFile {
  final String path; // SF value as emitted
  final Map<int, int> lineHits; // line -> hit count
}
Map<String, LcovFile> parseLcov(String content); // keyed by raw SF

// runner.dart (async): the pipeline + CRAP scoring.
const crapThreshold = 10.0;

class MethodScore {
  final String name;
  final String file; // report-on path, forward slashes
  final int line;
  final int complexity;
  final double coverage; // 0..1
  double get crap =>
      complexity * complexity * pow(1 - coverage, 3) + complexity;
  bool get overBudget => crap >= crapThreshold && coverage < 1.0;
}

class CoverageVerdict {
  final bool passed; // advisory v1: always true
  final List<MethodScore> methods; // sorted by file, line
  final int filesScored;
}

class CoverageRunner {
  CoverageRunner({this.timeout = const Duration(seconds: 8)});
  final Duration timeout; // per subprocess hop
  Future<CoverageVerdict> run({
    required String testPath, // single test file (v1)
    required List<String> reportOn, // files or dirs to score
  });
}
```

Pipeline (`run`): `dart test <testPath> --coverage=<tmp>/raw
--concurrency=1`, then `dart run coverage:format_coverage -i
<tmp>/raw -o <tmp>/lcov.info -l --report-on <each> --package .`
(one flag per entry), then parse → AST map → score. The test
executable is `Platform.resolvedExecutable` (`dart` fallback);
each hop carries the 8s breaker (TimeoutException-free design:
`Process.start` + watchdog kill, same as SYS-MUT-001). `<tmp>` is
a system-temp run dir, deleted in a `finally` — artifacts are
fully parsed into the verdict (unlike mutation sandboxes, they
are not rerunnable repros).

Slow lane (calibration only): the `mcp/tools` trio (24s suite)
exceeds the 8s default, so `tool/calibrate.dart` runs it at a
180s/hop budget; the 8s default stands for gate-time use.
Sharding the slow suite is deferred until a gate-time consumer
needs it (no CLI runs CRAP today).

CC counting (CleanCodeDeterministicGates Gate A, base 1 McCabe;
only declarations WITH bodies are scored):

| AST | +CC |
|-----|-----|
| `IfStatement` (each `if`, incl. else-if) | +1 |
| `IfElement`, `ForElement` (branching in collection literals; concretizes the widget-bifurcation row) | +1 |
| `ForStatement` (covers for-in), `WhileStatement`, `DoStatement` | +1 |
| `SwitchCase`, `SwitchPatternCase` (each `case`; `default` never) | +1 |
| `CatchClause` | +1 |
| `&&`, `\|\|`, `??` | +1 per operator |
| `ConditionalExpression` (`?:`) | +1 |

`cov(m)`: lcov `DA` entries within `[line, endLine]`;
covered-with-hits>0 / total. Zero entries in range → `0.0`
(fail-closed: untested until proven covered). A report-on file
absent from lcov scores all its methods `0.0` (never imported =
untested).

`CRAP(m) = CC(m)^2 x (1 - cov(m))^3 + CC(m)` (both origin docs
agree). `overBudget` at `>= 10.0` with imperfect coverage is
advisory: reported, never fails. Full coverage absolves
complexity (CC-floor decision, §6): a method with proof for
every line has nothing left to cover, so only `cov < 1.0`
methods can flag. `passed` is always true in v1; the blocking
flip requires a SYS-CAL-001 amendment (same treatment as
FG-MET-007).

# 3. File Placement

- `specs/system/SYS-COV-001-coverage-crap.md` (this contract).
- `lib/src/coverage/complexity.dart` (CC visitor, pure).
- `lib/src/coverage/lcov.dart` (SF/DA parser, pure).
- `lib/src/coverage/runner.dart` (two-hop pipeline + scoring).
- `lib/flutterguard_ai.dart` (re-export).
- `samples/coverage/sample.dart` (CC 2 covered / CC 2 uncovered /
  CC 5 uncovered), `sample_test.dart` (exercises `max2` only),
  `red_test.dart` (failing suite). Committed, check-clean, outside
  `test/` so the root suite never auto-collects them.
- `test/coverage_runner_test.dart` (CC units, lcov units, formula,
  integration with exact CC/cov/CRAP on the sample, red-suite and
  argument errors).
- Runtime-only: system-temp run dirs (deleted); no repo residue.

# 4. Evidence Wiring

Emits no `evidence.jsonl` in v1: the verdict object is the record.
Any future coverage lines MUST amend SYS-TELE-001 first (canon
rule §4).

# 5. Errors and Edges

- Missing `testPath`, empty `reportOn`, missing report-on entry:
  `ArgumentError` before any subprocess.
- Red test suite (non-zero exit): `StateError` — coverage of a
  failing suite is meaningless (same doctrine as the SYS-MUT-001
  clean baseline).
- Breaker timeout on either hop: `StateError` (fail-closed).
- `format_coverage` non-zero: `StateError` with a capped stderr
  tail (last 2000 chars).
- Whole-suite runs are out of scope in v1 (single test file;
  the `test` gate already scopes runs to changed files).
- SF matching: absolute-normalized compare (no `path` dep, same
  `Uri` technique as SYS-MUT-001); `file://` URIs decoded;
  relative SF resolved against the current directory.
- The parser reads `SF`/`DA`/`end_of_record` only (`LF`/`LH`/
  `FN*`/`BR*` ignored); a malformed `DA` line throws
  `FormatException` (loud, never skipped).
- `cov(m)` is a line fraction, not branch coverage: a fully
  line-covered method with untested branches still scores 1.0
  (documented simplification; branch data is a future contract).

# 6. Contradictions Resolved

- Blocking vs calibration: the Gate A rule (`CRAP >= 10`
  FAIL-CLOSED) stands as specified, but its ENFORCEMENT is
  deferred — v1 is advisory (`passed` always true, `overBudget`
  flags) because blocking on uncalibrated thresholds is barred
  (REVIEW-01 §3.9). The flip is owned by SYS-CAL-001.
- CC-floor decision (CAL-001 design question, answered v2):
  coverage absolves — `overBudget` requires `cov < 1.0`
  alongside `crap >= 10`. Flagging fully covered methods
  produced only FPs (`bagJaccard`, `_checkDepth` at cov 1.0
  had nothing left to cover); the gate's purpose is untested
  complexity (a CC3/cov0 method still flags). The `crap`
  formula itself is unchanged; only the budget flag narrows.
- `flutterguard crap` / `dryer` command names are superseded
  (PLAN-01) → library API only, no CLI surface.
- The widget-bifurcation CC row ("nested widget with state
  decision in `build()`") has no node classifier as stated →
  concretized as `IfElement`/`ForElement` +1 (branching inside
  declarative collection literals, the checkable form).
- CC base is 1 (McCabe; the docs state increments only).
- `samples/` placement: committed, never-collected fixtures live
  here — `fixtures/` is gitignored-volatile, `benchmark/` is
  golden evals, `test/` auto-collects. New convention recorded
  here, not in conflict with any placement rule.
