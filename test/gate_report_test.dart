// Per-gate report: verdicts, timings, and the --by-gate flag.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

CheckFinding _finding(String rule, {String severity = 'error'}) => CheckFinding(
  ruleId: rule,
  spec: 'specs/TS-00.md',
  file: 'a.dart',
  line: 1,
  message: 'message',
  severity: severity,
);

void main() {
  group('gateReport', () {
    test('maps findings to PASS/WARN/FAIL with counts', () {
      final rules = [
        ruleAnalyzers.firstWhere((r) => r.id == 'FG-BLOC-001'),
        ruleAnalyzers.firstWhere((r) => r.id == 'FG-MET-007'),
        ruleAnalyzers.firstWhere((r) => r.id == 'FG-LAY-004'),
      ];
      final verdicts = gateReport(
        rules: rules,
        findings: [
          _finding('FG-MET-007', severity: 'warning'),
          _finding('FG-LAY-004'),
          _finding('FG-LAY-004'),
        ],
        msByRule: const {'FG-LAY-004': 34},
      );
      expect(verdicts.map((v) => v.ruleId), [
        'FG-BLOC-001',
        'FG-MET-007',
        'FG-LAY-004',
      ]);
      expect(verdicts.map((v) => v.status), ['PASS', 'WARN', 'FAIL']);
      expect(verdicts[2].errors, 2);
      expect(verdicts[1].warnings, 1);
      expect(verdicts.map((v) => v.ms), [0, 0, 34]);
    });

    test('gateLine renders the text row', () {
      const verdict = GateVerdict(
        ruleId: 'FG-LAY-004',
        status: 'FAIL',
        errors: 16,
        warnings: 0,
        ms: 34,
      );
      expect(
        gateLine(verdict),
        'gate FAIL FG-LAY-004 (16 errors, 0 warnings, 34 ms)',
      );
      expect(verdict.toJson(), {
        'rule_id': 'FG-LAY-004',
        'status': 'FAIL',
        'errors': 16,
        'warnings': 0,
        'ms': 34,
      });
    });
  });

  group('timings', () {
    test('analyzeFilesWithRules times run rules', () {
      final result = analyzeFilesWithRules(
        ['benchmark/vectors/TC-07_lay.bad.dart'],
        ruleAnalyzers
            .where((r) => r.id == 'FG-LAY-004' || r.id == 'FG-SYN-017')
            .toList(),
      );
      expect(result.msByRule.keys, containsAll(['FG-LAY-004', 'FG-SYN-017']));
      expect(result.msByRule.values.every((ms) => ms >= 0), isTrue);
    });

    test('checkFiles carries timings on the result', () {
      final result = checkFiles([
        'benchmark/vectors/TC-07_lay.bad.dart',
      ], 'benchmark/vectors/TC-07_lay.bad.dart');
      expect(result.msByRule['FG-LAY-004'], greaterThanOrEqualTo(0));
      expect(
        result.msByRule.keys.every(
          (id) => ruleAnalyzers.any((r) => r.id == id),
        ),
        isTrue,
      );
    });
  });

  group('check --by-gate', () {
    test('JSON carries per-gate verdicts (subprocess)', () {
      final result = Process.runSync('dart', [
        'run',
        'bin/flutterguard.dart',
        'check',
        '--by-gate',
        '--json',
        'benchmark/vectors/TC-07_lay.bad.dart',
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 1);
      final decoded =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final gates = decoded['gates'] as List;
      expect(gates.map((g) => (g as Map)['rule_id']).toSet(), {
        for (final r in ruleAnalyzers) r.id,
      });
      final lay = gates.singleWhere(
        (g) => (g as Map)['rule_id'] == 'FG-LAY-004',
      ) as Map;
      expect(lay['status'], 'FAIL');
      expect(lay['errors'], 16);
      expect(gates.every((g) => ((g as Map)['ms'] as int) >= 0), isTrue);
    });

    test('text prints gate rows (subprocess)', () {
      final result = Process.runSync('dart', [
        'run',
        'bin/flutterguard.dart',
        'check',
        '--by-gate',
        'benchmark/vectors/TC-07_lay.bad.dart',
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 1);
      expect(
        result.stdout as String,
        contains('gate FAIL FG-LAY-004 (16 errors, 0 warnings,'),
      );
      expect(result.stdout as String, contains('gate PASS FG-BLOC-001 ('));
    });
  });
}
