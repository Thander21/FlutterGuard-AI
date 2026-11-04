import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../bin/flutterguard.dart' as cli;

/// Canon keys in emission order (SYS-TELE-001 §2).
const canonKeys = [
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
  group('SYS-TELE-001 telemetry canon', () {
    test('grade-appended lines match the canon table exactly', () {
      final root = Directory.systemTemp.createTempSync('tele_canon.');
      try {
        Directory('${root.path}/specs').createSync();
        Directory('${root.path}/benchmark/vectors').createSync(recursive: true);
        for (final name in [
          'specs/TS-01-bloc-emit-guard.md',
          'benchmark/vectors/TC-01_bloc.bad.dart',
          'benchmark/vectors/TC-01_bloc.good.dart',
        ]) {
          File('${root.path}/$name')
              .writeAsStringSync(File(name).readAsStringSync());
        }

        expect(cli.grade(root: root.path), isZero);
        final lines = File('${root.path}/evidence.jsonl').readAsLinesSync();
        expect(lines, hasLength(2));

        final byKind = <String, Map<String, dynamic>>{};
        for (final line in lines) {
          final entry = jsonDecode(line) as Map<String, dynamic>;
          expect(entry.keys.toList(), orderedEquals(canonKeys));
          expect(entry['phase'], 'DETERMINISTIC_GATE');
          expect(entry['rule_id'], 'FG-BLOC-001');
          expect(entry['action'], 'EVAL_RECORDED');
          expect(entry['recipe_injected'], isEmpty);
          expect(entry['iteration'], 1);
          DateTime.parse(entry['timestamp'] as String);
          final file = entry['file'] as String;
          byKind[file.endsWith('.bad.dart') ? 'bad' : 'good'] = entry;
        }

        expect(byKind['bad']!['status'], 'FAILED');
        expect(byKind['bad']!['error_message'], isNotEmpty);
        expect(byKind['good']!['status'], 'PASSED');
        expect(byKind['good']!['error_message'], isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
