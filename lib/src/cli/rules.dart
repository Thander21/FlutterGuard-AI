// Registry of implemented FlutterGuard AST rules.
//
// Each entry binds a rule id and its normative spec contract to the
// visitor that enforces it. Both `grade` and `check` run this registry,
// so adding a rule means adding one entry here.
import '../ast/arch_layer_guard.dart';
import '../ast/arb_guard.dart';
import '../ast/asset_guard.dart';
import '../ast/async_build_guard.dart';
import '../ast/async_context_guard.dart';
import '../ast/banned_symbol_guard.dart';
import '../ast/bloc_emit_guard.dart';
import '../ast/complexity_guard.dart';
import '../ast/context_scope_guard.dart';
import '../ast/print_logger_guard.dart';
import '../ast/controller_build_guard.dart';
import '../ast/doc_guard.dart';
import '../ast/encoding_guard.dart';
import '../ast/env_guard.dart';
import '../ast/format_guard.dart';
import '../ast/i18n_guard.dart';
import '../ast/import_guard.dart';
import '../ast/layer_guard.dart';
import '../ast/lifecycle_guard.dart';
import '../ast/lint_suppression_guard.dart';
import '../ast/metric_guard.dart';
import '../ast/list_key_guard.dart';
import '../ast/orphan_guard.dart';
import '../ast/pii_guard.dart';
import '../ast/provider_naming_guard.dart';
import '../ast/list_viewport_guard.dart';
import '../ast/riverpod_watch_guard.dart';
import '../ast/state_mutation_guard.dart';
import '../ast/sync_jank_guard.dart';
import '../ast/syntax_guard.dart';
import '../ast/test_presence_guard.dart';
import '../ast/theme_token_guard.dart';
import '../ast/version_guard.dart';
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
    this.extensions = const {'.dart'},
    this.namePrefixes = const {},
    this.names = const {},
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

  /// File extensions this rule reads (default: Dart only).
  /// The check loop never feeds a rule a file outside its scope,
  /// so Dart visitors never parse `.arb` catalogs and vice versa.
  final Set<String> extensions;

  /// Basename prefixes this rule reads (default: none; dotfiles
  /// like `.env*` carry no matchable extension).
  final Set<String> namePrefixes;

  /// Exact basenames this rule reads (default: none; singletons
  /// like `pubspec.yaml` match neither an extension nor a prefix).
  final Set<String> names;

  /// True when [file] is in this rule's scope.
  bool scopes(String file) {
    if (extensions.any(file.endsWith)) return true;
    if (namePrefixes.isEmpty && names.isEmpty) return false;
    final base = file.replaceAll(r'\', '/').split('/').last;
    if (names.contains(base)) return true;
    return namePrefixes.any(base.startsWith);
  }
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
    severityFor: (violation) =>
        violation is LintSuppressionViolation && violation.isCommentOnly
        ? 'warning'
        : null,
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
  RuleAnalyzer(
    id: 'FG-BAN-018',
    spec: 'specs/TS-18-banned-symbol-guard.md',
    analyze: analyzeBannedSymbolFile,
  ),
  RuleAnalyzer(
    id: 'FG-LOG-019',
    spec: 'specs/TS-19-print-logger-guard.md',
    analyze: analyzeLogFile,
  ),
  RuleAnalyzer(
    id: 'FG-TOK-020',
    spec: 'specs/TS-20-theme-token-guard.md',
    analyze: analyzeTokFile,
  ),
  RuleAnalyzer(
    id: 'FG-I18N-021',
    spec: 'specs/TS-21-i18n-guard.md',
    analyze: analyzeI18nFile,
  ),
  RuleAnalyzer(
    id: 'FG-ENC-022',
    spec: 'specs/TS-22-encoding-guard.md',
    analyze: analyzeEncFile,
  ),
  RuleAnalyzer(
    id: 'FG-ORP-023',
    spec: 'specs/TS-23-orphan-guard.md',
    analyze: analyzeOrpFile,
  ),
  RuleAnalyzer(
    id: 'FG-LYR-024',
    spec: 'specs/TS-24-layer-guard.md',
    analyze: analyzeLayerFile,
  ),
  RuleAnalyzer(
    id: 'FG-CC-025',
    spec: 'specs/TS-25-complexity-guard.md',
    analyze: analyzeCcFile,
  ),
  RuleAnalyzer(
    id: 'FG-RIV-026',
    spec: 'specs/TS-26-provider-naming-guard.md',
    analyze: analyzeProviderNamingFile,
    severity: 'warning',
  ),
  RuleAnalyzer(
    id: 'FG-ARB-027',
    spec: 'specs/TS-27-arb-guard.md',
    analyze: analyzeArbFile,
    extensions: const {'.arb'},
  ),
  RuleAnalyzer(
    id: 'FG-PII-028',
    spec: 'specs/TS-28-pii-guard.md',
    analyze: analyzePiiFile,
  ),
  RuleAnalyzer(
    id: 'FG-ENV-029',
    spec: 'specs/TS-29-env-guard.md',
    analyze: analyzeEnvFile,
    extensions: const {},
    namePrefixes: const {'.env'},
  ),
  RuleAnalyzer(
    id: 'FG-ASSET-030',
    spec: 'specs/TS-30-asset-guard.md',
    analyze: analyzeAssetFile,
    extensions: const {},
    names: const {'pubspec.yaml'},
  ),
  RuleAnalyzer(
    id: 'FG-VER-031',
    spec: 'specs/TS-31-version-guard.md',
    analyze: analyzeVersionFile,
    extensions: const {},
    names: const {'pubspec.yaml'},
  ),
  RuleAnalyzer(
    id: 'FG-DOC-032',
    spec: 'specs/TS-32-doc-guard.md',
    analyze: analyzeDocFile,
    extensions: const {'.md'},
  ),
  RuleAnalyzer(
    id: 'FG-TST-033',
    spec: 'specs/TS-33-test-presence-guard.md',
    analyze: analyzeTstFile,
  ),
  RuleAnalyzer(
    id: 'FG-SYNC-034',
    spec: 'specs/TS-34-sync-jank-guard.md',
    analyze: analyzeSyncJankFile,
  ),
];

/// Extension union over the registry: every file kind some rule
/// reads. `check` collects exactly this set, so a newly registered
/// scope joins the walk with no collection change.
Set<String> get registeredExtensions => {
  for (final rule in ruleAnalyzers) ...rule.extensions,
};

/// Basename-prefix union over the registry (dotfile scopes).
Set<String> get registeredPrefixes => {
  for (final rule in ruleAnalyzers) ...rule.namePrefixes,
};

/// Exact-basename union over the registry (singleton scopes).
Set<String> get registeredNames => {
  for (final rule in ruleAnalyzers) ...rule.names,
};
