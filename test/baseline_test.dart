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
        writeBaseline(path, findings);
        final first = File(path).readAsStringSync();
        final loaded = loadBaseline(path);
        expect(loaded.counts, baselineCounts(findings));
        writeBaseline(path, findings);
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
          file: {'FG-BLOC-001': 1},
        }),
      );
      expect(reported.map((f) => f.line), [9, 1, 2]);
    });

    test('applyBaseline reports everything on empty baselines', () {
      final findings = [_finding('a.dart', 'R', 1)];
      expect(applyBaseline(findings, const FindingBaseline({})), findings);
    });

    test('baseline keys are absolute and spelling-stable', () {
      // Resolution, not spelling, decides the key: a walked-relative
      // path keys identically to its absolute form, so baselines stay
      // stable however the target was spelled. Cross-CWD convergence
      // inherits File.absolute (SDK) and is not mutated in-process:
      // Directory.current is process-global and would race parallel
      // suites.
      final root = Directory.systemTemp.createTempSync('baseline_test.');
      try {
        Directory('${root.path}/sub').createSync();
        final fromWalk = absoluteNormalized('${root.path}/sub/a.dart');
        expect(File(fromWalk).isAbsolute, isTrue);
        expect(fromWalk.contains(r'\'), isFalse);
        final relative = absoluteNormalized('sub/a.dart');
        final absolute = absoluteNormalized(
          '${Directory.current.path}/sub/a.dart',
        );
        expect(relative, absolute);
        final counts = baselineCounts([
          _finding('${root.path}/sub/a.dart', 'R', 1),
        ]);
        expect(counts.keys.single, fromWalk);
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
