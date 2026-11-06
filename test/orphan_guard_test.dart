import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ORP-023 orphan guard', () {
    test('flags the golden orphan', () {
      final violations = analyzeOrpFile(
        'benchmark/vectors/tc23/stray_widget.g.dart',
      );
      expect(violations.map((v) => v.line), [1]);
      expect(violations.single.message, contains('stray_widget.g.dart'));
      expect(violations.single.message, contains('stray_widget.dart'));
    });

    test('spares the paired golden (zero false positives)', () {
      final violations = analyzeOrpFile(
        'benchmark/vectors/tc23/paired_widget.g.dart',
      );
      expect(violations, isEmpty);
    });

    test('covers every generated suffix plus plain files', () {
      final root = Directory.systemTemp.createTempSync('orp_test.');
      try {
        File('${root.path}/a.freezed.dart').writeAsStringSync('// orphan\n');
        File('${root.path}/b.gr.dart').writeAsStringSync('// orphan\n');
        File('${root.path}/c.mocks.dart').writeAsStringSync('// orphan\n');
        File('${root.path}/d.g.dart').writeAsStringSync('// paired\n');
        File('${root.path}/d.dart').writeAsStringSync('// source\n');
        File('${root.path}/e.dart').writeAsStringSync('// plain\n');

        for (final name in ['a.freezed.dart', 'b.gr.dart', 'c.mocks.dart']) {
          final violations = analyzeOrpFile('${root.path}/$name');
          expect(violations.map((v) => v.line), [
            1,
          ], reason: '$name is an orphan');
        }
        expect(
          analyzeOrpFile('${root.path}/d.g.dart'),
          isEmpty,
          reason: 'source sibling present',
        );
        expect(
          analyzeOrpFile('${root.path}/d.dart'),
          isEmpty,
          reason: 'the source itself is not generated',
        );
        expect(
          analyzeOrpFile('${root.path}/e.dart'),
          isEmpty,
          reason: 'plain files never match',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('default scans skip generated files; include-generated judges', () {
      final skipped = checkPath('benchmark/vectors/tc23');
      expect(
        skipped.findings,
        isEmpty,
        reason: 'generated goldens are invisible to default scans',
      );

      final judged = checkPath(
        'benchmark/vectors/tc23',
        includeGenerated: true,
      );
      expect(judged.findings.map((f) => '${f.ruleId}:${f.file}'), [
        'FG-ORP-023:benchmark/vectors/tc23/stray_widget.g.dart',
      ]);
    });
  });
}
