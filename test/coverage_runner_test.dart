// SYS-COV-001 contract test: CC units, lcov units, the CRAP formula,
// and the two-hop pipeline with exact CC/cov/CRAP on the committed
// sample (plus red-suite and argument errors).
import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('analyzeComplexity', () {
    test('counts every branch kind once', () {
      const source = '''
class A {
  int m(int x) {
    if (x > 0) x = 1;
    for (var i = 0; i < x; i++) {}
    while (x < 0) {
      x++;
    }
    do {
      x--;
    } while (x > 10);
    try {
      x = 1;
    } catch (_) {}
    switch (x) {
      case 1:
        x = 2;
        break;
      case 2:
        x = 3;
        break;
      default:
        x = 4;
    }
    x = x > 1 ? 1 : 0;
    if (x > 0 && x < 10 || x == 5) x = 0;
    x = x ?? 0;
    return x;
  }
}
int top(int x) => x > 0 ? x : -x;
''';
      final methods = analyzeComplexity(source);
      expect(methods.map((m) => m.name), ['A.m', 'top']);
      // 1 + if + for + while + do + catch + 2 cases + ?: + if + && +
      // || + ?? = 13.
      expect(methods.firstWhere((m) => m.name == 'A.m').complexity, 13);
      expect(methods.firstWhere((m) => m.name == 'top').complexity, 2);
    });

    test('counts collection branches, for-in, constructors, getters', () {
      const source = '''
List<int> build(bool c) => [if (c) 1, for (var i = 0; i < 3; i++) i];
int sum(List<int> xs) {
  var total = 0;
  for (final x in xs) {
    total += x;
  }
  return total;
}
class C {
  C.named(int x) {
    if (x > 0) {}
  }
  int get g => 1;
}
''';
      final byName = {
        for (final m in analyzeComplexity(source)) m.name: m.complexity,
      };
      expect(byName, {'build': 3, 'sum': 2, 'C.named': 2, 'C.g': 1});
    });

    test('skips bodiless declarations, reports exact ranges', () {
      const source = '''
abstract class B {
  int m(int x);
}
int f(int x) {
  return x;
}
''';
      final methods = analyzeComplexity(source);
      expect(methods.map((m) => m.name), ['f']);
      expect(methods.single.line, 4);
      expect(methods.single.endLine, 6);
      expect(methods.single.complexity, 1);
    });
  });

  group('parseLcov', () {
    test('parses records, sums duplicates, ignores summaries', () {
      const lcov = '''
TN:
SF:/pkg/lib/a.dart
DA:1,2
DA:2,0
DA:2,3
LF:2
LH:1
end_of_record
SF:/pkg/lib/b.dart
DA:9,1
end_of_record
''';
      final files = parseLcov(lcov);
      expect(files.keys, ['/pkg/lib/a.dart', '/pkg/lib/b.dart']);
      expect(files['/pkg/lib/a.dart']!.lineHits, {1: 2, 2: 3});
      expect(files['/pkg/lib/b.dart']!.lineHits, {9: 1});
    });

    test('rejects malformed input', () {
      expect(() => parseLcov('DA:1,1\nend_of_record'), throwsFormatException);
      expect(
        () => parseLcov('SF:/a.dart\nDA:1\nend_of_record'),
        throwsFormatException,
      );
      expect(
        () => parseLcov('SF:/a.dart\nDA:x,1\nend_of_record'),
        throwsFormatException,
      );
      expect(
        () => parseLcov('SF:/a.dart\nDA:0,1\nend_of_record'),
        throwsFormatException,
      );
      expect(() => parseLcov('SF:\nend_of_record'), throwsFormatException);
    });
  });

  group('MethodScore', () {
    test('CRAP formula and budget flag', () {
      const half = MethodScore(
        name: 'm',
        file: 'f',
        line: 1,
        complexity: 2,
        coverage: 0.5,
      );
      expect(half.crap, 2.5);
      expect(half.overBudget, isFalse);
      const risky = MethodScore(
        name: 'm',
        file: 'f',
        line: 1,
        complexity: 5,
        coverage: 0.0,
      );
      expect(risky.crap, 30.0);
      expect(risky.overBudget, isTrue);
      const clean = MethodScore(
        name: 'm',
        file: 'f',
        line: 1,
        complexity: 1,
        coverage: 1.0,
      );
      expect(clean.crap, 1.0);
    });

    test('full coverage absolves complexity (CC floor decision)', () {
      const absolved = MethodScore(
        name: 'm',
        file: 'f',
        line: 1,
        complexity: 12,
        coverage: 1.0,
      );
      expect(absolved.crap, 12.0);
      expect(absolved.overBudget, isFalse);
      const exposed = MethodScore(
        name: 'm',
        file: 'f',
        line: 1,
        complexity: 12,
        coverage: 0.9,
      );
      expect(exposed.crap, closeTo(12.144, 1e-9));
      expect(exposed.overBudget, isTrue);
    });
  });

  group('CoverageRunner', () {
    test('scores exact CC/cov/CRAP on the sample', () async {
      final verdict = await CoverageRunner().run(
        testPath: 'samples/coverage/sample_test.dart',
        reportOn: ['samples/coverage/sample.dart'],
      );
      expect(verdict.passed, isTrue);
      expect(verdict.filesScored, 1);
      final byName = {for (final m in verdict.methods) m.name: m};
      expect(byName.keys, ['max2', 'negateIfPositive', 'complex']);
      expect(byName['max2']!.complexity, 2);
      expect(byName['max2']!.coverage, 1.0);
      expect(byName['max2']!.crap, 2.0);
      expect(byName['max2']!.overBudget, isFalse);
      expect(byName['negateIfPositive']!.complexity, 2);
      expect(byName['negateIfPositive']!.coverage, 0.0);
      expect(byName['negateIfPositive']!.crap, 6.0);
      expect(byName['complex']!.complexity, 5);
      expect(byName['complex']!.coverage, 0.0);
      expect(byName['complex']!.crap, 30.0);
      expect(byName['complex']!.overBudget, isTrue);
    }, timeout: const Timeout(Duration(seconds: 180)));

    test('red suite refuses to score', () async {
      await expectLater(
        CoverageRunner().run(
          testPath: 'samples/coverage/red_test.dart',
          reportOn: ['samples/coverage/sample.dart'],
        ),
        throwsStateError,
      );
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('rejects bad inputs without running', () async {
      final runner = CoverageRunner();
      await expectLater(
        runner.run(testPath: 'nope.dart', reportOn: ['samples/coverage']),
        throwsArgumentError,
      );
      await expectLater(
        runner.run(testPath: 'samples/coverage/sample_test.dart', reportOn: []),
        throwsArgumentError,
      );
      await expectLater(
        runner.run(
          testPath: 'samples/coverage/sample_test.dart',
          reportOn: ['no/such/entry'],
        ),
        throwsArgumentError,
      );
    });
  });
}
