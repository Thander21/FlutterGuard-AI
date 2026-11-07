import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:flutterguard_ai/flutterguard_ai.dart' as cli;

void main() {
  group('check cli', () {
    test('returns 2 on missing, doubled, or unknown arguments', () async {
      expect(await cli.check([]), 2);
      expect(await cli.check(['a.dart', 'b.dart']), 2);
      expect(await cli.check(['--bogus', 'benchmark/vectors']), 2);
      expect(await cli.check(['does/not/exist']), 2);
    });

    test('prints usage and returns 0 on --help', () async {
      expect(await cli.check(['--help']), isZero);
      expect(await cli.check(['-h']), isZero);
    });

    test('returns 0 when clean, 1 on violations', () async {
      expect(
        await cli.check(['benchmark/vectors/TC-01_bloc.good.dart']),
        isZero,
      );
      expect(await cli.check(['benchmark/vectors/TC-01_bloc.bad.dart']), 1);
      expect(await cli.check(['benchmark/vectors']), 1);
    });

    test(
      'returns 0 on warnings-only targets (advisories never block)',
      () async {
        expect(
          await cli.check(['benchmark/vectors/TC-13_met.bad.dart']),
          isZero,
          reason: 'FG-MET-007 is advisory until SYS-CAL-001 calibrates it',
        );
      },
    );

    test('accepts --json without changing exit codes', () async {
      expect(
        await cli.check(['--json', 'benchmark/vectors/TC-01_bloc.good.dart']),
        isZero,
      );
      expect(
        await cli.check(['benchmark/vectors/TC-01_bloc.bad.dart', '--json']),
        1,
      );
    });

    test(
      'skips generated files unless --include-generated is passed',
      () async {
        final root = Directory.systemTemp.createTempSync('check_cli_test.');
        try {
          File('${root.path}/store.g.dart').writeAsStringSync(
            File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
          );
          expect(await cli.check([root.path]), isZero);
          expect(await cli.check(['--include-generated', root.path]), 1);
        } finally {
          root.deleteSync(recursive: true);
        }
      },
    );

    test('--update-baseline writes counts and exits 0 (R2-2)', () async {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        File('${root.path}/bloc.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
        );
        final baseline = '${root.path}/baseline.json';
        expect(
          await cli.check([
            root.path,
            '--baseline',
            baseline,
            '--update-baseline',
          ]),
          isZero,
        );
        expect(File(baseline).existsSync(), isTrue);
        final loaded = cli.loadBaseline(baseline);
        expect(loaded.counts.values.single['FG-BLOC-001'], 1);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test(
      'baseline suppresses ratcheted findings, reports excess (R2-2)',
      () async {
        final root = Directory.systemTemp.createTempSync('check_cli_test.');
        try {
          final bad = File('benchmark/vectors/TC-01_bloc.bad.dart')
              .readAsStringSync();
          File('${root.path}/bloc.dart').writeAsStringSync(bad);
          final baseline = '${root.path}/baseline.json';
          expect(
            await cli.check([
              root.path,
              '--baseline',
              baseline,
              '--update-baseline',
            ]),
            isZero,
          );
          expect(await cli.check([root.path, '--baseline', baseline]), isZero);
          File('${root.path}/bloc2.dart').writeAsStringSync(bad);
          expect(await cli.check([root.path, '--baseline', baseline]), 1);
        } finally {
          root.deleteSync(recursive: true);
        }
      },
    );

    test(
      '--update-baseline writes project-relative keys (flutterguardai3 K1)',
      () async {
        final root = Directory.systemTemp.createTempSync('check_cli_test.');
        final out = Directory.systemTemp.createTempSync('check_cli_test.');
        try {
          _projectFixture(root);
          final baseline = '${out.path}/baseline.json';
          expect(
            await cli.check([
              '${root.path}/lib',
              '--baseline',
              baseline,
              '--update-baseline',
            ]),
            isZero,
          );
          final keys = (jsonDecode(File(baseline).readAsStringSync()) as Map)
              .keys
              .cast<String>();
          expect(keys, ['lib/src/bloc.dart']);
          for (final key in keys) {
            expect(key, isNot(matches(RegExp(r'^([A-Za-z]:|/)'))));
            expect(key.contains(r'\'), isFalse);
          }
        } finally {
          root.deleteSync(recursive: true);
          out.deleteSync(recursive: true);
        }
      },
    );

    test(
      'a baseline from folder A applies to a copy in folder B (K2)',
      () async {
        final a = Directory.systemTemp.createTempSync('check_cli_test.');
        final b = Directory.systemTemp.createTempSync('check_cli_test.');
        final out = Directory.systemTemp.createTempSync('check_cli_test.');
        try {
          _projectFixture(a);
          _projectFixture(b);
          final baseline = '${out.path}/baseline.json';
          expect(
            await cli.check([
              a.path,
              '--baseline',
              baseline,
              '--update-baseline',
            ]),
            isZero,
          );
          expect(await cli.check([b.path]), 1, reason: 'B has violations');
          expect(await cli.check([b.path, '--baseline', baseline]), isZero);
        } finally {
          a.deleteSync(recursive: true);
          b.deleteSync(recursive: true);
          out.deleteSync(recursive: true);
        }
      },
    );

    test('legacy absolute-keyed baselines are still honored (K3)', () async {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      final out = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        _projectFixture(root);
        final file = cli.absoluteNormalized('${root.path}/lib/src/bloc.dart');
        final baseline = '${out.path}/baseline.json';
        File(baseline).writeAsStringSync(
          jsonEncode({
            file: {'FG-BLOC-001': 1},
          }),
        );
        expect(await cli.check([root.path, '--baseline', baseline]), isZero);
        File(baseline).writeAsStringSync(
          jsonEncode({
            '/elsewhere/lib/src/bloc.dart': {'FG-BLOC-001': 1},
          }),
        );
        expect(
          await cli.check([root.path, '--baseline', baseline]),
          1,
          reason: 'absolute keys from another location do not match',
        );
      } finally {
        root.deleteSync(recursive: true);
        out.deleteSync(recursive: true);
      }
    });

    test('--diff checks only changed files (R2-2)', () async {
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
          await cli.check([root.path, '--diff', '--diff-base', 'main']),
          isZero,
          reason: 'committed violations are out of the diff scope',
        );
        File('${root.path}/clean.dart').writeAsStringSync(bad);
        expect(
          await cli.check([root.path, '--diff', '--diff-base', 'main']),
          1,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('--diff-base implies --diff (R2-2)', () async {
      final root = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        _gitInit(root);
        File('${root.path}/bad.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
        );
        _git(root, ['add', '-A']);
        _git(root, ['commit', '-m', 'base']);
        expect(
          await cli.check([root.path, '--diff-base', 'main']),
          isZero,
          reason: 'whole-tree would be 1; implied diff scope is clean',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('--diff fails closed outside git and on bad refs (R2-2)', () async {
      final plain = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        expect(await cli.check([plain.path, '--diff']), 2);
      } finally {
        plain.deleteSync(recursive: true);
      }
      final repo = Directory.systemTemp.createTempSync('check_cli_test.');
      try {
        _gitInit(repo);
        File('${repo.path}/a.dart').writeAsStringSync('void main() {}\n');
        _git(repo, ['add', '-A']);
        _git(repo, ['commit', '-m', 'base']);
        expect(await cli.check([repo.path, '--diff-base', 'nope/missing']), 2);
      } finally {
        repo.deleteSync(recursive: true);
      }
    });

    test(
      '--update-baseline needs --baseline and rejects --diff (R2-2)',
      () async {
        final root = Directory.systemTemp.createTempSync('check_cli_test.');
        try {
          expect(await cli.check([root.path, '--update-baseline']), 2);
          expect(
            await cli.check([
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
      },
    );

    test('--jobs fans out without changing exits', () async {
      expect(
        await cli.check([
          '--jobs',
          '4',
          'benchmark/vectors/TC-01_bloc.good.dart',
        ]),
        isZero,
      );
      expect(
        await cli.check([
          '--jobs',
          '4',
          'benchmark/vectors/TC-01_bloc.bad.dart',
        ]),
        1,
      );
      expect(
        await cli.check([
          '--jobs',
          '1',
          'benchmark/vectors/TC-01_bloc.bad.dart',
        ]),
        1,
      );
    });

    test('--jobs rejects non-positive integers', () async {
      expect(await cli.check(['--jobs', '0', 'benchmark/vectors']), 2);
      expect(await cli.check(['--jobs', '-2', 'benchmark/vectors']), 2);
      expect(await cli.check(['--jobs', 'nope', 'benchmark/vectors']), 2);
    });

    test('--jobs output is byte-identical to sequential (subprocess)', () {
      String run(List<String> extra) {
        final result = Process.runSync('dart', [
          'run',
          'bin/flutterguard.dart',
          'check',
          ...extra,
          'benchmark/vectors/TC-01_bloc.bad.dart',
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 1);
        return result.stdout as String;
      }

      expect(run(['--jobs', '4']), run([]));
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

/// A minimal project: `pubspec.yaml` at [root] and one FG-BLOC-001
/// violation under `lib/src/`.
void _projectFixture(Directory root) {
  File('${root.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
  File('${root.path}/lib/src/bloc.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
    );
}
