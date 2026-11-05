import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ARCH-003 arch layer guard', () {
    test('flags persistence/network imports in a widget file', () {
      final violations = analyzeArchFile(
        'benchmark/vectors/TC-05_arch.bad.dart',
      );
      expect(violations.map((v) => v.line), [4, 6]);
      expect(violations.first.message, contains('drift'));
      expect(violations.last.message, contains('dio'));
      expect(violations.first.message, contains('data layer'));
    });

    test('spares the delegating widget (zero false positives)', () {
      final violations = analyzeArchFile(
        'benchmark/vectors/TC-05_arch.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('spares denylisted imports in a non-widget file', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/app_db.dart';
        File(path).writeAsStringSync('''
import 'package:drift/drift.dart';

class AppDatabase extends Database {
  AppDatabase(super.executor);
}
''');
        expect(analyzeArchFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags a denylisted export in a widget file', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/cart_screen.dart';
        File(path).writeAsStringSync('''
import 'package:flutter/widgets.dart';
export 'package:dio/dio.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => const Text('cart');
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [2]);
        expect(violations.single.message, contains('dio'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('matches custom widget bases by the Widget suffix', () {
      final root = Directory.systemTemp.createTempSync('arch_test.');
      try {
        final path = '${root.path}/base_button.dart';
        File(path).writeAsStringSync('''
import 'package:sqlite3/sqlite3.dart';

class BaseButton extends AppButtonWidget {
  const BaseButton({super.key});
}
''');
        final violations = analyzeArchFile(path);
        expect(violations.map((v) => v.line), [1]);
        expect(violations.single.message, contains('sqlite3'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
