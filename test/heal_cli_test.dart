// Thin `heal` CLI contract (SYS-HEAL-001 §2 Wave 2): exit codes,
// red-to-green per fast-path rule through the real analyzers,
// rollback + report, guided no-rule behavior, JSON map. In-process
// calls (check_cli_test idiom); violating fixtures live in temp dirs
// (never in-tree: dogfood asserts the repo self-clean).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

const _blocFixture = '''
class CartCubit extends Cubit<CartState> {
  Future<void> checkout() async {
    emit(CartSaving());
    await _repository.save();
    emit(CartSaved());
  }
}
''';

const _blocDoubleFixture = '''
class CartCubit extends Cubit<CartState> {
  Future<void> checkout() async {
    emit(CartSaving());
    await _repository.save();
    emit(CartSaved());
    await _repository.log();
    emit(CartLogged());
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
  group('heal cli', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('heal_cli_test.');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    String writeFixture(String name, String content) {
      final file = File('${root.path}/$name')..writeAsStringSync(content);
      return file.path;
    }

    test('returns 2 on missing, doubled, or unknown arguments', () {
      expect(heal([]), 2);
      expect(heal(['a.dart', 'b.dart']), 2);
      expect(heal(['--bogus', 'a.dart']), 2);
    });

    test('returns 2 on missing, directory, or non-dart targets', () {
      final missing = '${root.path}/nope.dart';
      expect(heal([missing, '--rule', 'FG-BLOC-001']), 2);
      expect(heal([root.path, '--rule', 'FG-BLOC-001']), 2);
      final notes = writeFixture('notes.txt', 'plain text\n');
      expect(heal([notes, '--rule', 'FG-BLOC-001']), 2);
    });

    test('prints usage and returns 0 on --help', () {
      expect(heal(['--help']), isZero);
      expect(heal(['-h']), isZero);
    });

    test('returns 2 on unknown or non-mechanical rules', () {
      final path = writeFixture('bloc.dart', _blocFixture);
      expect(heal([path, '--rule', 'FG-NOPE-999']), 2);
      expect(
        heal([path, '--rule', 'FG-ST-001']),
        2,
        reason: 'registry rule without a fast-path recipe',
      );
    });

    test('returns 2 on out-of-range --attempts', () {
      final path = writeFixture('clean.dart', 'void main() {}\n');
      for (final attempts in ['0', '-1', '11', 'abc']) {
        expect(
          heal([path, '--attempts', attempts]),
          2,
          reason: 'attempts=$attempts',
        );
      }
    });

    test('missing --rule guides (2) or reports clean (0)', () {
      final red = writeFixture('riv.dart', _rivFixture);
      expect(heal([red]), 2);
      final clean = writeFixture('clean.dart', 'void main() {}\n');
      expect(heal([clean]), isZero);
    });

    test('heals a BLOC-001 fixture red to green', () {
      final path = writeFixture('bloc.dart', _blocFixture);
      expect(analyzeBlocFile(path), hasLength(1));
      expect(heal([path, '--rule', 'FG-BLOC-001']), isZero);
      expect(analyzeBlocFile(path), isEmpty);
      expect(File('$path.heal-report.md').existsSync(), isFalse);
    });

    test('heals RIV-001 and ASYNC-002 fixtures red to green', () {
      final riv = writeFixture('riv.dart', _rivFixture);
      expect(heal([riv, '--rule', 'FG-RIV-001']), isZero);
      expect(analyzeRiverpodFile(riv), isEmpty);

      final async = writeFixture('async.dart', _asyncFixture);
      expect(heal([async, '--rule', 'FG-ASYNC-002']), isZero);
      expect(analyzeAsyncFile(async), isEmpty);
    });

    test('already-green input exits 0 with zero writes', () {
      const content = 'void main() {}\n';
      final path = writeFixture('clean.dart', content);
      expect(heal([path, '--rule', 'FG-BLOC-001']), isZero);
      expect(File(path).readAsStringSync(), content);
      expect(File('$path.heal-report.md').existsSync(), isFalse);
    });

    test('cap exhaustion rolls back with a report (exit 1)', () {
      final path = writeFixture('double.dart', _blocDoubleFixture);
      expect(analyzeBlocFile(path), hasLength(2));
      expect(heal([path, '--rule', 'FG-BLOC-001', '--attempts', '1']), 1);
      expect(File(path).readAsStringSync(), _blocDoubleFixture);
      expect(File('$path.heal-report.md').existsSync(), isTrue);
    });

    test('--attempts override converges a double violation', () {
      final path = writeFixture('double.dart', _blocDoubleFixture);
      expect(heal([path, '--rule', 'FG-BLOC-001', '--attempts', '2']), isZero);
      expect(analyzeBlocFile(path), isEmpty);
    });

    test('accepts --json without changing exit codes', () {
      final clean = writeFixture('clean.dart', 'void main() {}\n');
      expect(heal(['--json', clean, '--rule', 'FG-BLOC-001']), isZero);
      final double = writeFixture('double.dart', _blocDoubleFixture);
      expect(
        heal([double, '--rule', 'FG-BLOC-001', '--attempts', '1', '--json']),
        1,
      );
    });

    test('healResultJson carries the documented shape', () {
      final map = healResultJson(
        target: 'a.dart',
        ruleId: 'FG-RIV-001',
        result: HealResult(
          success: false,
          attempts: 3,
          rolledBack: true,
          errors: const [
            HealError(
              attempt: 1,
              phase: 'patch',
              target: 'a.dart',
              ruleId: 'FG-RIV-001',
              error: 'no-op: premise exhausted',
            ),
          ],
          report: '# report',
        ),
      );
      expect(map, {
        'success': false,
        'attempts': 3,
        'rolled_back': true,
        'rule_id': 'FG-RIV-001',
        'target': 'a.dart',
        'errors': [
          {
            'attempt': 1,
            'phase': 'patch',
            'target': 'a.dart',
            'rule_id': 'FG-RIV-001',
            'error': 'no-op: premise exhausted',
          },
        ],
        'report': '# report',
      });
    });
  });
}
