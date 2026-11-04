// FG-SYN-017 contract test: flags files with syntactic errors,
// spares clean and semantic-only files.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-SYN-017 syntax guard', () {
    test('flags the .bad vector at the error line', () {
      final violations =
          analyzeSyntaxFile('benchmark/vectors/TC-17_syn.bad.dart');
      expect(violations.map((v) => v.line), [5]);
      expect(violations.first.message, contains('MISSING_IDENTIFIER'));
    });

    test('spares the .good vector (zero false positives)', () {
      final violations =
          analyzeSyntaxFile('benchmark/vectors/TC-17_syn.good.dart');
      expect(violations, isEmpty);
    });

    test('flags each error once at its own offset', () {
      final root = Directory.systemTemp.createTempSync('syn_test.');
      try {
        final path = '${root.path}/two.dart';
        File(path).writeAsStringSync('var a = ;\nvar b = ;\n');
        final violations = analyzeSyntaxFile(path);
        expect(violations.map((v) => v.line), [1, 2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares semantic-only diagnostics (parse-only oracle)', () {
      final root = Directory.systemTemp.createTempSync('syn_test.');
      try {
        final path = '${root.path}/semantic.dart';
        File(path).writeAsStringSync('''
import 'dart:async';
import 'dart:convert';

class A {
  @override
  void missing() {}
}
''');
        expect(analyzeSyntaxFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
