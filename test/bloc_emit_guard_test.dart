import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-BLOC-001 bloc emit guard', () {
    test('flags the golden failing vector', () {
      final violations =
          analyzeBlocFile('benchmark/vectors/TC-01_bloc.bad.dart');
      expect(violations, hasLength(1));
      expect(violations.single.line, 26);
      expect(violations.single.message, contains('isClosed'));
    });

    test('spares the golden passing vector (zero false positives)', () {
      final violations =
          analyzeBlocFile('benchmark/vectors/TC-01_bloc.good.dart');
      expect(violations, isEmpty);
    });
  });
}
