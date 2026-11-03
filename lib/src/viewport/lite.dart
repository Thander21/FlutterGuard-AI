// SYS-VIEW-001: Tier-1-lite — viewport-relevant AST rules as the
// degraded stand-in where the Flutter SDK is absent (CI).
//
// Pure library code (no stdout/stderr side effects), same walk/sort
// discipline as `checkPath`, so the behavior is unit-testable.
import 'dart:io';

import '../cli/check.dart';
import '../cli/rules.dart';

/// Viewport-relevant AST rule ids (Tier-1-lite vocabulary, v1).
const tier1LiteRules = <String>['FG-LAY-004'];

/// Degraded-mode note: lite PASS never claims rendered-clean.
const tier1LiteNote = 'Tier-1-lite: AST stand-in; rendered overflow '
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
/// asserted on.
bool isFlutterSdkAvailable({String? pathEnv}) {
  final path = pathEnv ?? Platform.environment['PATH'] ?? '';
  if (path.isEmpty) return false;
  final separator = Platform.isWindows ? ';' : ':';
  const names = ['flutter', 'flutter.exe', 'flutter.bat', 'flutter.sh'];
  for (final entry in path.split(separator)) {
    final dir = entry.trim();
    if (dir.isEmpty) continue;
    for (final name in names) {
      if (File('$dir/$name').existsSync()) return true;
    }
  }
  return false;
}

/// Runs the Tier-1-lite vocabulary over [target] (one `.dart` file or
/// a directory scanned recursively, sorted).
///
/// One bad file never kills the run: per-file failures are collected
/// in [Tier1LiteResult.errors]. Throws [ArgumentError] when [target]
/// is missing, [StateError] when a lite rule id has no analyzer.
Tier1LiteResult runTier1Lite(String target) {
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.notFound) {
    throw ArgumentError('No such file or directory: $target');
  }
  final files = <String>[];
  if (type == FileSystemEntityType.directory) {
    for (final entity in Directory(target).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(_normalize(entity.path));
      }
    }
  } else if (target.endsWith('.dart')) {
    files.add(_normalize(target));
  }
  files.sort();

  final byId = {for (final rule in ruleAnalyzers) rule.id: rule};
  final analyzers = <RuleAnalyzer>[];
  for (final id in tier1LiteRules) {
    final analyzer = byId[id];
    if (analyzer == null) throw StateError('no analyzer for lite rule $id');
    analyzers.add(analyzer);
  }

  final findings = <CheckFinding>[];
  final errors = <CheckError>[];
  final seenErrors = <(String, String)>{};
  for (final file in files) {
    for (final rule in analyzers) {
      try {
        for (final violation in rule.analyze(file)) {
          findings.add(CheckFinding(
            ruleId: rule.id,
            spec: rule.spec,
            file: file,
            line: violation.line,
            message: violation.message,
            severity: rule.severity,
          ));
        }
      } catch (error) {
        if (seenErrors.add((file, '$error'))) {
          errors.add(CheckError(file: file, error: '$error'));
        }
      }
    }
  }
  findings.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    if (byFile != 0) return byFile;
    final byRule = a.ruleId.compareTo(b.ruleId);
    if (byRule != 0) return byRule;
    return a.line.compareTo(b.line);
  });
  return Tier1LiteResult(
    findings: findings,
    errors: errors,
    filesScanned: files.length,
    sdkAvailable: isFlutterSdkAvailable(),
  );
}

/// Forward slashes on every platform, so findings sort and compare the same
/// on Windows, macOS, and Linux.
String _normalize(String path) => path.replaceAll(r'\', '/');
