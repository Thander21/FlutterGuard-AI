import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ARB-027 arb guard', () {
    test('flags undeclared placeholders in the golden bad vector', () {
      final violations = analyzeArbFile('benchmark/vectors/TC-27_arb.bad.arb');
      expect(violations.map((v) => v.line), [3, 3, 7]);
      expect(violations[0].message, contains("'userName'"));
      expect(violations[0].message, contains("'greeting'"));
      expect(violations[1].message, contains("'unreadCount'"));
      expect(violations[2].message, contains("'farewell'"));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeArbFile('benchmark/vectors/TC-27_arb.good.arb');
      expect(violations, isEmpty);
    });

    test('fails closed on malformed JSON with one finding', () {
      final root = Directory.systemTemp.createTempSync('arb_test.');
      try {
        final path = '${root.path}/broken.arb';
        File(path).writeAsStringSync('{\n  "a": "x",\n  oops\n}\n');
        final violations = analyzeArbFile(path);
        expect(violations, hasLength(1));
        expect(violations.single.line, 3);
        expect(violations.single.message, contains('invalid JSON'));
        final arrayPath = '${root.path}/array.arb';
        File(arrayPath).writeAsStringSync('[]\n');
        final array = analyzeArbFile(arrayPath);
        expect(array, hasLength(1));
        expect(array.single.line, 1);
        expect(array.single.message, contains('must be an object'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('treats non-map metadata as missing', () {
      final root = Directory.systemTemp.createTempSync('arb_test.');
      try {
        final path = '${root.path}/shapes.arb';
        File(path).writeAsStringSync('''
{
  "a": "Hi {who}!",
  "@a": "just a string",
  "b": "Bye {who}!",
  "@b": {"placeholders": ["who"]}
}
''');
        final violations = analyzeArbFile(path);
        expect(violations.map((v) => v.line), [2, 4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
