// FG-SYNC-034 contract test: flags blocking sync I/O in
// frame-critical scopes (measured build flow + on* handlers).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-SYNC-034 sync-jank guard', () {
    test('flags the .bad vector at exact lines', () {
      final violations = analyzeSyncJankFile(
        'benchmark/vectors/TC-34_sync.bad.dart',
      );
      expect(violations.map((v) => v.line), [16, 17, 18, 21, 39, 55]);
      expect(violations.first.message, contains('readAsStringSync'));
    });

    test('spares the .good vector (zero false positives)', () {
      final violations = analyzeSyncJankFile(
        'benchmark/vectors/TC-34_sync.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags nested-handler and Widget-function shapes', () {
      final root = Directory.systemTemp.createTempSync('sync_test.');
      try {
        final path = '${root.path}/nested.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
Widget badge(String label) {
  final size = File('badge.txt').statSync();
  return Text('\$label \$size');
}
class W extends StatelessWidget {
  const W({super.key});
  @override
  Widget build(BuildContext context) {
    compute(_warm);
    return TextButton(
      onPressed: () {
        items.forEach((item) {
          File(item).deleteSync();
        });
      },
      child: const Text('go'),
    );
  }
}
''');
        final violations = analyzeSyncJankFile(path);
        expect(violations.map((v) => v.line), [3, 14]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares assignments, lowercase args, and dotted sleep', () {
      final root = Directory.systemTemp.createTempSync('sync_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
class W extends StatelessWidget {
  const W({super.key});
  @override
  Widget build(BuildContext context) {
    data.resync();
    DataSync();
    button.onPressed = () {
      File('x.txt').readAsStringSync();
    };
    return Picker(
      only: () {
        File('y.txt').readAsStringSync();
      },
      child: const Text('pick'),
    );
  }
  void refresh() {
    setState(() {
      sleep(const Duration(milliseconds: 10));
    });
    io.sleep(const Duration(milliseconds: 10));
    alarm.sleep();
  }
}
''');
        expect(analyzeSyncJankFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
