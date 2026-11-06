import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

RuleListConfig<BannedEntry> _testConfig() => const RuleListConfig([
  BannedEntry(symbol: 'SnackBar', message: 'route through NotificationService'),
  BannedEntry(symbol: 'trace', message: 'route through TelemetryService'),
]);

void main() {
  group('FG-BAN-018 banned symbol guard', () {
    test('flags banned uses in the golden bad vector', () {
      final violations = analyzeBannedSymbolFile(
        'benchmark/vectors/tc18/TC-18_ban.bad.dart',
      );
      expect(violations.map((v) => v.line), [5, 6, 7, 8]);
      expect(violations.first.message, contains('SnackBar'));
      expect(
        violations.first.message,
        contains('route through NotificationService'),
      );
      expect(
        violations.last.message,
        contains('route through TelemetryService'),
      );
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeBannedSymbolFile(
        'benchmark/vectors/tc18/TC-18_ban.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags type references, supertypes, and creations', () {
      final root = Directory.systemTemp.createTempSync('ban_test.');
      try {
        final path = '${root.path}/types.dart';
        File(path).writeAsStringSync('''
SnackBar makeBar(String label) {
  return SnackBar(content: label);
}

class MyBar extends SnackBar {
  const MyBar();
}
''');
        final violations = analyzeBannedSymbolFile(path, config: _testConfig());
        expect(violations.map((v) => v.line), [1, 2, 5]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares dotted calls, declarations, and non-uses', () {
      final root = Directory.systemTemp.createTempSync('ban_test.');
      try {
        final path = '${root.path}/near_miss.dart';
        File(path).writeAsStringSync('''
// trace and SnackBar below are near-misses, not uses.
class SnackBar {
  const SnackBar();
}

void run(Object logger) {
  logger.trace('scoped');
  final handler = trace;
  final label = 'SnackBar';
}
''');
        final violations = analyzeBannedSymbolFile(path, config: _testConfig());
        expect(violations, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('honors except, nearest-wins, and malformed entries', () {
      final root = Directory.systemTemp.createTempSync('ban_test.');
      try {
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
banned_symbols:
  - symbol: SnackBar
    message: "route through NotificationService"
    except: ["service/**"]
  - symbol: trace
  - message: "missing symbol, skipped"
  - symbol: 42
  - symbol: Ghost
    except: "not-a-list"
''');
        Directory('${root.path}/service').createSync();
        File('${root.path}/service/notify.dart').writeAsStringSync('''
void notify(String message) {
  show(SnackBar(content: message));
}
''');
        Directory('${root.path}/ui').createSync();
        final page = '${root.path}/ui/page.dart';
        File(page).writeAsStringSync('''
void submit() {
  show(SnackBar(content: 'x'));
}
''');
        Directory('${root.path}/nested').createSync();
        File('${root.path}/nested/flutterguard.yaml').writeAsStringSync('''
banned_symbols: []
''');
        File('${root.path}/nested/inner.dart').writeAsStringSync('''
void submit() {
  show(SnackBar(content: 'x'));
}
''');
        Directory('${root.path}/other').createSync();
        File('${root.path}/other/flutterguard.yaml').writeAsStringSync('''
rules:
  all: true
''');
        File('${root.path}/other/o.dart').writeAsStringSync('''
void submit() {
  show(SnackBar(content: 'x'));
}
''');

        expect(
          analyzeBannedSymbolFile('${root.path}/service/notify.dart'),
          isEmpty,
          reason: 'except glob silences the service file',
        );
        final pageViolations = analyzeBannedSymbolFile(page);
        expect(pageViolations.map((v) => v.line), [2]);
        expect(
          pageViolations.single.message,
          contains('route through NotificationService'),
        );
        expect(
          analyzeBannedSymbolFile('${root.path}/nested/inner.dart'),
          isEmpty,
          reason: 'nearest config wins: empty list, no merging',
        );
        expect(
          analyzeBannedSymbolFile('${root.path}/other/o.dart'),
          isEmpty,
          reason: 'nearest config without the section is silent',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('is silent without configuration', () {
      final root = Directory.systemTemp.createTempSync('ban_test.');
      try {
        final path = '${root.path}/plain.dart';
        File(path).writeAsStringSync('''
void run() {
  show(SnackBar(content: Text('x')));
}
''');
        expect(analyzeBannedSymbolFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
