import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-CTX-006 context scope guard', () {
    test('flags context bound to service objects', () {
      final violations = analyzeContextScopeFile(
        'benchmark/vectors/TC-09_ctx.bad.dart',
      );
      expect(violations.map((v) => v.line), [9, 18]);
      expect(violations.first.message, contains('BuildContext'));
      expect(violations.first.message, contains('pass data'));
    });

    test('spares widgets and free helpers (zero false positives)', () {
      final violations = analyzeContextScopeFile(
        'benchmark/vectors/TC-09_ctx.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags stored context even inside State', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/cached.dart';
        File(path).writeAsStringSync('''
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  BuildContext? cached;

  @override
  Widget build(BuildContext context) => const Text('x');
}
''');
        final violations = analyzeContextScopeFile(path);
        expect(violations.map((v) => v.line), [8]);
        expect(violations.single.message, contains('stored'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags stored globals, spares service return types (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/service.dart';
        File(path).writeAsStringSync('''
BuildContext? activeContext;

class CartService {
  BuildContext current() => throw UnimplementedError();
}
''');
        final violations = analyzeContextScopeFile(path);
        expect(violations.map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares extensions with context parameters (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/extensions.dart';
        File(path).writeAsStringSync('''
extension PopX on BuildContext {
  void popTwice() {
    Navigator.of(this).pop();
  }
}

extension StrX on String {
  void showIn(BuildContext context) {}
}
''');
        expect(analyzeContextScopeFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares ConsumerState scope', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/consumer.dart';
        File(path).writeAsStringSync('''
class CartState extends ConsumerState<CartScreen> {
  void refresh(BuildContext context) {}
}
''');
        expect(analyzeContextScopeFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags fields in Bloc-state subclasses (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/saved.dart';
        File(path).writeAsStringSync('''
class CartSaved extends CartState {
  CartSaved(this.context);
  final BuildContext context;
}
''');
        final violations = analyzeContextScopeFile(path);
        expect(violations.map((v) => v.line), [3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares locals, casts, and type arguments (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/flow.dart';
        File(path).writeAsStringSync('''
class CartService {
  void checkout(BuildContext context) {
    final BuildContext current = context;
    final queue = <BuildContext>[];
    final raw = context as BuildContext;
    _api.pay();
  }
}
''');
        expect(analyzeContextScopeFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares function-typed fields (R2-3)', () {
      final root = Directory.systemTemp.createTempSync('ctx_test.');
      try {
        final path = '${root.path}/callbacks.dart';
        File(path).writeAsStringSync('''
class Buttons {
  final void Function(BuildContext context)? onTap;
  final BuildContext Function()? fetch;
}
''');
        expect(analyzeContextScopeFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
