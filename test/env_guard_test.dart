import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ENV-029 env guard', () {
    test('flags key gaps in the golden bad vector', () {
      final violations = analyzeEnvFile('benchmark/vectors/tc29/bad/.env');
      expect(violations.map((v) => v.line), [1, 2]);
      expect(violations[0].message, contains("'API_KEY'"));
      expect(violations[0].message, contains('lacks'));
      expect(violations[1].message, contains("'EXTRA_KEY'"));
      for (final violation in violations) {
        expect(violation.message, isNot(contains('oops')));
        expect(violation.message, isNot(contains('staging')));
      }
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeEnvFile('benchmark/vectors/tc29/good/.env');
      expect(violations, isEmpty);
    });

    test('skips bare keys and colon lines', () {
      final root = Directory.systemTemp.createTempSync('env_test.');
      try {
        File('${root.path}/.env.example').writeAsStringSync('A=\n');
        File('${root.path}/.env').writeAsStringSync('A=1\nBARE\nWEIRD: x\n');
        expect(analyzeEnvFile('${root.path}/.env'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('stays silent without a sibling example', () {
      final root = Directory.systemTemp.createTempSync('env_test.');
      try {
        File('${root.path}/.env').writeAsStringSync('A=1\n');
        expect(analyzeEnvFile('${root.path}/.env'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('never judges the example oracle itself', () {
      expect(
        analyzeEnvFile('benchmark/vectors/tc29/bad/.env.example'),
        isEmpty,
      );
    });

    test('tolerates CRLF and strips the BOM', () {
      final root = Directory.systemTemp.createTempSync('env_test.');
      try {
        File('${root.path}/.env.example').writeAsStringSync('A=\r\nB=\r\n');
        File('${root.path}/.env').writeAsStringSync('\uFEFFA=1\r\nB=2\r\n');
        expect(analyzeEnvFile('${root.path}/.env'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
