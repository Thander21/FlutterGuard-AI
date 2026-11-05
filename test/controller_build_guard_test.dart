import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ST-001 controller in build guard', () {
    test('flags every controller created inside build()', () {
      final violations = analyzeControllerBuildFile(
        'benchmark/vectors/TC-03_controller.bad.dart',
      );
      expect(violations.map((v) => v.line), [16, 20]);
      expect(violations.first.message, contains('TextEditingController'));
      expect(violations.first.message, contains('initState'));
    });

    test('spares state-owned controllers (zero false positives)', () {
      final violations = analyzeControllerBuildFile(
        'benchmark/vectors/TC-03_controller.good.dart',
      );
      expect(violations, isEmpty);
    });
  });
}
