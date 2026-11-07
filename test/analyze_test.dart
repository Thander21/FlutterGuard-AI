// Opt-in analyzer step: machine-output parsing plus real-SDK runs.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Stages a minimal package with [body] as `lib.dart`.
Directory _package(String body) {
  final root = Directory.systemTemp.createTempSync('analyze_test.');
  File('${root.path}/pubspec.yaml')
      .writeAsStringSync('name: pkg\nenvironment:\n  sdk: ^3.13.0\n');
  File('${root.path}/lib.dart').writeAsStringSync(body);
  return root;
}

void main() {
  group('parseAnalyzerOutput', () {
    test('parses machine lines into issues', () {
      final issues = parseAnalyzerOutput(
        "ERROR|COMPILE_TIME_ERROR|UNDEFINED_FUNCTION|pkg/lib/a.dart|2|12|4|The function 'nope' isn't defined.\r\n"
        'INFO|LINT|UNUSED_IMPORT|pkg/lib/b.dart|1|8|15|Unused import.\n',
      );
      expect(issues.map((i) => i.file), ['pkg/lib/a.dart', 'pkg/lib/b.dart']);
      expect(issues.map((i) => i.line), [2, 1]);
      expect(issues[0].message, contains("isn't defined"));
      expect(issues[1].message, contains('Unused import'));
    });

    test('joins piped messages and skips malformed lines', () {
      final issues = parseAnalyzerOutput(
        'garbage\n'
        'A|B|C\n'
        'INFO|X|Y|f.dart|NaN|1|1|m\n'
        'ERROR|T|C|f.dart|3|1|1|a|b|c\n',
      );
      expect(issues.map((i) => i.line), [3]);
      expect(issues.single.message, contains('a|b|c'));
    });

    test('unescapes Windows separators', () {
      final issues = parseAnalyzerOutput(
        'ERROR|T|C|C:\\\\x\\\\a.dart|1|1|1|m\n',
      );
      expect(issues.single.file, 'C:/x/a.dart');
    });

    test('empty output yields no issues', () {
      expect(parseAnalyzerOutput(''), isEmpty);
      expect(parseAnalyzerOutput('\n'), isEmpty);
    });
  });

  group('groupAnalyzerIssues', () {
    test('groups per file sorted with lines sorted', () {
      const issues = [
        AnalyzerIssue(file: 'b.dart', line: 9, message: 'm9'),
        AnalyzerIssue(file: 'a.dart', line: 5, message: 'm5'),
        AnalyzerIssue(file: 'a.dart', line: 2, message: 'm2'),
      ];
      final grouped = groupAnalyzerIssues(issues);
      expect(grouped.keys.toList(), ['a.dart', 'b.dart']);
      expect(grouped['a.dart'], 'L2: m2; L5: m5');
      expect(grouped['b.dart'], 'L9: m9');
    });
  });

  group('runAnalyzer', () {
    test('clean package passes', () {
      final root = _package('void main() {}\n');
      try {
        final result = runAnalyzer(root.path);
        expect(result.passed, isTrue);
        expect(result.issues, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('dirty package fails with parsed issues', () {
      final root = _package('void f() { nope(); }\n');
      try {
        final result = runAnalyzer(root.path);
        expect(result.passed, isFalse);
        expect(result.issues, isNotEmpty);
        expect(result.issues.first.line, 1);
        expect(result.issues.first.file, contains('lib.dart'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('unparseable file fails', () {
      final root = _package('void f( {\n');
      try {
        expect(runAnalyzer(root.path).passed, isFalse);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });

  group('check --analyze', () {
    test('clean target exits 0, dirty target exits 1', () async {
      final clean = _package('void main() {}\n');
      final dirty = _package('void f() { nope(); }\n');
      try {
        expect(await check(['--analyze', clean.path]), isZero);
        expect(await check(['--analyze', dirty.path]), 1);
      } finally {
        clean.deleteSync(recursive: true);
        dirty.deleteSync(recursive: true);
      }
    });

    test('requires exactly one target', () async {
      expect(await check(['--analyze']), 2);
    });

    test('dirty JSON carries analyzer errors (subprocess)', () {
      final dirty = _package('void f() { nope(); }\n');
      try {
        final result = Process.runSync('dart', [
          'run',
          'bin/flutterguard.dart',
          'check',
          '--analyze',
          '--json',
          dirty.path,
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1);
        final decoded =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        final errors = decoded['errors'] as List;
        expect(errors, isNotEmpty);
        expect(
          errors.every(
            (e) => (e as Map)['error'].toString().startsWith('analyzer:'),
          ),
          isTrue,
        );
      } finally {
        dirty.deleteSync(recursive: true);
      }
    });

    test('analyzes the whole target under --diff', () async {
      final root = Directory.systemTemp.createTempSync('analyze_test.');
      try {
        Process.runSync('git', [
          'init',
          '-b',
          'main',
        ], workingDirectory: root.path);
        Process.runSync('git', [
          'config',
          'user.email',
          'a@t',
        ], workingDirectory: root.path);
        Process.runSync('git', [
          'config',
          'user.name',
          'a',
        ], workingDirectory: root.path);
        Process.runSync('git', [
          'config',
          'commit.gpgsign',
          'false',
        ], workingDirectory: root.path);
        File('${root.path}/pubspec.yaml')
            .writeAsStringSync('name: pkg\nenvironment:\n  sdk: ^3.13.0\n');
        File('${root.path}/dirty.dart')
            .writeAsStringSync('void f() { nope(); }\n');
        Process.runSync('git', ['add', '-A'], workingDirectory: root.path);
        Process.runSync('git', [
          'commit',
          '-m',
          'base',
        ], workingDirectory: root.path);
        // Nothing changed: visitors see an empty diff, but the
        // analyzer still runs over the whole target and fails.
        expect(
          await check([
            '--analyze',
            '--diff',
            '--diff-base',
            'main',
            root.path,
          ]),
          1,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
