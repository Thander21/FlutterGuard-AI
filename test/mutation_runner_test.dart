// SYS-MUT-001 contract test: rewriter units, the canary pair
// (complacent test FAILs, honest test PASSes), the timeout breaker,
// the relative-import guard, and the zero-mutant PASS.
//
// Runner tests stage real `dart test` subprocess runs under
// fixtures/mutation/<runId>/ (volatile, gitignored) with fixture
// inputs under the system temp dir; both are removed in tearDown.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('findMutants', () {
    test('finds the 3 operators with replacements, ordered by offset', () {
      const source = '''
bool gt(int a, int b) => a > b;
bool eq(int a, int b) => a == b;
bool ge(int a) => a >= 10;
bool yes() => true;
''';
      final mutants = findMutants(source);
      expect(mutants.map((m) => m.original), ['>', '==', '>=', 'true']);
      expect(mutants.map((m) => m.replacement), ['<', '!=', '<=', 'false']);
      expect(mutants.map((m) => m.line), [1, 2, 3, 4]);
      final offsets = mutants.map((m) => m.offset).toList();
      expect(offsets, orderedEquals([...offsets]..sort()));
    });

    test('ignores strings, comments, generics, false, and inverse ops', () {
      const source = '''
// a > b == c >= d
String s = 'x > y == z';
List<int> xs = [];
bool lt(int a, int b) => a < b;
bool ne(int a, int b) => a != b;
bool le(int a, int b) => a <= b;
bool no() => false;
''';
      expect(findMutants(source), isEmpty);
    });
  });

  group('applyMutant', () {
    test('rewrites only the single site', () {
      const source = 'bool gt(int a, int b) => a > b;\n';
      final mutant = findMutants(source).single;
      expect(applyMutant(source, mutant),
          'bool gt(int a, int b) => a < b;\n');
    });

    test('rejects a mutant from another source', () {
      const source = 'bool gt(int a, int b) => a > b;\n';
      final mutant = findMutants(source).single;
      expect(() => applyMutant('bool other() => true;\n', mutant),
          throwsStateError);
    });
  });

  group('MutationRunner', () {
    late Directory inputs;
    late List<String> runIds;

    setUp(() {
      inputs = Directory.systemTemp.createTempSync('mut_inputs_');
      runIds = [];
      addTearDown(() {
        if (inputs.existsSync()) inputs.deleteSync(recursive: true);
        for (final id in runIds) {
          final dir = Directory('fixtures/mutation/$id');
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      });
    });

    /// Writes a nested `lib/target.dart` + `test/target_test.dart` pair
    /// (import `'../lib/target.dart'`) and returns the [source, test].
    List<String> writePair(String name, String source, String test) {
      final lib = Directory('${inputs.path}/$name/lib')
        ..createSync(recursive: true);
      final testDir = Directory('${inputs.path}/$name/test')
        ..createSync(recursive: true);
      final sourceFile = File('${lib.path}/target.dart')
        ..writeAsStringSync(source);
      final testFile = File('${testDir.path}/target_test.dart')
        ..writeAsStringSync(test);
      return [sourceFile.path, testFile.path];
    }

    String nextId(String name) {
      final id =
          't${pid}_${DateTime.now().microsecondsSinceEpoch}_$name';
      runIds.add(id);
      return id;
    }

    test('canary: complacent test survives the mutant (FAIL)', () async {
      final pair = writePair('complacent', 'bool isAboveZero(int n) => n > 0;\n', '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('complacent', () {
    expect(isAboveZero, isNotNull);
  });
}
''');
      final verdict = await MutationRunner().run(
          sourcePath: pair[0], testPath: pair[1], runId: nextId('compl'));
      expect(verdict.passed, isFalse);
      expect(verdict.results, hasLength(1));
      expect(verdict.results.single.status, MutantStatus.survived);
      expect(verdict.results.single.exitCode, 0);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('honest test kills the mutant (PASS)', () async {
      final pair = writePair('honest', 'bool isAboveZero(int n) => n > 0;\n', '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''');
      final verdict = await MutationRunner().run(
          sourcePath: pair[0], testPath: pair[1], runId: nextId('honest'));
      expect(verdict.passed, isTrue);
      expect(verdict.results.single.status, MutantStatus.killed);
      expect(verdict.results.single.exitCode, isNot(0));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('zero mutants is an honest PASS', () async {
      final pair = writePair('clean', 'int add(int a, int b) => a + b;\n', '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('adds', () {
    expect(add(1, 2), 3);
  });
}
''');
      final verdict = await MutationRunner().run(
          sourcePath: pair[0], testPath: pair[1], runId: nextId('clean'));
      expect(verdict.passed, isTrue);
      expect(verdict.results, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('breaker kills a hanging mutant run (timeout FAIL)', () async {
      final pair = writePair('hang', 'bool flag = true;\nbool getFlag() => flag;\n', '''
import 'dart:async';
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('hangs on mutant', () async {
    if (!getFlag()) {
      await Completer<void>().future;
    }
  });
}
''');
      final verdict = await MutationRunner().run(
          sourcePath: pair[0], testPath: pair[1], runId: nextId('hang'));
      expect(verdict.passed, isFalse);
      expect(verdict.results.single.status, MutantStatus.timeout);
      expect(verdict.results.single.exitCode, -1);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('red baseline refuses to judge mutants', () async {
      final pair = writePair('red', 'bool isAboveZero(int n) => n > 0;\n', '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('broken', () {
    expect(isAboveZero(1), isFalse);
  });
}
''');
      await expectLater(
          MutationRunner().run(
              sourcePath: pair[0], testPath: pair[1], runId: nextId('red')),
          throwsStateError);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('rejects a test that does not relatively import the source',
        () async {
      final lib = Directory('${inputs.path}/orphan/lib')
        ..createSync(recursive: true);
      final source = File('${lib.path}/target.dart')
        ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
      final test = File('${inputs.path}/orphan/lonely_test.dart')
        ..writeAsStringSync('''
import 'package:test/test.dart';
void main() {
  test('lonely', () {
    expect(1, 1);
  });
}
''');
      await expectLater(
          MutationRunner().run(
              sourcePath: source.path,
              testPath: test.path,
              runId: nextId('orphan')),
          throwsArgumentError);
    });

    test('rejects missing files, identical paths, and bad timeouts',
        () async {
      final runner = MutationRunner();
      await expectLater(
          runner.run(sourcePath: 'nope.dart', testPath: 'nope_test.dart'),
          throwsArgumentError);
      await expectLater(
          MutationRunner(timeout: Duration.zero)
              .run(sourcePath: 'a.dart', testPath: 'b.dart'),
          throwsArgumentError);
      final same = File('${inputs.path}/same.dart')
        ..writeAsStringSync('int x = 1;\n');
      await expectLater(
          runner.run(sourcePath: same.path, testPath: same.path),
          throwsArgumentError);
    });
  });
}
