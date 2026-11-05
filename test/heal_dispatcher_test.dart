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

const _asyncFixture = '''
Future<void> submit(BuildContext context) async {
  await save();
  Navigator.of(context).pop();
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
      final file = File('${root.path}/$name')..writeAsStringSync(content);
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
      expect(File(path).readAsStringSync(), 'line one\nline two\nline three\n');
      expect(File('$path.heal-report.md').existsSync(), isTrue);
    });

    test('detect crash rolls back immediately with a report', () {
      final path =
          writeFixture('crash.dart', 'line one\nline two\nline three\n');
      List<RuleViolation> crashing(String _) => throw StateError('boom');

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
      expect(File(path).readAsStringSync(), 'line one\nline two\nline three\n');
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
      final path =
          writeFixture('stub.dart', 'line one\nline two\nline three\n');
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
      expect(File(path).readAsStringSync(), 'line one\nline two\nline three\n');
      final report = File('$path.heal-report.md');
      expect(report.existsSync(), isTrue);
      expect(report.readAsStringSync(), contains('FG-STUB-001'));
      expect(report.readAsStringSync(), contains('3/3'));
      expect(report.readAsStringSync(), contains('Attack the Premise'));
    });

    group('fast-path recipe table (SYS-REL-001 R4)', () {
      test('table pins exactly the closed mechanical list', () {
        expect(fastPathRecipes.keys,
            unorderedEquals(['FG-BLOC-001', 'FG-RIV-001', 'FG-ASYNC-002']));
        expect(healRecipeFor('FG-NOPE-000'), isNull);
        expect(healRecipeFor('FG-BLOC-001')!.guard, 'if (isClosed) return;');
        expect(healRecipeFor('FG-RIV-001')!.from, 'ref.watch');
        expect(healRecipeFor('FG-RIV-001')!.to, 'ref.read');
        expect(healRecipeFor('FG-ASYNC-002')!.guard,
            'if (!context.mounted) return;');
      });

      test('table recipe heals an ASYNC-002 fixture red to green', () {
        final path = writeFixture('async.dart', _asyncFixture);
        expect(analyzeAsyncFile(path), hasLength(1));

        final result = HealDispatcher().healFile(
          path: path,
          recipe: healRecipeFor('FG-ASYNC-002')!,
          analyze: analyzeAsyncFile,
        );

        expect(result.success, isTrue);
        expect(analyzeAsyncFile(path), isEmpty);
      });

      test('table recipe heals a RIV-001 fixture red to green', () {
        final path = writeFixture('riv_table.dart', _rivFixture);
        expect(analyzeRiverpodFile(path), hasLength(1));

        final result = HealDispatcher().healFile(
          path: path,
          recipe: healRecipeFor('FG-RIV-001')!,
          analyze: analyzeRiverpodFile,
        );

        expect(result.success, isTrue);
        expect(analyzeRiverpodFile(path), isEmpty);
      });
    });
  });
}
