// Changed-tests selection: diff files mapped onto runnable tests.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void _git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  expect(
    result.exitCode,
    isZero,
    reason: 'git ${args.join(' ')}: ${result.stderr}',
  );
}

Directory _gitRepo() {
  final root = Directory.systemTemp.createTempSync('select_test.');
  _git(root, ['init', '-b', 'main']);
  _git(root, ['config', 'user.email', 'select@test']);
  _git(root, ['config', 'user.name', 'select']);
  _git(root, ['config', 'commit.gpgsign', 'false']);
  return root;
}

/// Stages a package with lib/covered.dart + mirror, lib/lonely.dart
/// without one, and a committed base.
void _stageBase(Directory root) {
  Directory('${root.path}/lib').createSync(recursive: true);
  Directory('${root.path}/test').createSync(recursive: true);
  File('${root.path}/lib/covered.dart').writeAsStringSync('void f() {}\n');
  File('${root.path}/test/covered_test.dart').writeAsStringSync('// test\n');
  File('${root.path}/lib/lonely.dart').writeAsStringSync('void g() {}\n');
  _git(root, ['add', '-A']);
  _git(root, ['commit', '-m', 'base']);
}

void main() {
  group('selectChangedTests', () {
    test('selects changed tests and mirrors of changed lib files', () {
      final root = _gitRepo();
      try {
        _stageBase(root);
        File('${root.path}/lib/covered.dart')
            .writeAsStringSync('void f() {/* edit */}\n');
        File('${root.path}/test/covered_test.dart')
            .writeAsStringSync('// test edit\n');
        File('${root.path}/lib/lonely.dart')
            .writeAsStringSync('void g() {/* edit */}\n');
        File('${root.path}/notes.md').writeAsStringSync('# notes\n');
        final selected = selectChangedTests(root.path, base: 'main');
        expect(selected, [
          absoluteNormalized('${root.path}/test/covered_test.dart'),
        ]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('empty diff selects nothing (full-suite shell fallback)', () {
      final root = _gitRepo();
      try {
        _stageBase(root);
        expect(selectChangedTests(root.path, base: 'main'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('deleted tests are not selected', () {
      final root = _gitRepo();
      try {
        _stageBase(root);
        File('${root.path}/test/covered_test.dart').deleteSync();
        expect(selectChangedTests(root.path, base: 'main'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('accepts a file target (repo-wide selection)', () {
      final root = _gitRepo();
      try {
        _stageBase(root);
        File('${root.path}/lib/covered.dart')
            .writeAsStringSync('void f() {/* edit */}\n');
        final selected = selectChangedTests(
          '${root.path}/lib/covered.dart',
          base: 'main',
        );
        expect(selected, [
          absoluteNormalized('${root.path}/test/covered_test.dart'),
        ]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('fails closed outside git and on bad refs', () {
      final plain = Directory.systemTemp.createTempSync('select_test.');
      try {
        expect(
          () => selectChangedTests(plain.path, base: 'main'),
          throwsArgumentError,
        );
      } finally {
        plain.deleteSync(recursive: true);
      }
      final repo = _gitRepo();
      try {
        _stageBase(repo);
        expect(
          () => selectChangedTests(repo.path, base: 'nope/missing'),
          throwsArgumentError,
        );
      } finally {
        repo.deleteSync(recursive: true);
      }
    });
  });

  group('select-tests CLI', () {
    test('prints one test per line and exits 0', () {
      final root = _gitRepo();
      try {
        _stageBase(root);
        File('${root.path}/lib/covered.dart')
            .writeAsStringSync('void f() {/* edit */}\n');
        final out = StringBuffer();
        expect(
          selectTests([root.path, '--diff-base', 'main'], out: out),
          isZero,
        );
        expect(out.toString().trim().split('\n'), [
          absoluteNormalized('${root.path}/test/covered_test.dart'),
        ]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('empty selection prints nothing and exits 0', () {
      final root = _gitRepo();
      try {
        _stageBase(root);
        final out = StringBuffer();
        expect(
          selectTests([root.path, '--diff-base', 'main'], out: out),
          isZero,
        );
        expect(out.toString(), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('bin dispatches select-tests (subprocess smoke)', () {
      final result = Process.runSync('dart', [
        'run',
        'bin/flutterguard.dart',
        'select-tests',
        '--help',
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, isZero);
    });

    test('bad arity, bad base, and non-git exit 2; --help exits 0', () {
      expect(selectTests([]), 2);
      expect(selectTests(['a', 'b']), 2);
      expect(selectTests(['--help']), isZero);
      final plain = Directory.systemTemp.createTempSync('select_test.');
      try {
        expect(selectTests([plain.path]), 2);
      } finally {
        plain.deleteSync(recursive: true);
      }
      final repo = _gitRepo();
      try {
        _stageBase(repo);
        expect(selectTests([repo.path, '--diff-base', 'nope/missing']), 2);
      } finally {
        repo.deleteSync(recursive: true);
      }
    });
  });
}
