// SYS-CAL-001 tripwire: pins the ratified MET flag set and DRY pair
// membership. Any detector or codebase change that moves the numbers
// fails here ON PURPOSE — re-run `dart tool/calibrate.dart`,
// re-judge every flag, amend SYS-CAL-001, then update these pins.
// Never update pins without re-judging. (CRAP is excluded: slow
// suites trip the 8s breaker, so it cannot pin deterministically.)
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Ratified MET flag set (SYS-CAL-001 §2): `file:line`.
const _ratifiedMetFlags = {
  'benchmark/vectors/TC-13_met.bad.dart:7',
  'benchmark/vectors/TC-13_met.bad.dart:32',
  'lib/src/duplication/detector.dart:47',
  'viewport/test/fixtures/good_layout.dart:18',
};

/// Ratified DRY pairs over `lib/` (SYS-CAL-001 §2):
/// `fileA:lineA~fileB:lineB` in canonical order. The 3 TPs were
/// healed into `lib/src/util.dart` (re-ratification 2026-11-03);
/// all 12 remaining pairs are known FP classes (data holders,
/// guard idiom, thin wrappers).
const _ratifiedLibPairs = {
  'lib/src/ast/arch_layer_guard.dart:74~lib/src/ast/controller_build_guard.dart:54',
  'lib/src/cli/rules.dart:22~lib/src/duplication/detector.dart:22',
  'lib/src/cli/rules.dart:22~lib/src/util.dart:51',
  'lib/src/coverage/complexity.dart:13~lib/src/mutation/mutant.dart:12',
  'lib/src/duplication/detector.dart:22~lib/src/duplication/detector.dart:77',
  'lib/src/duplication/detector.dart:22~lib/src/heal/dispatcher.dart:62',
  'lib/src/duplication/detector.dart:22~lib/src/util.dart:51',
  'lib/src/duplication/detector.dart:22~lib/src/viewport/lite.dart:17',
  'lib/src/duplication/detector.dart:77~lib/src/heal/dispatcher.dart:62',
  'lib/src/duplication/detector.dart:77~lib/src/viewport/lite.dart:17',
  'lib/src/heal/dispatcher.dart:62~lib/src/viewport/lite.dart:17',
  'lib/src/mcp/tools.dart:190~lib/src/mcp/tools.dart:212',
};

const _ratifiedViewportPairs = {
  'viewport/test/fixtures/bad_layout.dart:5~viewport/test/fixtures/good_layout.dart:5',
};

void main() {
  group('SYS-CAL-001 tripwire', () {
    test('MET flag set is exactly the ratified 4', () {
      final files = _corpusFiles([
        'lib',
        'bin',
        'test',
        'tool',
        'viewport/lib',
        'viewport/test',
        'samples',
        'benchmark/vectors',
      ]);
      final flags = <String>{};
      for (final file in files) {
        for (final violation in analyzeMetricFile(file)) {
          flags.add('$file:${violation.line}');
        }
      }
      expect(flags, _ratifiedMetFlags,
          reason: 'MET numbers moved — re-calibrate per SYS-CAL-001 §5');
    });

    test('DRY pair membership is exactly the ratified set', () {
      String keyOf(ClonePair pair) =>
          '${pair.fileA}:${pair.lineA}~${pair.fileB}:${pair.lineB}';

      final lib = findDuplication('lib');
      expect(lib.errors, isEmpty);
      expect({for (final p in lib.pairs) keyOf(p)}, _ratifiedLibPairs,
          reason: 'DRY/lib numbers moved — re-calibrate per SYS-CAL-001 §5');

      for (final root in ['bin', 'tool']) {
        final verdict = findDuplication(root);
        expect(verdict.errors, isEmpty, reason: root);
        expect(verdict.pairs, isEmpty, reason: root);
      }

      final viewport = findDuplication('viewport');
      expect(viewport.errors, isEmpty);
      expect({for (final p in viewport.pairs) keyOf(p)},
          _ratifiedViewportPairs,
          reason:
              'DRY/viewport numbers moved — re-calibrate per SYS-CAL-001 §5');
    });
  });
}

List<String> _corpusFiles(List<String> roots) {
  final files = <String>[];
  for (final root in roots) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path.replaceAll(r'\', '/'));
      }
    }
  }
  return files..sort();
}
