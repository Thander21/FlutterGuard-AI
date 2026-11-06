import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-CC-025 complexity guard', () {
    test('flags the god-function in the golden bad vector', () {
      final violations = analyzeCcFile('benchmark/vectors/TC-25_cc.bad.dart');
      expect(violations.map((v) => v.line), [4]);
      expect(violations.single.message, contains("'classify'"));
      expect(violations.single.message, contains('86'));
      expect(violations.single.message, contains('80'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeCcFile('benchmark/vectors/TC-25_cc.good.dart');
      expect(violations, isEmpty);
    });

    test('pins the boundary at the injectable ceiling', () {
      final root = Directory.systemTemp.createTempSync('cc_test.');
      try {
        final path = '${root.path}/boundary.dart';
        File(path).writeAsStringSync('''
int atCeiling(int x) {
  if (x > 0) return 1;
  if (x < 0) return -1;
  return 0;
}

int overCeiling(int x) {
  if (x > 0) return 1;
  if (x < 0) return -1;
  if (x == 0) return 0;
  return 0;
}
''');
        expect(
          analyzeCcFile(path, maxComplexity: 3),
          hasLength(1),
          reason: 'CC 3 clean, CC 4 flags',
        );
        expect(analyzeCcFile(path, maxComplexity: 3).single.line, 7);
        expect(analyzeCcFile(path, maxComplexity: 4), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('folds closures and scores methods and constructors', () {
      final root = Directory.systemTemp.createTempSync('cc_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync('''
int withClosure(List<int> xs) {
  return xs.where((x) {
    if (x > 0) return true;
    if (x < 0) return false;
    if (x == 0) return true;
    return false;
  }).length;
}

abstract class Base {
  int run(int x);
}

class Worker extends Base {
  Worker(int x) {
    if (x > 0) print(x);
    if (x < 0) print(x);
    if (x == 0) print(x);
  }

  @override
  int run(int x) {
    return x;
  }
}
''');
        final violations = analyzeCcFile(path, maxComplexity: 3);
        expect(violations.map((v) => v.line), [1, 15]);
        expect(violations.first.message, contains("'withClosure'"));
        expect(violations.last.message, contains("'Worker'"));
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
