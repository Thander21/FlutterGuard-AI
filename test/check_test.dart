import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('check', () {
    test('flags every .bad vector and spares every .good vector', () {
      final result = checkPath('benchmark/vectors');
      expect(result.errors, hasLength(1),
          reason: 'only the intentional TC-17 syntax error throws visitors');
      expect(result.errors.single.file, endsWith('TC-17_syn.bad.dart'));
      expect(result.errors.single.error, contains('MISSING_IDENTIFIER'));
      final flagged = result.findings.map((f) => f.file).toSet();
      expect(
        flagged,
        containsAll([
          'benchmark/vectors/TC-01_bloc.bad.dart',
          'benchmark/vectors/TC-02_riverpod.bad.dart',
          'benchmark/vectors/TC-03_controller.bad.dart',
          'benchmark/vectors/TC-04_life.bad.dart',
          'benchmark/vectors/TC-05_arch.bad.dart',
          'benchmark/vectors/TC-06_async.bad.dart',
          'benchmark/vectors/TC-07_lay.bad.dart',
          'benchmark/vectors/TC-08_st.bad.dart',
          'benchmark/vectors/TC-09_ctx.bad.dart',
          'benchmark/vectors/TC-10_wid.bad.dart',
          'benchmark/vectors/TC-11_lint.bad.dart',
          'benchmark/vectors/TC-12_key.bad.dart',
          'benchmark/vectors/TC-13_met.bad.dart',
          'benchmark/vectors/TC-14_build.bad.dart',
          'benchmark/vectors/TC-15_imp.bad.dart',
          'benchmark/vectors/TC-16_fmt.bad.dart',
          'benchmark/vectors/TC-17_syn.bad.dart',
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

    test('analyzer crash becomes a report-only error, run continues', () {
      final boom = RuleAnalyzer(
        id: 'FG-BOOM-000',
        spec: 'specs/TS-01-bloc-emit-guard.md',
        analyze: (_) => throw StateError('boom'),
      );
      final result = analyzeFilesWithRules(
          ['benchmark/vectors/TC-01_bloc.good.dart'], [boom]);
      expect(result.findings, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.error, contains('boom'));
    });

    test('each .bad vector is flagged only by its own rule', () {
      const expected = <String, String>{
        'benchmark/vectors/TC-01_bloc.bad.dart': 'FG-BLOC-001',
        'benchmark/vectors/TC-02_riverpod.bad.dart': 'FG-RIV-001',
        'benchmark/vectors/TC-03_controller.bad.dart': 'FG-ST-001',
        'benchmark/vectors/TC-04_life.bad.dart': 'FG-LIFE-001',
        'benchmark/vectors/TC-05_arch.bad.dart': 'FG-ARCH-003',
        'benchmark/vectors/TC-06_async.bad.dart': 'FG-ASYNC-002',
        'benchmark/vectors/TC-07_lay.bad.dart': 'FG-LAY-004',
        'benchmark/vectors/TC-08_st.bad.dart': 'FG-ST-005',
        'benchmark/vectors/TC-09_ctx.bad.dart': 'FG-CTX-006',
        'benchmark/vectors/TC-10_wid.bad.dart': 'FG-WID-008',
        'benchmark/vectors/TC-11_lint.bad.dart': 'FG-LINT-009',
        'benchmark/vectors/TC-12_key.bad.dart': 'FG-KEY-001r',
        'benchmark/vectors/TC-13_met.bad.dart': 'FG-MET-007',
        'benchmark/vectors/TC-14_build.bad.dart': 'FG-BUILD-014',
        'benchmark/vectors/TC-15_imp.bad.dart': 'FG-IMP-015',
        'benchmark/vectors/TC-16_fmt.bad.dart': 'FG-FMT-016',
        'benchmark/vectors/TC-17_syn.bad.dart': 'FG-SYN-017',
      };
      final result = checkPath('benchmark/vectors');
      for (final entry in expected.entries) {
        final rules = result.findings
            .where((f) => f.file == entry.key)
            .map((f) => f.ruleId)
            .toSet();
        expect(rules, isNotEmpty, reason: '${entry.key} was not flagged');
        expect(rules, everyElement(entry.value),
            reason: '${entry.key} has cross-rule findings: $rules');
      }
    });

    test('fails closed on an unparseable file (FG-SYN-017 finding)', () {
      final root = Directory.systemTemp.createTempSync('check_test.');
      try {
        File('${root.path}/broken.dart').writeAsStringSync('class { !!!');
        final result = checkPath(root.path);
        expect(result.findings, isNotEmpty);
        expect(result.findings.map((f) => f.ruleId), everyElement('FG-SYN-017'),
            reason: 'unparseable files fail closed via FG-SYN-017');
        expect(result.errors, hasLength(1));
        expect(result.errors.single.file, endsWith('broken.dart'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('marks blocking findings error and advisories warning', () {
      final errors = checkPath('benchmark/vectors/TC-01_bloc.bad.dart');
      expect(errors.findings, isNotEmpty);
      expect(errors.findings.every((f) => f.severity == 'error'), isTrue);
      expect(errors.findings.single.toJson()['severity'], 'error');

      final advisories = checkPath('benchmark/vectors/TC-13_met.bad.dart');
      expect(advisories.findings, isNotEmpty);
      expect(advisories.findings.every((f) => f.severity == 'warning'), isTrue);
      expect(
          advisories.findings.every((f) => f.ruleId == 'FG-MET-007'), isTrue);
      expect(advisories.findings.first.toJson()['severity'], 'warning');
    });
  });
}
