import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LIFE-001 resource symmetry guard', () {
    test('flags unreleased fields and unpaired listeners', () {
      final violations =
          analyzeLifecycleFile('benchmark/vectors/TC-04_life.bad.dart');
      expect(violations.map((v) => v.line), [4, 5, 6, 7, 10, 11, 18, 19]);
      expect(violations.first.message, contains('StreamSubscription'));
      expect(violations.first.message, contains('dispose'));
      expect(violations[5].message, contains('StreamSubscription'));
      expect(violations[5].message, contains('_lateSub'));
      expect(violations.last.message, contains('removeListener'));
    });

    test('spares fully released resources (zero false positives)', () {
      final violations =
          analyzeLifecycleFile('benchmark/vectors/TC-04_life.good.dart');
      expect(violations, isEmpty);
    });
  });
}
