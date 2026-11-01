import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('check', () {
    test('flags every .bad vector and spares every .good vector', () {
      final result = checkPath('benchmark/vectors');
      expect(result.errors, isEmpty);
      final flagged = result.findings.map((f) => f.file).toSet();
      expect(
        flagged,
        containsAll([
          'benchmark/vectors/TC-01_bloc.bad.dart',
          'benchmark/vectors/TC-02_riverpod.bad.dart',
          'benchmark/vectors/TC-03_controller.bad.dart',
        ]),
      );
      expect(
        flagged.any((f) => f.endsWith('.good.dart')),
        isFalse,
        reason: 'zero false positives on .good vectors',
      );
    });

    test('reports rule id, line, and recipe pointer per finding', () {
      final result = checkPath('benchmark/vectors/TC-01_bloc.bad.dart');
      expect(result.findings, hasLength(1));
      final finding = result.findings.single;
      expect(finding.ruleId, 'FG-BLOC-001');
      expect(finding.line, 26);
      final json = finding.toJson();
      expect(json['rule_id'], 'FG-BLOC-001');
      expect(json['spec'], 'specs/TS-01-bloc-emit-guard.md');
      expect(json['recipe'], contains('TS-01'));
    });

    test('throws on a missing target', () {
      expect(() => checkPath('does/not/exist'), throwsArgumentError);
    });
  });
}
