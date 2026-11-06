import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ASYNC-002 async context guard', () {
    test('flags context and setState used after an async gap', () {
      final violations = analyzeAsyncFile(
        'benchmark/vectors/TC-06_async.bad.dart',
      );
      expect(violations.map((v) => v.line), [16, 21, 31]);
      expect(violations.first.message, contains('BuildContext'));
      expect(violations.first.message, contains('mounted'));
      expect(violations[1].message, contains('setState'));
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

    test('spares catch variables named context (SYS-CAL-003 R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/caught.dart';
        File(path).writeAsStringSync('''
Future<void> load() async {
  try {
    await _service.fetch();
  } catch (context) {
    _log(context);
  }
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares loop variables named context (R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/zones.dart';
        File(path).writeAsStringSync('''
Future<void> loadAll(List<Zone> zones) async {
  for (final context in zones) {
    await _service.fetch();
    _log(context);
  }
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares untyped redeclared parameters (R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/bus.dart';
        File(path).writeAsStringSync('''
Future<void> emitReady(dynamic context) async {
  await _service.ping();
  _bus.send(context);
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares mounted blocks in closures inside try (R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/open.dart';
        File(path).writeAsStringSync('''
Future<void> open(BuildContext context) async {
  try {
    await _service.open();
    schedule(() {
      if (context.mounted) {
        Navigator.of(context).push(route);
      }
    });
  } catch (_) {
    _log('open failed');
  }
}
''');
        expect(analyzeAsyncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags unguarded deferred uses inside closures (R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/deferred.dart';
        File(path).writeAsStringSync('''
Future<void> save(BuildContext context) async {
  await _service.save();
  runLater(() {
    Navigator.of(context).pop();
  });
}
''');
        final violations = analyzeAsyncFile(path);
        expect(violations.map((v) => v.line), [4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags this.context uses after a gap (R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/receiver.dart';
        File(path).writeAsStringSync('''
Future<void> refresh() async {
  await _service.reload();
  Navigator.of(this.context).pop();
}
''');
        final violations = analyzeAsyncFile(path);
        expect(violations.map((v) => v.line), [3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('still flags uses re-armed inside mounted blocks (R2-1)', () {
      final root = Directory.systemTemp.createTempSync('async_test.');
      try {
        final path = '${root.path}/stale.dart';
        File(path).writeAsStringSync('''
Future<void> sync(BuildContext context) async {
  if (mounted) {
    await _service.sync();
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
  });
}
