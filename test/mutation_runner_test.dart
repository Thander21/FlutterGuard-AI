// SYS-MUT-001 contract test: rewriter units, the canary pair
// (complacent test FAILs, honest test PASSes), the timeout breaker,
// the pair import guard, shadow-package staging with its compile
// canary, Windows Flutter-tool resolution, and the zero-mutant PASS.
//
// Runner tests stage real `dart test` subprocess runs under
// fixtures/mutation/<runId>/ (volatile, gitignored) or shadow
// packages under the system temp dir, with fixture inputs under the
// system temp dir; all are removed in tearDown.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
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
      expect(applyMutant(source, mutant), 'bool gt(int a, int b) => a < b;\n');
    });

    test('rejects a mutant from another source', () {
      const source = 'bool gt(int a, int b) => a > b;\n';
      final mutant = findMutants(source).single;
      expect(
        () => applyMutant('bool other() => true;\n', mutant),
        throwsStateError,
      );
    });
  });

  group('flutter tool resolution', () {
    test('findFlutterRoot scans PATH for an SDK bin', () {
      final temp = Directory.systemTemp.createTempSync('flutroot_');
      try {
        final root = stageFakeSdk(temp.path, 'sdk');
        final sep = Platform.isWindows ? ';' : ':';
        expect(findFlutterRoot(pathEnv: '$root/bin'), native(root));
        expect(
          findFlutterRoot(pathEnv: '${temp.path}_empty$sep$root/bin'),
          native(root),
        );
        expect(findFlutterRoot(pathEnv: temp.path), isNull);
        expect(findFlutterRoot(pathEnv: ''), isNull);
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('findFlutterRoot prefers native launchers, skips shims', () {
      final temp = Directory.systemTemp.createTempSync('flutroot_');
      try {
        final sep = Platform.isWindows ? ';' : ':';
        final cmdSdk = Directory('${temp.path}/cmdsdk')
          ..createSync(recursive: true);
        File('${cmdSdk.path}/bin/flutter.cmd')
          ..createSync(recursive: true)
          ..writeAsStringSync('x\n');
        final batSdk = Directory('${temp.path}/batsdk')
          ..createSync(recursive: true);
        File('${batSdk.path}/bin/flutter.bat')
          ..createSync(recursive: true)
          ..writeAsStringSync('x\n');
        final exeSdk = Directory('${temp.path}/exesdk')
          ..createSync(recursive: true);
        File('${exeSdk.path}/bin/flutter.exe')
          ..createSync(recursive: true)
          ..writeAsStringSync('x\n');
        final path =
            '${cmdSdk.path}/bin$sep${batSdk.path}/bin$sep${exeSdk.path}/bin';
        expect(findFlutterRoot(pathEnv: path), native(exeSdk.path));
        expect(
          findFlutterRoot(pathEnv: '${cmdSdk.path}/bin$sep${batSdk.path}/bin'),
          native(batSdk.path),
        );
        final shim = Directory('${temp.path}/shim')..createSync();
        File('${shim.path}/flutter.bat').writeAsStringSync('x\n');
        expect(findFlutterRoot(pathEnv: shim.path), isNull);
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('flutterToolCommand builds the batch-faithful invocation', () {
      final temp = Directory.systemTemp.createTempSync('fluttool_');
      try {
        final root = stageFakeSdk(temp.path, 'sdk');
        expect(flutterToolCommand(root, ['pub', 'get']), [
          '$root/bin/cache/dart-sdk/bin/dart.exe',
          '--packages=$root/packages/flutter_tools/.dart_tool/package_config.json',
          '$root/bin/cache/flutter_tools.snapshot',
          'pub',
          'get',
        ]);
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('flutterToolCommand fails closed on an incomplete SDK', () {
      final temp = Directory.systemTemp.createTempSync('fluttool_');
      try {
        const missing = [
          'bin/cache/dart-sdk/bin/dart.exe',
          'bin/cache/flutter_tools.snapshot',
          'packages/flutter_tools/.dart_tool/package_config.json',
        ];
        for (var i = 0; i < missing.length; i++) {
          final root = stageFakeSdk(temp.path, 'sdk$i', without: missing[i]);
          expect(() => flutterToolCommand(root, ['test']), throwsArgumentError);
        }
      } finally {
        temp.deleteSync(recursive: true);
      }
    });

    test('resolveFlutterCommand passes everything else through', () {
      expect(resolveFlutterCommand([]), isEmpty);
      expect(resolveFlutterCommand(['dart', 'test']), ['dart', 'test']);
      expect(
        resolveFlutterCommand(['C:/tools/dart-sdk/bin/dart.exe', '--version']),
        ['C:/tools/dart-sdk/bin/dart.exe', '--version'],
      );
    });

    test(
      'resolveFlutterCommand bypasses the batch launcher on Windows',
      skip: Platform.isWindows ? false : 'Windows path',
      () {
        final temp = Directory.systemTemp.createTempSync('flutres_');
        try {
          final root = stageFakeSdk(temp.path, 'sdk');
          final nroot = native(root);
          final dartExe = '$nroot/bin/cache/dart-sdk/bin/dart.exe';
          final snapshot = '$nroot/bin/cache/flutter_tools.snapshot';
          final packages =
              '$nroot/packages/flutter_tools/.dart_tool/package_config.json';
          expect(
            resolveFlutterCommand([
              'flutter',
              'pub',
              'get',
            ], pathEnv: '$root/bin'),
            [dartExe, '--packages=$packages', snapshot, 'pub', 'get'],
          );
          expect(resolveFlutterCommand(['$root/bin/flutter.bat', 'test']), [
            dartExe,
            '--packages=$packages',
            snapshot,
            'test',
          ]);
          final exeSdk = stageFakeSdk(temp.path, 'exesdk');
          File('$exeSdk/bin/flutter.exe').writeAsStringSync('x\n');
          expect(
            resolveFlutterCommand(['flutter', 'test'], pathEnv: '$exeSdk/bin'),
            ['$exeSdk/bin/flutter.exe', 'test'],
          );
        } finally {
          temp.deleteSync(recursive: true);
        }
      },
    );

    test(
      'resolveFlutterCommand fails closed when Flutter is unresolvable',
      skip: Platform.isWindows ? false : 'Windows path',
      () {
        final temp = Directory.systemTemp.createTempSync('flutres_');
        try {
          expect(
            () =>
                resolveFlutterCommand(['flutter', 'test'], pathEnv: temp.path),
            throwsArgumentError,
          );
          final root = stageFakeSdk(
            temp.path,
            'brokensdk',
            without: 'bin/cache/flutter_tools.snapshot',
          );
          expect(
            () => resolveFlutterCommand([
              'flutter',
              'test',
            ], pathEnv: '$root/bin'),
            throwsArgumentError,
          );
          final stray = File('${temp.path}/stray/flutter.bat')
            ..createSync(recursive: true)
            ..writeAsStringSync('x\n');
          expect(
            () => resolveFlutterCommand([stray.path, 'test']),
            throwsArgumentError,
          );
        } finally {
          temp.deleteSync(recursive: true);
        }
      },
    );
  });

  group('MutationRunner', () {
    late Directory inputs;
    late List<String> runIds;

    /// Shadow package dir for [id] under the system temp dir.
    String shadowDir(String id) =>
        '${Directory.systemTemp.path}/${MutationRunner.shadowDirPrefix}$id';

    /// Best-effort cleanup: temp/volatile litter must never mask a
    /// test outcome (a breaker-killed child may still hold file
    /// handles when this runs).
    void deleteBestEffort(Directory dir) {
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {
        // Left for the OS temp reaper / stale sweep.
      }
    }

    setUp(() {
      inputs = Directory.systemTemp.createTempSync('mut_inputs_');
      runIds = [];
      addTearDown(() {
        deleteBestEffort(inputs);
        for (final id in runIds) {
          deleteBestEffort(Directory('fixtures/mutation/$id'));
          deleteBestEffort(Directory(shadowDir(id)));
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

    /// Writes a zero-dependency package `$name/` (`pubspec.yaml` +
    /// `lib/target.dart` + `test/target_test.dart`, the test importing
    /// `package:<name>_app/target.dart`) and returns [root, source,
    /// test].
    List<String> writePackage(String name, String source, String test) {
      final root = Directory('${inputs.path}/$name')
        ..createSync(recursive: true);
      File(
        '${root.path}/pubspec.yaml',
      ).writeAsStringSync('name: ${name}_app\nenvironment:\n  sdk: ^3.13.0\n');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      final testDir = Directory('${root.path}/test')
        ..createSync(recursive: true);
      final sourceFile = File('${lib.path}/target.dart')
        ..writeAsStringSync(source);
      final testFile = File('${testDir.path}/target_test.dart')
        ..writeAsStringSync(test);
      return [root.path, sourceFile.path, testFile.path];
    }

    /// Writes a fake test-runner script (spawned with cwd = shadow
    /// root, argv = [staged test, --concurrency=1]) and returns it.
    String writeFake(String name, String body) {
      final fake = File('${inputs.path}/$name.dart')..writeAsStringSync(body);
      return fake.path;
    }

    String nextId(String name) {
      final id = 't${pid}_${DateTime.now().microsecondsSinceEpoch}_$name';
      runIds.add(id);
      return id;
    }

    /// True when a Flutter tool can run here (real SDK required).
    bool flutterRunnable() {
      if (!Platform.isWindows) return resolvesOnPath('flutter');
      try {
        resolveFlutterCommand(const ['flutter', '--version']);
        return true;
      } on ArgumentError {
        return false;
      }
    }

    test('canary: complacent test survives the mutant (FAIL)', () async {
      final pair = writePair(
        'complacent',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('complacent', () {
    expect(isAboveZero, isNotNull);
  });
}
''',
      );
      final verdict = await MutationRunner().run(
        sourcePath: pair[0],
        testPath: pair[1],
        runId: nextId('compl'),
      );
      expect(verdict.passed, isFalse);
      expect(verdict.results, hasLength(1));
      expect(verdict.results.single.status, MutantStatus.survived);
      expect(verdict.results.single.exitCode, 0);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('honest test kills the mutant (PASS)', () async {
      final pair = writePair(
        'honest',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''',
      );
      final verdict = await MutationRunner().run(
        sourcePath: pair[0],
        testPath: pair[1],
        runId: nextId('honest'),
      );
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
        sourcePath: pair[0],
        testPath: pair[1],
        runId: nextId('clean'),
      );
      expect(verdict.passed, isTrue);
      expect(verdict.results, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('breaker kills a hanging mutant run (timeout FAIL)', () async {
      final pair = writePair(
        'hang',
        'bool flag = true;\nbool getFlag() => flag;\n',
        '''
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
''',
      );
      final verdict = await MutationRunner().run(
        sourcePath: pair[0],
        testPath: pair[1],
        runId: nextId('hang'),
      );
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
          sourcePath: pair[0],
          testPath: pair[1],
          runId: nextId('red'),
        ),
        throwsStateError,
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('rejects a test that does not relatively import the source', () async {
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
          runId: nextId('orphan'),
        ),
        throwsArgumentError,
      );
    });

    test('pair: package: import without enclosing pubspec rejects', () async {
      final lib = Directory('${inputs.path}/nopkg/lib')
        ..createSync(recursive: true);
      final source = File('${lib.path}/target.dart')
        ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
      final testFile = File('${inputs.path}/nopkg/nopkg_test.dart')
        ..writeAsStringSync('''
import 'package:test/test.dart';
import 'package:nopkg_app/target.dart';
void main() {
  test('nopkg', () {
    expect(1, 1);
  });
}
''');
      await expectLater(
        MutationRunner().run(
          sourcePath: source.path,
          testPath: testFile.path,
          runId: nextId('nopkg'),
        ),
        throwsArgumentError,
      );
    });

    test('shadow: honest package pair kills the mutant', () async {
      final pkg = writePackage(
        'shadowhonest',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import 'package:shadowhonest_app/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''',
      );
      final fake = writeFake('shadow_honest', '''
import 'dart:io';
void main(List<String> args) {
  if (args.isEmpty || !args.first.endsWith('target_test.dart')) exit(3);
  if (File('lib/target.dart').readAsStringSync() !=
      'bool isAboveZero(int n) => n > 0;\\n') {
    exit(1);
  }
}
''');
      final id = nextId('shadowhonest');
      final verdict = await MutationRunner(
        testCommand: ({required bool usesFlutterTest}) => [
          Platform.resolvedExecutable,
          fake,
        ],
      ).run(sourcePath: pkg[1], testPath: pkg[2], runId: id);
      expect(verdict.passed, isTrue);
      expect(verdict.results.single.status, MutantStatus.killed);
      // The package tree is untouched and the shadow is removed.
      expect(
        File(pkg[1]).readAsStringSync(),
        'bool isAboveZero(int n) => n > 0;\n',
      );
      final rootEntries =
          Directory(pkg[0])
              .listSync()
              .map((e) => e.path.replaceAll(r'\', '/').split('/').last)
              .toList()
            ..sort();
      expect(rootEntries, ['lib', 'pubspec.yaml', 'test']);
      expect(Directory(shadowDir(id)).existsSync(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('shadow: complacent package pair survives', () async {
      final pkg = writePackage(
        'shadowcompl',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import 'package:shadowcompl_app/target.dart';
void main() {
  test('complacent', () {
    expect(isAboveZero, isNotNull);
  });
}
''',
      );
      // White-box on MutationRunner.canarySnippet: anything but the
      // canary exits 0 (see the canary-token test below).
      final fake = writeFake('shadow_compl', '''
import 'dart:io';
void main(List<String> args) {
  if (args.isEmpty || !args.first.endsWith('target_test.dart')) exit(3);
  if (File('lib/target.dart').readAsStringSync().contains('MUTATION_CANARY')) {
    exit(1);
  }
}
''');
      final verdict = await MutationRunner(
        testCommand: ({required bool usesFlutterTest}) => [
          Platform.resolvedExecutable,
          fake,
        ],
      ).run(sourcePath: pkg[1], testPath: pkg[2], runId: nextId('shadowcompl'));
      expect(verdict.passed, isFalse);
      expect(verdict.results.single.status, MutantStatus.survived);
      expect(verdict.results.single.exitCode, 0);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('shadow: real dart test run kills the mutant end to end', () async {
      final root = Directory('${inputs.path}/shadowreal')
        ..createSync(recursive: true);
      File('${root.path}/pubspec.yaml').writeAsStringSync(
        'name: shadowreal_app\nenvironment:\n  sdk: ^3.13.0\n'
        'dev_dependencies:\n  test: ^1.24.0\n',
      );
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      final testDir = Directory('${root.path}/test')
        ..createSync(recursive: true);
      final source = File('${lib.path}/target.dart')
        ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
      final testFile = File('${testDir.path}/target_test.dart')
        ..writeAsStringSync('''
import 'package:test/test.dart';
import 'package:shadowreal_app/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''');
      // Generous per-invocation breaker: nested `dart test` under
      // full-suite parallel load can exceed the 8s default.
      final verdict = await MutationRunner(timeout: const Duration(seconds: 60))
          .run(
            sourcePath: source.path,
            testPath: testFile.path,
            runId: nextId('shadowreal'),
          );
      expect(verdict.passed, isTrue);
      expect(verdict.results.single.status, MutantStatus.killed);
    }, timeout: const Timeout(Duration(seconds: 300)));

    test(
      'shadow: real flutter test run kills the mutant end to end',
      skip: flutterRunnable() ? false : 'Flutter SDK required',
      () async {
        final root = Directory('${inputs.path}/shadowflut')
          ..createSync(recursive: true);
        File('${root.path}/pubspec.yaml').writeAsStringSync(
          'name: shadowflut_app\nenvironment:\n  sdk: ^3.13.0\n'
          'dependencies:\n  flutter:\n    sdk: flutter\n'
          'dev_dependencies:\n  flutter_test:\n    sdk: flutter\n',
        );
        final lib = Directory('${root.path}/lib')..createSync(recursive: true);
        final testDir = Directory('${root.path}/test')
          ..createSync(recursive: true);
        final source = File('${lib.path}/target.dart')
          ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
        final testFile = File('${testDir.path}/target_test.dart')
          ..writeAsStringSync('''
import 'package:flutter_test/flutter_test.dart';
import 'package:shadowflut_app/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''');
        final verdict =
            await MutationRunner(
              timeout: const Duration(seconds: 120),
              pubGetTimeout: const Duration(seconds: 300),
            ).run(
              sourcePath: source.path,
              testPath: testFile.path,
              runId: nextId('shadowflut'),
            );
        expect(verdict.passed, isTrue);
        expect(verdict.results.single.status, MutantStatus.killed);
      },
      timeout: const Timeout(Duration(seconds: 600)),
    );

    test('shadow: passing canary aborts fail-closed', () async {
      final pkg = writePackage(
        'shadowcanary',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import 'package:shadowcanary_app/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
  });
}
''',
      );
      final fake = writeFake(
        'shadow_canary',
        'void main(List<String> args) {}\n',
      );
      final id = nextId('shadowcanary');
      await expectLater(
        MutationRunner(
          testCommand: ({required bool usesFlutterTest}) => [
            Platform.resolvedExecutable,
            fake,
          ],
        ).run(sourcePath: pkg[1], testPath: pkg[2], runId: id),
        throwsStateError,
      );
      // A staging failure keeps the shadow for inspection.
      final shadow = Directory(shadowDir(id));
      expect(shadow.existsSync(), isTrue);
      shadow.deleteSync(recursive: true); // Asserted; leave no litter.
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('shadow: failing pub get aborts with the shadow kept', () async {
      final pkg = writePackage(
        'shadowpubfail',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import 'package:shadowpubfail_app/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
  });
}
''',
      );
      final id = nextId('shadowpubfail');
      await expectLater(
        MutationRunner(
          pubGetCommand: ({required bool usesFlutter}) => [
            Platform.resolvedExecutable,
            'definitely_missing_pubget_probe.dart',
          ],
        ).run(sourcePath: pkg[1], testPath: pkg[2], runId: id),
        throwsStateError,
      );
      final shadow = Directory(shadowDir(id));
      expect(shadow.existsSync(), isTrue);
      shadow.deleteSync(recursive: true); // Asserted; leave no litter.
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('shadow: pubGetCommand override threads usesFlutter', () async {
      final pkg = writePackage(
        'shadowpubseen',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import 'package:shadowpubseen_app/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''',
      );
      final fake = writeFake('shadow_pubseen', '''
import 'dart:io';
void main(List<String> args) {
  if (File('lib/target.dart').readAsStringSync() !=
      'bool isAboveZero(int n) => n > 0;\\n') {
    exit(1);
  }
}
''');
      final seen = <bool>[];
      final verdict =
          await MutationRunner(
            pubGetCommand: ({required bool usesFlutter}) {
              seen.add(usesFlutter);
              return [Platform.resolvedExecutable, '--version'];
            },
            testCommand: ({required bool usesFlutterTest}) => [
              Platform.resolvedExecutable,
              fake,
            ],
          ).run(
            sourcePath: pkg[1],
            testPath: pkg[2],
            runId: nextId('shadowpubseen'),
          );
      expect(seen, [false]);
      expect(verdict.passed, isTrue);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('shadow: canary snippet breaks parsing', () {
      expect(MutationRunner.canarySnippet, contains('MUTATION_CANARY'));
      final result = parseString(
        content: 'bool ok() => true;\n${MutationRunner.canarySnippet}',
        throwIfDiagnostics: false,
      );
      expect(result.errors, isNotEmpty);
    });

    test('shadow: test outside the package rejects', () async {
      final root = Directory('${inputs.path}/splitpkg')
        ..createSync(recursive: true);
      File('${root.path}/pubspec.yaml')
          .writeAsStringSync('name: splitpkg\nenvironment:\n  sdk: ^3.13.0\n');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      final source = File('${lib.path}/target.dart')
        ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
      final testFile = File('${inputs.path}/split_test.dart')
        ..writeAsStringSync('''
import 'package:test/test.dart';
import 'splitpkg/lib/target.dart';
void main() {
  test('split', () {
    expect(1, 1);
  });
}
''');
      await expectLater(
        MutationRunner().run(
          sourcePath: source.path,
          testPath: testFile.path,
          runId: nextId('split'),
        ),
        throwsArgumentError,
      );
    });

    test('a package: import for another file still rejects', () async {
      final root = Directory('${inputs.path}/pkgother')
        ..createSync(recursive: true);
      File('${root.path}/pubspec.yaml')
          .writeAsStringSync('name: pkgother\nenvironment:\n  sdk: ^3.13.0\n');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      final source = File('${lib.path}/target.dart')
        ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
      final testFile = File('${root.path}/other_test.dart')
        ..writeAsStringSync('''
import 'package:test/test.dart';
import 'package:pkgother/other.dart';
void main() {
  test('other', () {
    expect(1, 1);
  });
}
''');
      await expectLater(
        MutationRunner().run(
          sourcePath: source.path,
          testPath: testFile.path,
          runId: nextId('pkgother'),
        ),
        throwsArgumentError,
      );
    });

    test('sweepStaleShadows removes only stale shadows', () {
      // White-box on the runner's incomplete-run marker filename.
      sweepStaleShadows(); // Clear the global temp: exact counts below.
      final fresh = Directory(shadowDir(nextId('sweepfresh')))
        ..createSync(recursive: true);
      File('${fresh.path}/.fg-mutprobe-incomplete')
          .writeAsStringSync('fresh\n');
      final stale = Directory(shadowDir(nextId('sweepstale')))
        ..createSync(recursive: true);
      File('${stale.path}/.fg-mutprobe-incomplete')
        ..writeAsStringSync('stale\n')
        ..setLastModifiedSync(DateTime(2020));
      final civilian = Directory('${inputs.path}/civilian')..createSync();
      expect(sweepStaleShadows(), 1);
      expect(fresh.existsSync(), isTrue);
      expect(stale.existsSync(), isFalse);
      expect(civilian.existsSync(), isTrue);
      // Marker-less copies that died mid-flight sweep once stale: with
      // a zero backdate even a fresh copy counts. Lower bound, not
      // exact: a sibling failing just before would leave its fresh
      // shadow here too.
      final bare = Directory(shadowDir(nextId('sweepbare')))
        ..createSync(recursive: true);
      expect(
        sweepStaleShadows(olderThan: Duration.zero),
        greaterThanOrEqualTo(2),
      );
      expect(bare.existsSync(), isFalse);
      expect(fresh.existsSync(), isFalse);
    });

    test('shadowDirPrefix spelling is pinned', () {
      expect(MutationRunner.shadowDirPrefix, 'fg_mut_shadow_');
    });

    test('rejects missing files, identical paths, and bad timeouts', () async {
      final runner = MutationRunner();
      await expectLater(
        runner.run(sourcePath: 'nope.dart', testPath: 'nope_test.dart'),
        throwsArgumentError,
      );
      await expectLater(
        MutationRunner(timeout: Duration.zero)
            .run(sourcePath: 'a.dart', testPath: 'b.dart'),
        throwsArgumentError,
      );
      await expectLater(
        MutationRunner(pubGetTimeout: Duration.zero)
            .run(sourcePath: 'a.dart', testPath: 'b.dart'),
        throwsArgumentError,
      );
      final same = File('${inputs.path}/same.dart')
        ..writeAsStringSync('int x = 1;\n');
      await expectLater(
        runner.run(sourcePath: same.path, testPath: same.path),
        throwsArgumentError,
      );
    });
    test('defaultTestCommand switches on flutter_test detection', () {
      expect(MutationRunner.defaultTestCommand(usesFlutterTest: true), [
        'flutter',
        'test',
      ]);
      final dart = MutationRunner.defaultTestCommand(usesFlutterTest: false);
      expect(dart, hasLength(2));
      expect(dart.last, 'test');
    });

    test('defaultPubGetCommand switches on flutter', () {
      expect(MutationRunner.defaultPubGetCommand(usesFlutter: true), [
        'flutter',
        'pub',
        'get',
      ]);
      final dart = MutationRunner.defaultPubGetCommand(usesFlutter: false);
      expect(dart, hasLength(3));
      expect(dart.sublist(1), ['pub', 'get']);
    });

    test('usesFlutterTest is AST-sited (strings/comments never match)', () {
      expect(
        usesFlutterTest("import 'package:flutter_test/flutter_test.dart';\n"),
        isTrue,
      );
      expect(usesFlutterTest("import 'package:test/test.dart';\n"), isFalse);
      expect(
        usesFlutterTest(
          "// import 'package:flutter_test/x.dart'\nvoid main() {}\n",
        ),
        isFalse,
      );
      expect(
        usesFlutterTest("const s = 'package:flutter_test/x.dart';\n"),
        isFalse,
      );
    });

    test(
      'flutter_test suites resolve the flutter command (override seam)',
      () async {
        final pair = writePair(
          'fluttercmd',
          'bool isAboveZero(int n) => n > 0;\n',
          '''
import 'package:flutter_test/flutter_test.dart';
import '../lib/target.dart';
void main() {
  testWidgets('honest', (tester) async {
    expect(isAboveZero(1), isTrue);
  });
}
''',
        );
        final seen = <bool>[];
        final fake = File('${inputs.path}/fake_test.dart')
          ..writeAsStringSync('void main(List<String> args) {}\n');
        final runner = MutationRunner(
          testCommand: ({required bool usesFlutterTest}) {
            seen.add(usesFlutterTest);
            return [Platform.resolvedExecutable, fake.path];
          },
        );
        final verdict = await runner.run(
          sourcePath: pair[0],
          testPath: pair[1],
          runId: nextId('fluttercmd'),
        );
        expect(seen, isNotEmpty);
        expect(seen, everyElement(isTrue));
        expect(verdict.results, hasLength(1));
        expect(verdict.results.single.status, MutantStatus.survived);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test('empty resolved command fails fast', () async {
      final pair = writePair(
        'emptycmd',
        'bool isAboveZero(int n) => n > 0;\n',
        '''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('x', () {
    expect(isAboveZero(1), isTrue);
  });
}
''',
      );
      await expectLater(
        MutationRunner(testCommand: ({required bool usesFlutterTest}) => [])
            .run(
              sourcePath: pair[0],
              testPath: pair[1],
              runId: nextId('emptycmd'),
            ),
        throwsStateError,
      );
    });
  });
}

/// Stages a fake Flutter SDK under [parent]/[name] (a `bin/flutter.bat`
/// launcher plus the three layout pieces, minus [without]) and returns
/// its root.
String stageFakeSdk(String parent, String name, {String? without}) {
  final root = Directory('$parent/$name')..createSync(recursive: true);
  for (final file in [
    'bin/flutter.bat',
    'bin/cache/dart-sdk/bin/dart.exe',
    'bin/cache/flutter_tools.snapshot',
    'packages/flutter_tools/.dart_tool/package_config.json',
  ]) {
    if (file == without) continue;
    File('${root.path}/$file')
      ..createSync(recursive: true)
      ..writeAsStringSync('x\n');
  }
  return root.path;
}

/// [path] with native separators (fake roots mix `/` in).
String native(String path) => path.replaceAll('/', Platform.pathSeparator);
