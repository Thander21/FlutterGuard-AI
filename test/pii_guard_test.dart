import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-PII-028 pii guard', () {
    test('flags unmasked PII in the golden bad vector', () {
      final violations = analyzePiiFile(
        'benchmark/vectors/tc28/TC-28_pii.bad.dart',
      );
      expect(violations.map((v) => v.line), [5, 6, 7, 8, 9, 10]);
      expect(violations[0].message, contains('email-shaped'));
      expect(violations[0].message, isNot(contains('ana@example.com')));
      expect(violations[2].message, contains("'password'"));
      expect(violations[3].message, contains("'cpf'"));
      expect(violations[4].message, contains('configured pattern'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzePiiFile(
        'benchmark/vectors/tc28/TC-28_pii.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('honors except files via injected config', () {
      final violations = analyzePiiFile(
        'benchmark/vectors/tc28/TC-28_pii.bad.dart',
        config: const PiiConfig(except: ['**/TC-28_pii.bad.dart']),
      );
      expect(violations, isEmpty);
    });

    test('drops malformed regex leniently, defaults still flag', () {
      final root = Directory.systemTemp.createTempSync('pii_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync("void f() {\n  print('a@b.com');\n}\n");
        final violations = analyzePiiFile(
          path,
          config: const PiiConfig(patterns: {'(['}),
        );
        expect(violations, hasLength(1));
        expect(violations.single.message, contains('email-shaped'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('bare log() is clean, print() flags without a section', () {
      final root = Directory.systemTemp.createTempSync('pii_test.');
      try {
        final path = '${root.path}/sinks.dart';
        File(path).writeAsStringSync(
          "void f() {\n  log('a@b.com');\n  print('c@d.com');\n}\n",
        );
        final violations = analyzePiiFile(path);
        expect(violations.map((v) => v.line), [3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('matches dotted sinks by simple name', () {
      final root = Directory.systemTemp.createTempSync('pii_test.');
      try {
        final path = '${root.path}/dotted.dart';
        File(path)
            .writeAsStringSync("void f() {\n  logger.info('a@b.com');\n}\n");
        final violations = analyzePiiFile(
          path,
          config: const PiiConfig(sinks: {'info'}),
        );
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
