import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LINT-009 lint suppression guard', () {
    test('flags suppressions and the empty catch', () {
      final violations = analyzeLintSuppressionFile(
        'benchmark/vectors/TC-11_lint.bad.dart',
      );
      expect(violations.map((v) => v.line), [6, 12, 15]);
      expect(violations.first.message, contains('ignore:'));
      expect(violations.first.message, contains('root cause'));
      expect(violations[1].message, contains('empty catch'));
      expect(violations.last.message, contains('ignore_for_file:'));
    });

    test('spares handled errors (zero false positives)', () {
      final violations = analyzeLintSuppressionFile(
        'benchmark/vectors/TC-11_lint.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags trailing ignores, spares block comments', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/comments.dart';
        File(path).writeAsStringSync('''
void f() {
  debugPrint('x'); // ignore: avoid_print
  /* ignore: avoid_print */
}
''');
        final violations = analyzeLintSuppressionFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags empty on-clauses and semicolon-only catches', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/catches.dart';
        File(path).writeAsStringSync('''
void f() {
  try {
    fetch();
  } on FormatException {
  }
  try {
    fetch();
  } catch (error) {
    ;
  }
}
''');
        final violations = analyzeLintSuppressionFile(path);
        expect(violations.map((v) => v.line), [4, 8]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares uppercase directives and colon-less mentions', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/mentions.dart';
        File(path).writeAsStringSync('''
void f() {
  // IGNORE: avoid_print
  // never ignore errors silently
  debugPrint('x');
}
''');
        expect(analyzeLintSuppressionFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
