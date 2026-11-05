import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-RIV-001 riverpod watch guard', () {
    test('flags the golden failing vector', () {
      final violations = analyzeRiverpodFile(
        'benchmark/vectors/TC-02_riverpod.bad.dart',
      );
      expect(violations, hasLength(1));
      expect(violations.single.line, 16);
      expect(violations.single.message, contains('ref.read'));
    });

    test('spares the golden passing vector (zero false positives)', () {
      final violations = analyzeRiverpodFile(
        'benchmark/vectors/TC-02_riverpod.good.dart',
      );
      expect(violations, isEmpty);
    });
  });
}
