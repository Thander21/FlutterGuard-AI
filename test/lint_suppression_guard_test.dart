import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LINT-009 lint suppression guard', () {
    test('flags suppressions and the empty catch', () {
      final violations = analyzeLintSuppressionFile(
        'benchmark/vectors/TC-11_lint.bad.dart',
      );
      expect(violations.map((v) => v.line), [6, 12, 15, 23, 28, 31, 34]);
      expect(violations.first.message, contains('ignore:'));
      expect(violations.first.message, contains('root cause'));
      expect(violations[1].message, contains('empty catch'));
      expect(violations[2].message, contains('ignore_for_file:'));
      expect(violations[3].message, contains('catch block'));
      expect(
        violations.skip(4).map((v) => v.message),
        everyElement(contains('ignore:')),
      );
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

    test('flags empty catches in primary-constructor classes', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/connection.dart';
        File(path).writeAsStringSync('''
class Connection {
  new(this._ref);
  final Object _ref;

  void send() {
    try {
      transmit();
    } catch (_) {}
  }
}
''');
        final violations = analyzeLintSuppressionFile(path);
        expect(violations.map((v) => v.line), [8]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags empty rationale, spares justified suppressions', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/justified.dart';
        File(path).writeAsStringSync('''
void f() {
  debugPrint('x'); // ignore: avoid_print //
  debugPrint('y'); // ignore: avoid_print // tasting build
}
''');
        final violations = analyzeLintSuppressionFile(path);
        expect(violations.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('preceding-line gaps, docs, chains, and blanks stay bare (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/above.dart';
        File(path).writeAsStringSync('''
void f() {
  // reason here

  // ignore: a
  /// doc line
  // ignore: b
  // ignore: c
  // ignore: d
  //
  // ignore: e
}
''');
        final violations = analyzeLintSuppressionFile(path);
        expect(violations.map((v) => v.line), [4, 6, 7, 8, 10]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('comment-only catches warn, empty catches error (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/severity.dart';
        File(path).writeAsStringSync('''
void f() {
  try {
    a();
  } catch (_) {
    // tolerated: best-effort ping
  }
  try {
    b();
  } catch (_) {}
}
''');
        final result = checkPath(path);
        final byLine = {
          for (final finding in result.findings.where(
            (finding) => finding.ruleId == 'FG-LINT-009',
          ))
            finding.line: finding.severity,
        };
        expect(byLine[4], 'warning');
        expect(byLine[9], 'error');
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('comment-only vector catch warns through the registry (R2-3)', () {
      final result = checkPath('benchmark/vectors/TC-11_lint.bad.dart');
      final byLine = {
        for (final finding in result.findings.where(
          (finding) => finding.ruleId == 'FG-LINT-009',
        ))
          finding.line: finding.severity,
      };
      expect(byLine[12], 'error');
      expect(byLine[23], 'warning');
    });
    test('spares same-line rationale shapes (K3)', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync('''
// ignore_for_file: avoid_print // Justificativa: x
void f() {
  // ignore: specify_nonobvious_property_types, justificativa: A tipagem varia.
  a();
  // ignore: i18n - nome técnico da escala tipográfica.
  b();
  // ignore: avoid_print // Justificativa: CLI.
  c();
  // ignore: x — kept for the legacy driver
  d();
  // ignore: x, y, needed until the upstream fix lands
  e();
  // ignore: x Rationale: generated shim
  g();
  // ignore: x reason: upstream bug
  h();
  // ignore: x MOTIVO: legado
  i();
}
''');
        expect(analyzeLintSuppressionFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('bare code lists and empty separators stay flagged (K4)', () {
      final root = Directory.systemTemp.createTempSync('lint_test.');
      try {
        final path = '${root.path}/bare.dart';
        File(path).writeAsStringSync('''
void f() {
  a(); // ignore: x
  b(); // ignore: x //
  c(); // ignore: a, b
  d(); // ignore: x -
  e(); // ignore: x, justificativa:
  g(); // ignore: a, b,
  h(); // ignore_for_file: type=lint
}
''');
        final violations = analyzeLintSuppressionFile(path);
        expect(violations.map((v) => v.line), [2, 3, 4, 5, 6, 7, 8]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
