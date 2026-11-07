// R2-2 adoption scope: baseline load/write/ratchet + diff file-set.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

CheckFinding _finding(
  String file,
  String rule,
  int line, {
  String message = 'message',
  String severity = 'error',
}) => CheckFinding(
  ruleId: rule,
  spec: 'specs/TS-00.md',
  file: file,
  line: line,
  message: message,
  severity: severity,
);

void _git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  expect(
    result.exitCode,
    isZero,
    reason: 'git ${args.join(' ')}: ${result.stderr}',
  );
}

Directory _gitRepo() {
  final root = Directory.systemTemp.createTempSync('baseline_test.');
  _git(root, ['init', '-b', 'main']);
  _git(root, ['config', 'user.email', 'baseline@test']);
  _git(root, ['config', 'user.name', 'baseline']);
  _git(root, ['config', 'commit.gpgsign', 'false']);
  return root;
}

void main() {
  group('R2-2 baseline', () {
    test('round-trips a baseline file with stable bytes', () {
      final root = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        final findings = [
          _finding('${root.path}/a.dart', 'FG-BLOC-001', 3),
          _finding('${root.path}/a.dart', 'FG-BLOC-001', 9),
          _finding('${root.path}/b.dart', 'FG-MET-007', 1, severity: 'warning'),
        ];
        final path = '${root.path}/baseline.json';
        writeBaseline(path, findings, root: root.path);
        final first = File(path).readAsStringSync();
        final loaded = loadBaseline(path);
        expect(loaded.counts, baselineCounts(findings, root: root.path));
        writeBaseline(path, findings, root: root.path);
        expect(File(path).readAsStringSync(), first);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('loadBaseline rejects missing, malformed, and mistyped files', () {
      final root = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        expect(
          () => loadBaseline('${root.path}/nope.json'),
          throwsArgumentError,
        );
        final bad = '${root.path}/bad.json';
        File(bad).writeAsStringSync('{oops');
        expect(() => loadBaseline(bad), throwsArgumentError);
        File(bad).writeAsStringSync('[]');
        expect(() => loadBaseline(bad), throwsArgumentError);
        File(bad).writeAsStringSync(
          jsonEncode({
            'f.dart': ['x'],
          }),
        );
        expect(() => loadBaseline(bad), throwsArgumentError);
        File(bad).writeAsStringSync(
          jsonEncode({
            'f.dart': {'R': 'x'},
          }),
        );
        expect(() => loadBaseline(bad), throwsArgumentError);
        File(bad).writeAsStringSync(
          jsonEncode({
            'f.dart': {'R': -1},
          }),
        );
        expect(() => loadBaseline(bad), throwsArgumentError);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('applyBaseline suppresses at-or-under counts, reports excess', () {
      final file = absoluteNormalized('lib/a.dart');
      final findings = [
        _finding(file, 'FG-BLOC-001', 3),
        _finding(file, 'FG-BLOC-001', 9),
        _finding(file, 'FG-MET-007', 1),
        _finding(absoluteNormalized('lib/b.dart'), 'FG-BLOC-001', 2),
      ];
      final reported = applyBaseline(
        findings,
        FindingBaseline({
          'lib/a.dart': {'FG-BLOC-001': 1},
        }),
        root: Directory.current.path,
      );
      expect(reported.map((f) => f.line), [9, 1, 2]);
    });

    test('applyBaseline reports everything on empty baselines', () {
      final findings = [_finding('a.dart', 'R', 1)];
      expect(
        applyBaseline(
          findings,
          const FindingBaseline({}),
          root: Directory.current.path,
        ),
        findings,
      );
    });

    test('baseline keys are root-relative and spelling-stable', () {
      // Resolution, not spelling, decides the key: a walked-relative
      // path and its absolute form key identically, relative to the
      // project root, with forward slashes (flutterguardai3 K1).
      // Directory.current is read, never mutated (process-global).
      final cwd = Directory.current.path;
      final counts = baselineCounts([
        _finding('sub/a.dart', 'R', 1),
        _finding('$cwd/sub/a.dart', 'R', 2),
        _finding(
          '$cwd${Platform.pathSeparator}sub${Platform.pathSeparator}'
              'b.dart',
          'R',
          3,
        ),
      ], root: cwd);
      expect(counts, {
        'sub/a.dart': {'R': 2},
        'sub/b.dart': {'R': 1},
      });
      final root = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        final keys = baselineCounts([
          _finding('${root.path}/sub/a.dart', 'R', 1),
        ], root: root.path).keys;
        expect(keys, ['sub/a.dart']);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('baselineRoot is the nearest pubspec ancestor, else the target', () {
      final root = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        final plain = Directory('${root.path}/plain/lib')
          ..createSync(recursive: true);
        File('${plain.path}/a.dart').writeAsStringSync('void main() {}\n');
        final project = Directory('${root.path}/app/lib/src')
          ..createSync(recursive: true);
        File('${root.path}/app/pubspec.yaml').writeAsStringSync('name: a\n');
        File('${project.path}/a.dart').writeAsStringSync('void main() {}\n');
        final app = absoluteNormalized('${root.path}/app');
        expect(baselineRoot('${root.path}/app'), app);
        expect(baselineRoot(project.path), app);
        expect(baselineRoot('${project.path}/a.dart'), app);
        expect(baselineRoot(plain.path), absoluteNormalized(plain.path));
        expect(
          baselineRoot('${plain.path}/a.dart'),
          absoluteNormalized(plain.path),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('applyBaseline honors legacy absolute keys (flutterguardai3 K3)', () {
      final root = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        final file = '${root.path}/lib/a.dart';
        final findings = [
          _finding(file, 'R', 1),
          _finding(file, 'R', 2),
          _finding(file, 'R', 3),
        ];
        final legacy = FindingBaseline({
          absoluteNormalized(file): {'R': 2},
        });
        expect(
          applyBaseline(findings, legacy, root: root.path).map((f) => f.line),
          [3],
        );
        final mixed = FindingBaseline({
          'lib/a.dart': {'R': 1},
          absoluteNormalized(file): {'R': 1},
        });
        expect(
          applyBaseline(findings, mixed, root: root.path).map((f) => f.line),
          [3],
        );
        final elsewhere = FindingBaseline({
          '/elsewhere/lib/a.dart': {'R': 3},
        });
        expect(applyBaseline(findings, elsewhere, root: root.path), findings);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('resolveChangedFiles sees worktree edits and untracked files', () {
      final root = _gitRepo();
      try {
        File('${root.path}/bad.dart').writeAsStringSync('void main() {}\n');
        File('${root.path}/clean.dart').writeAsStringSync('void main() {}\n');
        _git(root, ['add', '-A']);
        _git(root, ['commit', '-m', 'base']);
        File('${root.path}/clean.dart')
            .writeAsStringSync('void main() {/* edit */}\n');
        File('${root.path}/new.dart').writeAsStringSync('void main() {}\n');
        final changed = resolveChangedFiles(root.path, 'main');
        expect(
          changed,
          contains(absoluteNormalized('${root.path}/clean.dart')),
        );
        expect(changed, contains(absoluteNormalized('${root.path}/new.dart')));
        expect(
          changed,
          isNot(contains(absoluteNormalized('${root.path}/bad.dart'))),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('resolveChangedFiles fails closed outside git and on bad refs', () {
      final plain = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        expect(
          () => resolveChangedFiles(plain.path, 'main'),
          throwsArgumentError,
        );
      } finally {
        plain.deleteSync(recursive: true);
      }
      final repo = _gitRepo();
      try {
        File('${repo.path}/a.dart').writeAsStringSync('void main() {}\n');
        _git(repo, ['add', '-A']);
        _git(repo, ['commit', '-m', 'base']);
        expect(
          () => resolveChangedFiles(repo.path, 'nope/missing'),
          throwsArgumentError,
        );
      } finally {
        repo.deleteSync(recursive: true);
      }
    });

    test('resolveChangedFiles accepts a file target', () {
      final repo = _gitRepo();
      try {
        final sub = Directory('${repo.path}/sub')..createSync();
        File('${sub.path}/a.dart').writeAsStringSync('void main() {}\n');
        _git(repo, ['add', '-A']);
        _git(repo, ['commit', '-m', 'base']);
        File('${sub.path}/a.dart')
            .writeAsStringSync('void main() {/* edit */}\n');
        final changed = resolveChangedFiles('${sub.path}/a.dart', 'main');
        expect(changed, contains(absoluteNormalized('${sub.path}/a.dart')));
      } finally {
        repo.deleteSync(recursive: true);
      }
    });
  });
}
