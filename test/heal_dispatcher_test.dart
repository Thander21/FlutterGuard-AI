import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

class _StubViolation implements RuleViolation {
  @override
  int get line => 2;

  @override
  String get message => 'stub';
}

const _blocFixture = '''
class CartCubit extends Cubit<CartState> {
  Future<void> checkout() async {
    emit(CartSaving());
    await _repository.save();
    emit(CartSaved());
  }
}
''';

const _rivFixture = '''
void setup() {
  register(
    onTap: () {
      final current = ref.watch(counterProvider);
    },
  );
}
''';

void main() {
  group('SYS-HEAL-001 heal dispatcher', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('heal_test.');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    String writeFixture(String name, String content) {
      final file = File('${root.path}/$name')
        ..writeAsStringSync(content);
      return file.path;
    }

    test('red to patch to green on a BLOC-001 fixture', () {
      final path = writeFixture('bloc.dart', _blocFixture);
      expect(analyzeBlocFile(path), hasLength(1));

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.insert(
          ruleId: 'FG-BLOC-001',
          guard: 'if (isClosed) return;',
        ),
        analyze: analyzeBlocFile,
      );

      expect(result.success, isTrue);
      expect(result.attempts, 1);
      expect(result.rolledBack, isFalse);
      expect(analyzeBlocFile(path), isEmpty);
      expect(File('$path.heal-report.md').existsSync(), isFalse);
    });

    test('replace strategy heals a ref.watch fixture', () {
      final path = writeFixture('riv.dart', _rivFixture);
      expect(analyzeRiverpodFile(path), hasLength(1));

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.replace(
          ruleId: 'FG-RIV-001',
          from: 'ref.watch',
          to: 'ref.read',
        ),
        analyze: analyzeRiverpodFile,
      );

      expect(result.success, isTrue);
      expect(analyzeRiverpodFile(path), isEmpty);
    });

    test('insert no-op stops without burning the cap, rolls back', () {
      final path =
          writeFixture('noop.dart', 'guard();\nline two\nline three\n');
      List<RuleViolation> alwaysRed(String _) => [_StubViolation()];

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.insert(
          ruleId: 'FG-STUB-001',
          guard: 'guard();',
        ),
        analyze: alwaysRed,
      );

      expect(result.success, isFalse);
      expect(result.attempts, 1,
          reason: 'premise exhausted: the cap is not burned');
      expect(result.rolledBack, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.phase, 'patch');
      expect(File(path).readAsStringSync(), 'guard();\nline two\nline three\n');
      final report = File('$path.heal-report.md');
      expect(report.existsSync(), isTrue);
      expect(report.readAsStringSync(), contains('no-op'));
      expect(report.readAsStringSync(), contains('Attack the Premise'));
    });

    test('replace no-op stops without burning the cap, rolls back', () {
      final path =
          writeFixture('noop.dart', 'line one\nline two\nline three\n');
      List<RuleViolation> alwaysRed(String _) => [_StubViolation()];

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.replace(
          ruleId: 'FG-STUB-001',
          from: 'absent-token',
          to: 'replacement',
        ),
        analyze: alwaysRed,
      );

      expect(result.success, isFalse);
      expect(result.attempts, 1);
      expect(result.rolledBack, isTrue);
      expect(File(path).readAsStringSync(),
          'line one\nline two\nline three\n');
      expect(File('$path.heal-report.md').existsSync(), isTrue);
    });

    test('detect crash rolls back immediately with a report', () {
      final path =
          writeFixture('crash.dart', 'line one\nline two\nline three\n');
      List<RuleViolation> crashing(String _) =>
          throw StateError('boom');

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.insert(
          ruleId: 'FG-STUB-001',
          guard: 'guard();',
        ),
        analyze: crashing,
      );

      expect(result.success, isFalse);
      expect(result.attempts, 1);
      expect(result.rolledBack, isTrue);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.phase, 'detect');
      expect(result.errors.single.error, contains('boom'));
      expect(File(path).readAsStringSync(),
          'line one\nline two\nline three\n');
      final report = File('$path.heal-report.md');
      expect(report.existsSync(), isTrue);
      expect(report.readAsStringSync(), contains('FG-STUB-001'));
    });

    test('already-green input succeeds with zero writes', () {
      const content = 'void main() {}\n';
      final path = writeFixture('clean.dart', content);

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.insert(
          ruleId: 'FG-STUB-001',
          guard: 'guard();',
        ),
        analyze: (_) => const <RuleViolation>[],
      );

      expect(result.success, isTrue);
      expect(result.attempts, 1);
      expect(result.rolledBack, isFalse);
      expect(result.errors, isEmpty);
      expect(result.report, isEmpty);
      expect(File(path).readAsStringSync(), content);
      expect(File('$path.heal-report.md').existsSync(), isFalse);
    });

    test('persistent failure burns the cap, rolls back, reports', () {
      final path = writeFixture('stub.dart', 'line one\nline two\nline three\n');
      List<RuleViolation> alwaysRed(String _) => [_StubViolation()];

      final result = HealDispatcher().healFile(
        path: path,
        recipe: const HealRecipe.insert(
          ruleId: 'FG-STUB-001',
          guard: 'guard();',
        ),
        analyze: alwaysRed,
      );

      expect(result.success, isFalse);
      expect(result.attempts, 3);
      expect(result.rolledBack, isTrue);
      expect(File(path).readAsStringSync(),
          'line one\nline two\nline three\n');
      final report = File('$path.heal-report.md');
      expect(report.existsSync(), isTrue);
      expect(report.readAsStringSync(), contains('FG-STUB-001'));
      expect(report.readAsStringSync(), contains('3/3'));
      expect(report.readAsStringSync(), contains('Attack the Premise'));
    });
  });
}
