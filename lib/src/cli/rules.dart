// Registry of implemented FlutterGuard AST rules.
//
// Each entry binds a rule id and its normative spec contract to the
// visitor that enforces it. Both `grade` and `check` run this registry,
// so adding a rule means adding one entry here.
import '../ast/bloc_emit_guard.dart';
import '../ast/controller_build_guard.dart';
import '../ast/riverpod_watch_guard.dart';
import '../ast/rule_violation.dart';

/// One implemented rule: id, spec contract path, and visitor.
class RuleAnalyzer {
  const RuleAnalyzer({
    required this.id,
    required this.spec,
    required this.analyze,
  });

  /// Stable rule id (e.g. `FG-BLOC-001`).
  final String id;

  /// Normative spec contract (relative to the repository root).
  final String spec;

  /// Visitor: analyzes [path] and returns every violation found.
  final List<RuleViolation> Function(String path) analyze;
}

/// Every rule the CLI can run. v0 ships three rules.
final ruleAnalyzers = <RuleAnalyzer>[
  RuleAnalyzer(
    id: 'FG-BLOC-001',
    spec: 'specs/TS-01-bloc-emit-guard.md',
    analyze: analyzeBlocFile,
  ),
  RuleAnalyzer(
    id: 'FG-RIV-001',
    spec: 'specs/TS-02-riverpod-watch-guard.md',
    analyze: analyzeRiverpodFile,
  ),
  RuleAnalyzer(
    id: 'FG-ST-001',
    spec: 'specs/TS-03-controller-in-build-guard.md',
    analyze: analyzeControllerBuildFile,
  ),
];
