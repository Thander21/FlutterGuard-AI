import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ASYNC-002 async context guard', () {
    test('flags context and setState used after an async gap', () {
      final violations = analyzeAsyncFile(
        'benchmark/vectors/TC-06_async.bad.dart',
      );
      expect(violations.map((v) => v.line), [16, 21, 31, 40, 53]);
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

    test('spares context and setState before the first await (K1)', () {
      expect(
        _violationLines('''
Future<void> load() async {
  try {
    setState(() => _loading = true);
    final repo = Provider.of<Repo>(context);
    final list = await repo.list();
    if (mounted) {
      setState(() => _items = list);
    }
  } catch (_) {
    _log('load failed');
  }
}
'''),
        isEmpty,
      );
    });

    test('mounted early returns clear the gap inside nested blocks (K2)', () {
      expect(
        _violationLines('''
Future<void> remove(BuildContext context) async {
  final ok = await confirmDelete(context: context);
  if (ok != true || !context.mounted) return;
  try {
    await _repo.delete();
    if (!context.mounted) return;
    _notify(context, S.of(context)!.deleted);
  } catch (_) {
    if (!mounted) {
      return;
    }
    _notify(context, S.of(context)!.failed);
  }
}
'''),
        isEmpty,
      );
    });

    test('flags the same nested uses without the guard (K2)', () {
      expect(
        _violationLines('''
Future<void> remove(BuildContext context) async {
  final ok = await confirmDelete(context: context);
  if (ok != true) return;
  try {
    await _repo.delete();
    _notify(context, S.of(context)!.deleted);
  } catch (_) {
    _notify(context, S.of(context)!.failed);
  }
}
'''),
        [6, 8],
      );
    });

    test('spares mounted checks chained with && and nested blocks (K3)', () {
      expect(
        _violationLines('''
Future<void> check(BuildContext? context, bool quiet) async {
  final info = await fetch();
  if (info == null) {
    if (!quiet && context != null && context.mounted) {
      _show(context, 'offline');
    }
    return;
  }
  if (info.ready && mounted) {
    setState(() => _info = info);
  }
  if (info.name != null) {
    _controller.text = info.name;
    if (mounted) {
      setState(() => _named = true);
    }
  }
}
'''),
        isEmpty,
      );
    });

    test('flags a use after an || chain without a mounted check (K3)', () {
      expect(
        _violationLines('''
Future<void> check(BuildContext context, bool quiet) async {
  final info = await fetch();
  if (!quiet || mounted) {
    _show(context, 'offline');
  }
}
'''),
        [4],
      );
    });

    test('spares context inside the awaited call and its builder (K4)', () {
      expect(
        _violationLines('''
Future<void> pick(BuildContext context, bool remote) async {
  final id = await _service.installationId();
  if (!mounted) return;
  if (remote) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Text(S.of(context)!.terminalInUse),
    );
    if (ok != true) return;
  }
  _log(id);
}
'''),
        isEmpty,
      );
    });

    test('flags a use after the awaited dialog statement (K4)', () {
      expect(
        _violationLines('''
Future<void> remove(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Text(S.of(context)!.removeContact),
  );
  if (ok == true) {
    Navigator.of(context).pop();
  }
}
'''),
        [7],
      );
    });

    test('a branch that awaits and always exits does not arm the rest', () {
      expect(
        _violationLines('''
Future<void> open(BuildContext context, bool empty) async {
  if (empty) {
    if (!context.mounted) return;
    await showDialog<void>(context: context, builder: (c) => const Text(''));
    return;
  }
  await Navigator.push<bool>(context, _route());
}
'''),
        isEmpty,
      );
    });

    test('a branch that awaits without exiting still arms the rest', () {
      expect(
        _violationLines('''
Future<void> open(BuildContext context, bool empty) async {
  if (empty) {
    await _service.refresh();
  }
  await Navigator.push<bool>(context, _route());
}
'''),
        [5],
      );
    });
  });
}

/// Writes [source] to a temp file and returns the flagged line numbers.
List<int> _violationLines(String source) {
  final root = Directory.systemTemp.createTempSync('async_test.');
  try {
    final path = '${root.path}/fixture.dart';
    File(path).writeAsStringSync(source);
    return analyzeAsyncFile(path).map((v) => v.line).toList();
  } finally {
    root.deleteSync(recursive: true);
  }
}
