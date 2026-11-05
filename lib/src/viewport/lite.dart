// SYS-VIEW-001: Tier-1-lite — viewport-relevant AST rules as the
// degraded stand-in where the Flutter SDK is absent (CI).
//
// Pure library code (no stdout/stderr side effects), same walk/sort
// discipline as `checkPath`, so the behavior is unit-testable.
import '../cli/check.dart';
import '../cli/rules.dart';
import '../util.dart';

/// Viewport-relevant AST rule ids (Tier-1-lite vocabulary, v1).
const tier1LiteRules = <String>['FG-LAY-004'];

/// Degraded-mode note: lite PASS never claims rendered-clean.
const tier1LiteNote =
    'Tier-1-lite: AST stand-in; rendered overflow '
    'needs the full harness (Flutter SDK).';

/// Result of [runTier1Lite]: AST viewport findings plus the
/// degraded-mode flag.
class Tier1LiteResult {
  const Tier1LiteResult({
    required this.findings,
    required this.errors,
    required this.filesScanned,
    required this.sdkAvailable,
  });

  final List<CheckFinding> findings;
  final List<CheckError> errors;
  final int filesScanned;

  /// True when a `flutter` executable resolves on PATH.
  final bool sdkAvailable;

  String get note => tier1LiteNote;
}

/// True when a `flutter` executable resolves on PATH. [pathEnv]
/// injects a fake PATH for tests; the ambient machine is never
/// asserted on. Historical candidate set kept (`.sh` included).
bool isFlutterSdkAvailable({String? pathEnv}) => resolvesOnPath(
  'flutter',
  pathEnv: pathEnv,
  extensions: const ['', '.exe', '.bat', '.sh'],
);

/// Runs the Tier-1-lite vocabulary over [target] (one `.dart` file or
/// a directory scanned recursively, sorted).
///
/// One bad file never kills the run: per-file failures are collected
/// in [Tier1LiteResult.errors]. Throws [ArgumentError] when [target]
/// is missing, [StateError] when a lite rule id has no analyzer.
Tier1LiteResult runTier1Lite(String target) {
  final files = collectDartFiles(target);

  final byId = {for (final rule in ruleAnalyzers) rule.id: rule};
  final analyzers = <RuleAnalyzer>[];
  for (final id in tier1LiteRules) {
    final analyzer = byId[id];
    if (analyzer == null) throw StateError('no analyzer for lite rule $id');
    analyzers.add(analyzer);
  }

  final (:findings, :errors) = analyzeFilesWithRules(files, analyzers);
  return Tier1LiteResult(
    findings: findings,
    errors: errors,
    filesScanned: files.length,
    sdkAvailable: isFlutterSdkAvailable(),
  );
}
