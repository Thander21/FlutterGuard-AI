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
  });
}
