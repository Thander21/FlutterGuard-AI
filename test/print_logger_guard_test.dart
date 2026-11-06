import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LOG-019 print logger guard', () {
    test('flags print calls in the golden bad vector', () {
      final violations = analyzeLogFile(
        'benchmark/vectors/tc19/TC-19_log.bad.dart',
      );
      expect(violations.map((v) => v.line), [5, 6, 7]);
      expect(violations.first.message, contains("'print'"));
      expect(violations.first.message, contains('use AppLogger'));
      expect(violations.last.message, contains("'tattle'"));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeLogFile(
        'benchmark/vectors/tc19/TC-19_log.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('spares dotted calls, comments, and the default boundary', () {
      final root = Directory.systemTemp.createTempSync('log_test.');
      try {
        final path = '${root.path}/near_miss.dart';
        File(path).writeAsStringSync('''
// print('x') here is a comment, not a call.
void run() {
  stderr.writeln('dotted');
  log('not in the default set');
}
''');
        final violations = analyzeLogFile(path, config: const FlatRuleConfig());
        expect(violations, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('honors except, empty-map, and lenient degrade', () {
      final root = Directory.systemTemp.createTempSync('log_test.');
      try {
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
print_logger:
  symbols: [log]
  except: ["log/**"]
  message: "use AppLogger"
''');
        Directory('${root.path}/log').createSync();
        File('${root.path}/log/sink.dart').writeAsStringSync('''
void emit(String message) {
  print(message);
  debugPrint(message);
}
''');
        Directory('${root.path}/ui').createSync();
        final page = '${root.path}/ui/page.dart';
        File(page).writeAsStringSync('''
void submit() {
  print('x');
  debugPrint('y');
  log('z');
}
''');
        Directory('${root.path}/plain').createSync();
        File('${root.path}/plain/flutterguard.yaml').writeAsStringSync('''
print_logger: {}
''');
        File('${root.path}/plain/a.dart').writeAsStringSync('''
void submit() {
  print('x');
  log('not configured here');
}
''');
        Directory('${root.path}/messy').createSync();
        File('${root.path}/messy/flutterguard.yaml').writeAsStringSync('''
print_logger:
  symbols: "not-a-list"
  except: 42
  message: 7
''');
        File('${root.path}/messy/b.dart').writeAsStringSync('''
void submit() {
  print('x');
}
''');

        expect(
          analyzeLogFile('${root.path}/log/sink.dart'),
          isEmpty,
          reason: 'except glob silences the logger implementation',
        );
        final pageViolations = analyzeLogFile(page);
        expect(pageViolations.map((v) => v.line), [2, 3, 4]);
        expect(pageViolations.first.message, contains('use AppLogger'));
        final plainViolations = analyzeLogFile('${root.path}/plain/a.dart');
        expect(plainViolations.map((v) => v.line), [
          2,
        ], reason: 'empty map enables defaults only (log stays clean)');
        expect(
          plainViolations.single.message,
          contains('route it through the logger'),
        );
        final messyViolations = analyzeLogFile('${root.path}/messy/b.dart');
        expect(messyViolations.map((v) => v.line), [
          2,
        ], reason: 'malformed fields degrade leniently, defaults flag');
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('is silent without configuration', () {
      final root = Directory.systemTemp.createTempSync('log_test.');
      try {
        final path = '${root.path}/plain.dart';
        File(path).writeAsStringSync('''
void run() {
  print('x');
  debugPrint('y');
}
''');
        expect(analyzeLogFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
