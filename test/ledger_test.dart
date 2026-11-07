// Per-run evidence ledger: canon-shaped gate lines via --evidence.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Canon keys in emission order (SYS-TELE-001 §2, zero new keys).
const _canonKeys = [
  'timestamp',
  'phase',
  'rule_id',
  'file',
  'status',
  'error_message',
  'recipe_injected',
  'iteration',
  'action',
];

void main() {
  group('buildLedgerLines', () {
    test('emits canon-ordered gate lines with mapped statuses', () {
      final lines = buildLedgerLines(
        target: 'pkg/',
        gates: const [
          (ruleId: 'FG-A-001', status: 'FAIL'),
          (ruleId: 'FG-B-002', status: 'WARN'),
          (ruleId: 'FG-C-003', status: 'PASS'),
        ],
        findings: const [
          (ruleId: 'FG-A-001', message: 'first'),
          (ruleId: 'FG-A-001', message: 'second'),
          (ruleId: 'FG-B-002', message: 'warn-msg'),
        ],
        timestamp: '2026-11-06T00:00:00.000Z',
      );
      expect(lines, hasLength(3));
      final first = jsonDecode(lines[0]) as Map<String, dynamic>;
      expect(first.keys.toList(), orderedEquals(_canonKeys));
      expect(first, {
        'timestamp': '2026-11-06T00:00:00.000Z',
        'phase': 'CHECK_GATE',
        'rule_id': 'FG-A-001',
        'file': 'pkg/',
        'status': 'FAILED',
        'error_message': 'first',
        'recipe_injected': '',
        'iteration': 1,
        'action': 'CHECK_RECORDED',
      });
      final second = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(second['status'], 'WARNED');
      expect(second['error_message'], 'warn-msg');
      final third = jsonDecode(lines[2]) as Map<String, dynamic>;
      expect(third['status'], 'PASSED');
      expect(third['error_message'], isEmpty);
    });
  });

  group('appendLedger', () {
    test('appends JSONL, creates parents, doubles on rerun', () {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        final ledger = '${root.path}/deep/nested/ledger.jsonl';
        appendLedger(ledger, const ['{"a": 1}']);
        appendLedger(ledger, const ['{"a": 2}']);
        expect(File(ledger).readAsLinesSync(), ['{"a": 1}', '{"a": 2}']);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('empty lines write nothing', () {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        final ledger = '${root.path}/ledger.jsonl';
        appendLedger(ledger, const []);
        expect(File(ledger).existsSync(), isFalse);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('unwritable path throws ArgumentError', () {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        File('${root.path}/blocker').writeAsStringSync('x');
        expect(
          () => appendLedger('${root.path}/blocker/ledger.jsonl', const [
            '{"a": 1}',
          ]),
          throwsArgumentError,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });

  group('check --evidence', () {
    test('records per-gate lines for the run', () async {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        final ledger = '${root.path}/ledger.jsonl';
        expect(
          await check([
            '--evidence',
            ledger,
            'benchmark/vectors/TC-07_lay.bad.dart',
          ]),
          1,
        );
        final lines = File(ledger).readAsLinesSync();
        expect(lines, hasLength(ruleAnalyzers.length));
        final lay = lines
            .map((l) => jsonDecode(l) as Map<String, dynamic>)
            .singleWhere((e) => e['rule_id'] == 'FG-LAY-004');
        expect(lay.keys.toList(), orderedEquals(_canonKeys));
        expect(lay['phase'], 'CHECK_GATE');
        expect(lay['status'], 'FAILED');
        expect(lay['error_message'], isNotEmpty);
        expect(lay['file'], 'benchmark/vectors/TC-07_lay.bad.dart');
        expect(lay['action'], 'CHECK_RECORDED');
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('writes nothing without the flag', () async {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        File('${root.path}/a.dart').writeAsStringSync('void main() {}\n');
        expect(await check([root.path]), isZero);
        expect(
          Directory(root.path).listSync().map((e) {
            return e.path.replaceAll(r'\', '/').split('/').last;
          }).toList(),
          ['a.dart'],
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('unwritable ledger path exits 2', () async {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        File('${root.path}/blocker').writeAsStringSync('x');
        expect(
          await check([
            '--evidence',
            '${root.path}/blocker/ledger.jsonl',
            'benchmark/vectors/TC-07_lay.bad.dart',
          ]),
          2,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('evidence alone prints no gate rows (subprocess)', () {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        final ledger = '${root.path}/ledger.jsonl';
        final result = Process.runSync('dart', [
          'run',
          'bin/flutterguard.dart',
          'check',
          '--evidence',
          ledger,
          'benchmark/vectors/TC-07_lay.bad.dart',
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1);
        expect(result.stdout as String, isNot(contains('gate ')));
        expect(File(ledger).readAsLinesSync(), hasLength(ruleAnalyzers.length));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('update-baseline runs also record', () async {
      final root = Directory.systemTemp.createTempSync('ledger_test.');
      try {
        final ledger = '${root.path}/ledger.jsonl';
        final baseline = '${root.path}/baseline.json';
        expect(
          await check([
            '--evidence',
            ledger,
            '--baseline',
            baseline,
            '--update-baseline',
            'benchmark/vectors/TC-07_lay.bad.dart',
          ]),
          isZero,
        );
        expect(File(baseline).existsSync(), isTrue);
        expect(File(ledger).readAsLinesSync(), hasLength(ruleAnalyzers.length));
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
