import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ASYNC-002 async context guard', () {
    test('flags context and setState used after an async gap', () {
      final violations = analyzeAsyncFile(
        'benchmark/vectors/TC-06_async.bad.dart',
      );
      expect(violations.map((v) => v.line), [16, 21]);
      expect(violations.first.message, contains('BuildContext'));
      expect(violations.first.message, contains('mounted'));
      expect(violations.last.message, contains('setState'));
    });

    test('spares guarded uses (zero false positives)', () {
      final violations = analyzeAsyncFile(
        'benchmark/vectors/TC-06_async.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('scans helpers and re-arms on a later await', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/helper.dart';
        File(path).writeAsStringSync('''
Future<void> submitOrder(BuildContext context) async {
  await _service.process();
  if (!context.mounted) return;
  Navigator.of(context).pop();
  await _audit.log();
  Navigator.of(context).pop();
}
''');
        final violations = analyzeAsyncFile(path);
        expect(violations.map((v) => v.line), [6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares await and use in a single statement', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/confirm.dart';
        File(path).writeAsStringSync('''
Future<void> confirm(BuildContext context) async {
  await showDialog(context: context, builder: (_) => const Text('ok'));
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('nested closure awaits never arm the outer body', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/outer.dart';
        File(path).writeAsStringSync('''
Future<void> outer(BuildContext context) async {
  runLater(() async {
    await _work();
  });
  Navigator.of(context).pop();
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags gaps threaded through try blocks', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/load.dart';
        File(path).writeAsStringSync('''
Future<void> load(BuildContext context) async {
  try {
    await _service.fetch();
    Navigator.of(context).pop();
  } catch (_) {}
}
''');
        final violations = analyzeAsyncFile(path);
        expect(violations.map((v) => v.line), [4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags inner gaps of an unarmed if branch', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/maybe.dart';
        File(path).writeAsStringSync('''
Future<void> maybeLoad(bool flag, BuildContext context) async {
  if (flag) {
    await _service.fetch();
    Navigator.of(context).pop();
  }
}
''');
        final violations = analyzeAsyncFile(path);
        expect(violations.map((v) => v.line), [4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares statement labels named context (SYS-CAL-002 P1-4)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/labeled.dart';
        File(path).writeAsStringSync('''
Future<void> retry() async {
  await _service.ping();
  context: for (var i = 0; i < 1; i++) {
    _log(i);
  }
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
