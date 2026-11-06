import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-TST-033 test presence guard', () {
    test('flags the uncovered lib file in the golden bad vector', () {
      final violations = analyzeTstFile(
        'benchmark/vectors/tc33/bad/lib/shop.dart',
      );
      expect(violations.map((v) => v.line), [1]);
      expect(violations.single.message, contains('shop_test.dart'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeTstFile(
        'benchmark/vectors/tc33/good/lib/shop.dart',
      );
      expect(violations, isEmpty);
    });

    test('stays silent without the section (opt-in)', () {
      final root = Directory.systemTemp.createTempSync('tst_test.');
      try {
        Directory('${root.path}/lib').createSync();
        File('${root.path}/lib/foo.dart').writeAsStringSync('void f() {}\n');
        expect(analyzeTstFile('${root.path}/lib/foo.dart'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('empty map opts in, bare key and broken configs stay silent', () {
      final root = Directory.systemTemp.createTempSync('tst_test.');
      try {
        Directory('${root.path}/lib').createSync();
        File('${root.path}/lib/foo.dart').writeAsStringSync('void f() {}\n');
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('test_presence: {}\n');
        expect(analyzeTstFile('${root.path}/lib/foo.dart').map((v) => v.line), [
          1,
        ]);
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('test_presence:\n');
        expect(analyzeTstFile('${root.path}/lib/foo.dart'), isEmpty);
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('test_presence: [unclosed\n');
        expect(analyzeTstFile('${root.path}/lib/foo.dart'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('exempts lib/main.dart but flags lib/src/main.dart', () {
      final root = Directory.systemTemp.createTempSync('tst_test.');
      try {
        Directory('${root.path}/lib/src').createSync(recursive: true);
        File('${root.path}/lib/main.dart')
            .writeAsStringSync('void main() {}\n');
        File('${root.path}/lib/src/main.dart')
            .writeAsStringSync('void main() {}\n');
        expect(
          analyzeTstFile('${root.path}/lib/main.dart', enabled: true),
          isEmpty,
        );
        expect(
          analyzeTstFile(
            '${root.path}/lib/src/main.dart',
            enabled: true,
          ).map((v) => v.line),
          [1],
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('skips generated, test, and non-lib files', () {
      final root = Directory.systemTemp.createTempSync('tst_test.');
      try {
        Directory('${root.path}/lib').createSync();
        Directory('${root.path}/tool').createSync();
        File('${root.path}/lib/foo.g.dart').writeAsStringSync('// gen\n');
        File('${root.path}/lib/helper_test.dart')
            .writeAsStringSync('// colocated\n');
        File('${root.path}/tool/run.dart').writeAsStringSync('void f() {}\n');
        for (final file in [
          'lib/foo.g.dart',
          'lib/helper_test.dart',
          'tool/run.dart',
        ]) {
          expect(
            analyzeTstFile('${root.path}/$file', enabled: true),
            isEmpty,
            reason: '$file must stay clean',
          );
        }
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('maps monorepo mirrors', () {
      final root = Directory.systemTemp.createTempSync('tst_test.');
      try {
        Directory('${root.path}/packages/a/lib').createSync(recursive: true);
        File('${root.path}/packages/a/lib/x.dart')
            .writeAsStringSync('void f() {}\n');
        expect(
          analyzeTstFile(
            '${root.path}/packages/a/lib/x.dart',
            enabled: true,
          ).map((v) => v.line),
          [1],
        );
        Directory('${root.path}/packages/a/test').createSync(recursive: true);
        File('${root.path}/packages/a/test/x_test.dart')
            .writeAsStringSync('// test\n');
        expect(
          analyzeTstFile('${root.path}/packages/a/lib/x.dart', enabled: true),
          isEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
