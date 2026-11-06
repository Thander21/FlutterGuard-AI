import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-RIV-026 provider naming guard', () {
    test('flags every suffixless provider in the golden bad vector', () {
      final violations = analyzeProviderNamingFile(
        'benchmark/vectors/TC-26_prov.bad.dart',
      );
      expect(violations.map((v) => v.line), [
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        19,
      ]);
      expect(violations.first.message, contains("'counter'"));
      expect(violations.first.message, contains("'Provider'"));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeProviderNamingFile(
        'benchmark/vectors/TC-26_prov.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags assigned overrideWith only when suffixless', () {
      final root = Directory.systemTemp.createTempSync('prov_test.');
      try {
        final path = '${root.path}/overrides.dart';
        File(path).writeAsStringSync('''
final naked = base.overrideWith((ref) => 0);
final clothedProvider = base.overrideWith((ref) => 0);
''');
        final violations = analyzeProviderNamingFile(path);
        expect(violations.map((v) => v.line), [1]);
        expect(violations.single.message, contains("'naked'"));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares instance fields but judges each declarator', () {
      final root = Directory.systemTemp.createTempSync('prov_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync('''
class Owned {
  final cache = Provider((ref) => 0);
}

final split = Provider((ref) => 0), plain = 1;
''');
        final violations = analyzeProviderNamingFile(path);
        expect(violations.map((v) => v.line), [5]);
        expect(violations.single.message, contains("'split'"));
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
