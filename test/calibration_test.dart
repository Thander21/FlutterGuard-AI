// SYS-CAL-001 tripwire: pins the ratified MET flag set, DRY pair
// membership, and the unparseable-skip set. Any detector or
// codebase change that moves the numbers fails here ON PURPOSE —
// re-run `dart tool/calibrate.dart`, re-judge every flag, amend
// SYS-CAL-001, then update these pins. Never update pins without
// re-judging. (CRAP is excluded: slow suites trip the 8s breaker,
// so it cannot pin deterministically.)
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Ratified MET flag set (SYS-CAL-001 §2): `file:line`.
/// v2 (2026-11-04): both FP classes excluded by the detector
/// (data-holder params, scaffold transparency) — only the two
/// labeled TPs remain.
const _ratifiedMetFlags = {
  'benchmark/vectors/TC-13_met.bad.dart:7',
  'benchmark/vectors/TC-13_met.bad.dart:29',
};

/// Ratified unparseable-skip set (SYS-CAL-001 §2): corpus files the
/// MET scan skips (they cannot be measured). Exactly one by design:
/// TS-17's golden negative.
const _ratifiedSkipped = {'benchmark/vectors/TC-17_syn.bad.dart'};

/// Ratified DRY pairs over `lib/` (SYS-CAL-001 §2):
/// `fileA:lineA~fileB:lineB` in canonical order. The 3 TPs were
/// healed into `lib/src/util.dart` (re-ratification 2026-11-03);
/// v2 (2026-11-04): data-holder exclusion eliminated the ten
/// data-class pairs; the 3 survivors are known FP classes
/// (guard idiom ×2, thin wrappers).
/// REL-001 R3: +1 procedural-flow twin (moved `init()`); 4 pinned.
/// Wave 2: +1 procedural-flow twin (new `heal()`); 5 pinned.
/// SYS-CAL-002 P0-1: analyzer-14 token change eliminated the
/// metric~widget guard-idiom pair; reformat shifted 3 keys; 4 pinned.
const _ratifiedLibPairs = {
  'lib/src/ast/arch_layer_guard.dart:74~lib/src/ast/controller_build_guard.dart:54',
  'lib/src/cli/heal.dart:43~lib/src/cli/init.dart:60',
  'lib/src/cli/init.dart:60~lib/src/coverage/runner.dart:70',
  'lib/src/mcp/tools.dart:196~lib/src/mcp/tools.dart:218',
};

const _ratifiedViewportPairs = {
  'viewport/test/fixtures/bad_layout.dart:5~viewport/test/fixtures/good_layout.dart:5',
};

void main() {
  group('SYS-CAL-001 tripwire', () {
    test('MET flag set is exactly the ratified 2', () {
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
      final skipped = <String>{};
      for (final file in files) {
        try {
          for (final violation in analyzeMetricFile(file)) {
            flags.add('$file:${violation.line}');
          }
        } on ArgumentError {
          skipped.add(file);
        }
      }
      expect(
        skipped,
        _ratifiedSkipped,
        reason:
            'unparseable corpus files must stay exactly the designed one'
            ' — re-calibrate per SYS-CAL-001 §5',
      );
      expect(
        flags,
        _ratifiedMetFlags,
        reason: 'MET numbers moved — re-calibrate per SYS-CAL-001 §5',
      );
    });

    test('DRY pair membership is exactly the ratified set', () {
      String keyOf(ClonePair pair) =>
          '${pair.fileA}:${pair.lineA}~${pair.fileB}:${pair.lineB}';

      final lib = findDuplication('lib');
      expect(lib.errors, isEmpty);
      expect(
        {for (final p in lib.pairs) keyOf(p)},
        _ratifiedLibPairs,
        reason: 'DRY/lib numbers moved — re-calibrate per SYS-CAL-001 §5',
      );

      for (final root in ['bin', 'tool']) {
        final verdict = findDuplication(root);
        expect(verdict.errors, isEmpty, reason: root);
        expect(verdict.pairs, isEmpty, reason: root);
      }

      final viewport = findDuplication('viewport');
      expect(viewport.errors, isEmpty);
      expect(
        {for (final p in viewport.pairs) keyOf(p)},
        _ratifiedViewportPairs,
        reason: 'DRY/viewport numbers moved — re-calibrate per SYS-CAL-001 §5',
      );
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
