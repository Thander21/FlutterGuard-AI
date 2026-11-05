import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ST-005 state mutation guard', () {
    test('flags in-place mutations in Notifier and Cubit', () {
      final violations = analyzeStateMutationFile(
        'benchmark/vectors/TC-08_st.bad.dart',
      );
      expect(violations.map((v) => v.line), [11, 25]);
      expect(violations.first.message, contains("'add'"));
      expect(violations.first.message, contains('in place'));
      expect(violations.first.message, contains('copyWith'));
    });

    test('spares replaced state (zero false positives)', () {
      final violations = analyzeStateMutationFile(
        'benchmark/vectors/TC-08_st.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags assignments, ++, and clear on state receivers', () {
      final root = Directory.systemTemp.createTempSync('st005_test.');
      try {
        final path = '${root.path}/writes.dart';
        File(path).writeAsStringSync('''
class Holder extends Notifier<CartState> {
  @override
  CartState build() => CartState([]);

  void poke() {
    state.count = 1;
    state.count += 1;
    state.count++;
    state.items.clear();
  }
}
''');
        final violations = analyzeStateMutationFile(path);
        expect(violations.map((v) => v.line), [6, 7, 8, 9]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares state-like mutations outside holder classes', () {
      final root = Directory.systemTemp.createTempSync('st005_test.');
      try {
        final path = '${root.path}/helper.dart';
        File(path).writeAsStringSync('''
class Helper {
  final List<String> items = [];
  List<String> state = [];

  void addItem(String item) {
    items.add(item);
    state.add(item);
  }
}
''');
        expect(analyzeStateMutationFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares copies and reads inside holders', () {
      final root = Directory.systemTemp.createTempSync('st005_test.');
      try {
        final path = '${root.path}/reads.dart';
        File(path).writeAsStringSync('''
class CartItems extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void inspect() {
    final copy = state.toList();
    copy.add('x');
    state.toList().add('y');
    debugPrint('\${state.length}');
  }
}
''');
        expect(analyzeStateMutationFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags state cascades exactly once', () {
      final root = Directory.systemTemp.createTempSync('st005_test.');
      try {
        final path = '${root.path}/cascade.dart';
        File(path).writeAsStringSync('''
class CartItems extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void fill() {
    state..add('a')..add('b');
  }
}
''');
        final violations = analyzeStateMutationFile(path);
        expect(violations.map((v) => v.line), [6]);
        expect(violations.single.message, contains("'add'"));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('matches Notifier variants by suffix', () {
      final root = Directory.systemTemp.createTempSync('st005_test.');
      try {
        final path = '${root.path}/family.dart';
        File(path).writeAsStringSync('''
class CartFamily extends FamilyNotifier<List<String>, String> {
  @override
  List<String> build(String id) => [];

  void addItem(String item) {
    state.add(item);
  }
}
''');
        final violations = analyzeStateMutationFile(path);
        expect(violations.map((v) => v.line), [6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
