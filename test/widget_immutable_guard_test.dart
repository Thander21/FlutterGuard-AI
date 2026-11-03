import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-WID-008 widget immutable guard', () {
    test('flags mutable fields in a StatelessWidget', () {
      final violations =
          analyzeWidgetImmutableFile('benchmark/vectors/TC-10_wid.bad.dart');
      expect(violations.map((v) => v.line), [9, 10]);
      expect(violations.first.message, contains("'count'"));
      expect(violations.first.message, contains('immutable'));
    });

    test('spares immutable widgets (zero false positives)', () {
      final violations =
          analyzeWidgetImmutableFile('benchmark/vectors/TC-10_wid.good.dart');
      expect(violations, isEmpty);
    });

    test('flags mutable fields in a ConsumerWidget', () {
      final root = Directory.systemTemp.createTempSync('wid_test.');
      try {
        final path = '${root.path}/badge.dart';
        File(path).writeAsStringSync('''
class CartBadge extends ConsumerWidget {
  CartBadge({super.key, required this.count});

  int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('\$count');
  }
}
''');
        final violations = analyzeWidgetImmutableFile(path);
        expect(violations.map((v) => v.line), [4]);
        expect(violations.single.message, contains('ConsumerWidget'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares mutable fields in a StatefulWidget', () {
      final root = Directory.systemTemp.createTempSync('wid_test.');
      try {
        final path = '${root.path}/screen.dart';
        File(path).writeAsStringSync('''
class CartScreen extends StatefulWidget {
  CartScreen({super.key, this.initial = 0});

  int initial;

  @override
  State<CartScreen> createState() => _CartScreenState();
}
''');
        expect(analyzeWidgetImmutableFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares late final, flags late mutable', () {
      final root = Directory.systemTemp.createTempSync('wid_test.');
      try {
        final path = '${root.path}/mixed.dart';
        File(path).writeAsStringSync('''
class MixedLabel extends StatelessWidget {
  MixedLabel({super.key});

  late final String cached;
  late int mutationCount;

  @override
  Widget build(BuildContext context) => Text(cached);
}
''');
        final violations = analyzeWidgetImmutableFile(path);
        expect(violations.map((v) => v.line), [5]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares mutable fields in a plain class', () {
      final root = Directory.systemTemp.createTempSync('wid_test.');
      try {
        final path = '${root.path}/counter.dart';
        File(path).writeAsStringSync('''
class Counter {
  int count = 0;

  void increment() {
    count++;
  }
}
''');
        expect(analyzeWidgetImmutableFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
