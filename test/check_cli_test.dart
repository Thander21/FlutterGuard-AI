import 'dart:io';

import 'package:test/test.dart';

import 'package:flutterguard_ai/flutterguard_ai.dart' as cli;

void main() {
  group('check cli', () {
    test('returns 2 on missing, doubled, or unknown arguments', () {
      expect(cli.check([]), 2);
      expect(cli.check(['a.dart', 'b.dart']), 2);
      expect(cli.check(['--bogus', 'benchmark/vectors']), 2);
      expect(cli.check(['does/not/exist']), 2);
    });

    test('prints usage and returns 0 on --help', () {
      expect(cli.check(['--help']), isZero);
      expect(cli.check(['-h']), isZero);
    });

    test('returns 0 when clean, 1 on violations', () {
      expect(cli.check(['benchmark/vectors/TC-01_bloc.good.dart']), isZero);
      expect(cli.check(['benchmark/vectors/TC-01_bloc.bad.dart']), 1);
      expect(cli.check(['benchmark/vectors']), 1);
    });

    test('returns 0 on warnings-only targets (advisories never block)', () {
      expect(
        cli.check(['benchmark/vectors/TC-13_met.bad.dart']),
        isZero,
        reason: 'FG-MET-007 is advisory until SYS-CAL-001 calibrates it',
      );
    });

    test('accepts --json without changing exit codes', () {
      expect(
        cli.check(['--json', 'benchmark/vectors/TC-01_bloc.good.dart']),
        isZero,
      );
      expect(cli.check(['benchmark/vectors/TC-01_bloc.bad.dart', '--json']), 1);
    });

    test('skips generated files unless --include-generated is passed', () {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        File('${root.path}/store.g.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
        );
        expect(cli.check([root.path]), isZero);
        expect(cli.check(['--include-generated', root.path]), 1);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('--update-baseline writes counts and exits 0 (R2-2)', () {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        File('${root.path}/bloc.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
        );
        final baseline = '${root.path}/baseline.json';
        expect(
          cli.check([root.path, '--baseline', baseline, '--update-baseline']),
          isZero,
        );
        expect(File(baseline).existsSync(), isTrue);
        final loaded = cli.loadBaseline(baseline);
        expect(loaded.counts.values.single['FG-BLOC-001'], 1);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('baseline suppresses ratcheted findings, reports excess (R2-2)', () {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        final bad = File('benchmark/vectors/TC-01_bloc.bad.dart')
            .readAsStringSync();
        File('${root.path}/bloc.dart').writeAsStringSync(bad);
        final baseline = '${root.path}/baseline.json';
        expect(
          cli.check([root.path, '--baseline', baseline, '--update-baseline']),
          isZero,
        );
        expect(cli.check([root.path, '--baseline', baseline]), isZero);
        File('${root.path}/bloc2.dart').writeAsStringSync(bad);
        expect(cli.check([root.path, '--baseline', baseline]), 1);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('--diff checks only changed files (R2-2)', () {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        _gitInit(root);
        final bad = File('benchmark/vectors/TC-01_bloc.bad.dart')
            .readAsStringSync();
        File('${root.path}/bad.dart').writeAsStringSync(bad);
        File('${root.path}/clean.dart').writeAsStringSync('void main() {}\n');
        _git(root, ['add', '-A']);
        _git(root, ['commit', '-m', 'base']);
        expect(
          cli.check([root.path, '--diff', '--diff-base', 'main']),
          isZero,
          reason: 'committed violations are out of the diff scope',
        );
        File('${root.path}/clean.dart').writeAsStringSync(bad);
        expect(cli.check([root.path, '--diff', '--diff-base', 'main']), 1);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('--diff-base implies --diff (R2-2)', () {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        _gitInit(root);
        File('${root.path}/bad.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
        );
        _git(root, ['add', '-A']);
        _git(root, ['commit', '-m', 'base']);
        expect(
          cli.check([root.path, '--diff-base', 'main']),
          isZero,
          reason: 'whole-tree would be 1; implied diff scope is clean',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('--diff fails closed outside git and on bad refs (R2-2)', () {
      final plain = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        expect(cli.check([plain.path, '--diff']), 2);
      } finally {
        plain.deleteSync(recursive: true);
      }
      final repo = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        _gitInit(repo);
        File('${repo.path}/a.dart').writeAsStringSync('void main() {}\n');
        _git(repo, ['add', '-A']);
        _git(repo, ['commit', '-m', 'base']);
        expect(cli.check([repo.path, '--diff-base', 'nope/missing']), 2);
      } finally {
        repo.deleteSync(recursive: true);
      }
    });

    test('--update-baseline needs --baseline and rejects --diff (R2-2)', () {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        expect(cli.check([root.path, '--update-baseline']), 2);
        expect(
          cli.check([
            root.path,
            '--baseline',
            'b.json',
            '--update-baseline',
            '--diff',
          ]),
          2,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}

void _git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  expect(
    result.exitCode,
    isZero,
    reason: 'git ${args.join(' ')}: ${result.stderr}',
  );
}

void _gitInit(Directory root) {
  _git(root, ['init', '-b', 'main']);
  _git(root, ['config', 'user.email', 'check@test']);
  _git(root, ['config', 'user.name', 'check']);
  _git(root, ['config', 'commit.gpgsign', 'false']);
}
