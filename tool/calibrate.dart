// SYS-CAL-001: threshold calibration harness (re-runnable).
//
// Measures the advisory thresholds over the calibration corpus and
// prints the flag tables the spec publishes. Slow CRAP trios that
// trip the 8s breaker report UNMEASURED (method constraint: CRAP
// needs fast suites) instead of killing the run.
//
// Usage (from the repository root):
//   dart tool/calibrate.dart
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';

/// Calibration corpus v1: the repo itself (real Dart) + golden
/// vectors (labeled positives/negatives by construction).
const _corpusRoots = [
  'lib',
  'bin',
  'test',
  'tool',
  'viewport/lib',
  'viewport/test',
  'samples',
  'benchmark/vectors',
];

/// DRY corpus: real code only. `benchmark/` twins and `test/`
/// fixtures are intentional near-copies, not smell candidates.
const _dryRoots = ['lib', 'bin', 'tool', 'viewport'];

/// CRAP trios: (test file, reported-on lib file, hop budget in
/// seconds). The mcp/tools trio runs the 180s slow lane (SYS-COV-001
/// §2); the 8s default stands everywhere else.
const _crapTrios = [
  ('test/duplication_test.dart', 'lib/src/duplication/detector.dart', 8),
  ('test/metric_guard_test.dart', 'lib/src/ast/metric_guard.dart', 8),
  ('test/mcp_server_test.dart', 'lib/src/mcp/tools.dart', 180),
];

Future<void> main() async {
  final files = <String>[];
  for (final root in _corpusRoots) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path.replaceAll(r'\', '/'));
      }
    }
  }
  files.sort();
  print('=== corpus: ${files.length} files ===');

  print('--- MET depth/params flags ---');
  var metCount = 0;
  for (final file in files) {
    try {
      for (final violation in analyzeMetricFile(file)) {
        metCount++;
        print('$file:${violation.line}: ${violation.message}');
      }
    } on ArgumentError {
      print('SKIP (unparseable): $file');
    }
  }
  print('MET total: $metCount');

  print('--- DRY pairs (real code, no twins) ---');
  for (final root in _dryRoots) {
    final verdict = findDuplication(root);
    print(
      '$root: units=${verdict.unitsCompared} '
      'pairs=${verdict.pairs.length} errors=${verdict.errors.length}',
    );
    for (final pair in verdict.pairs) {
      print('  $pair');
    }
  }

  print('--- CRAP trios ---');
  for (final trio in _crapTrios) {
    try {
      final verdict = await CoverageRunner(timeout: Duration(seconds: trio.$3))
          .run(testPath: trio.$1, reportOn: [trio.$2]);
      final over = verdict.methods.where((m) => m.overBudget).toList();
      print(
        '${trio.$2}: ${verdict.methods.length} methods, '
        '${over.length} over budget',
      );
      for (final m in over) {
        print(
          '  ${m.name} L${m.line} CC=${m.complexity} '
          'cov=${m.coverage.toStringAsFixed(2)} '
          'CRAP=${m.crap.toStringAsFixed(1)}',
        );
      }
    } on StateError catch (error) {
      print('${trio.$2}: UNMEASURED ($error)');
    }
  }
}
