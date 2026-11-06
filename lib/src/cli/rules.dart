// Registry of implemented FlutterGuard AST rules.
//
// Each entry binds a rule id and its normative spec contract to the
// visitor that enforces it. Both `grade` and `check` run this registry,
// so adding a rule means adding one entry here.
import '../ast/arch_layer_guard.dart';
import '../ast/async_build_guard.dart';
import '../ast/async_context_guard.dart';
import '../ast/bloc_emit_guard.dart';
import '../ast/context_scope_guard.dart';
import '../ast/controller_build_guard.dart';
import '../ast/format_guard.dart';
import '../ast/import_guard.dart';
import '../ast/lifecycle_guard.dart';
import '../ast/lint_suppression_guard.dart';
import '../ast/metric_guard.dart';
import '../ast/list_key_guard.dart';
import '../ast/list_viewport_guard.dart';
import '../ast/riverpod_watch_guard.dart';
import '../ast/state_mutation_guard.dart';
import '../ast/syntax_guard.dart';
import '../ast/widget_immutable_guard.dart';
import '../ast/rule_violation.dart';

/// One implemented rule: id, spec contract path, and visitor.
class RuleAnalyzer {
  const RuleAnalyzer({
    required this.id,
    required this.spec,
    required this.analyze,
    this.severity = 'error',
    this.severityFor,
  });

  /// Stable rule id (e.g. `FG-BLOC-001`).
  final String id;

  /// Normative spec contract (relative to the repository root).
  final String spec;

  /// Visitor: analyzes [path] and returns every violation found.
  final List<RuleViolation> Function(String path) analyze;

  /// Gate impact: `error` fails `check`, `warning` is advisory-only.
  /// The warning→error flip is owned by the rule's calibration spec.
  final String severity;

  /// Optional per-violation severity override (R2-2 warn channel):
  /// returns a severity or null to keep [severity]. The
  /// [RuleViolation] interface stays untouched (SYS-CAL-003 R2-3).
  final String? Function(RuleViolation violation)? severityFor;
}

/// Every rule the CLI can run (P0 ships four; P1 extends this list).
final ruleAnalyzers = <RuleAnalyzer>[
  RuleAnalyzer(
    id: 'FG-ARCH-003',
    spec: 'specs/TS-05-arch-layer-guard.md',
    analyze: analyzeArchFile,
  ),
  RuleAnalyzer(
    id: 'FG-ASYNC-002',
    spec: 'specs/TS-06-async-context-guard.md',
    analyze: analyzeAsyncFile,
  ),
  RuleAnalyzer(
    id: 'FG-LAY-004',
    spec: 'specs/TS-07-list-viewport-guard.md',
    analyze: analyzeListViewportFile,
  ),
  RuleAnalyzer(
    id: 'FG-ST-005',
    spec: 'specs/TS-08-state-mutation-guard.md',
    analyze: analyzeStateMutationFile,
  ),
  RuleAnalyzer(
    id: 'FG-CTX-006',
    spec: 'specs/TS-09-context-scope-guard.md',
    analyze: analyzeContextScopeFile,
  ),
  RuleAnalyzer(
    id: 'FG-WID-008',
    spec: 'specs/TS-10-widget-immutable-guard.md',
    analyze: analyzeWidgetImmutableFile,
  ),
  RuleAnalyzer(
    id: 'FG-LINT-009',
    spec: 'specs/TS-11-lint-suppression-guard.md',
    analyze: analyzeLintSuppressionFile,
  ),
  RuleAnalyzer(
    id: 'FG-KEY-001r',
    spec: 'specs/TS-12-list-key-guard.md',
    analyze: analyzeListKeyFile,
  ),
  RuleAnalyzer(
    id: 'FG-MET-007',
    spec: 'specs/TS-13-metric-guard.md',
    analyze: analyzeMetricFile,
    severity: 'warning',
  ),
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
  RuleAnalyzer(
    id: 'FG-LIFE-001',
    spec: 'specs/TS-04-life-symmetry-guard.md',
    analyze: analyzeLifecycleFile,
  ),
  RuleAnalyzer(
    id: 'FG-BUILD-014',
    spec: 'specs/TS-14-async-in-build-guard.md',
    analyze: analyzeAsyncBuildFile,
  ),
  RuleAnalyzer(
    id: 'FG-IMP-015',
    spec: 'specs/TS-15-import-guard.md',
    analyze: analyzeImportFile,
  ),
  RuleAnalyzer(
    id: 'FG-FMT-016',
    spec: 'specs/TS-16-format-guard.md',
    analyze: analyzeFormatFile,
  ),
  RuleAnalyzer(
    id: 'FG-SYN-017',
    spec: 'specs/TS-17-syntax-guard.md',
    analyze: analyzeSyntaxFile,
  ),
];
