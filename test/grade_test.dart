import 'dart:io';

import 'package:test/test.dart';

import '../bin/flutterguard.dart' as cli;

void main() {
  group('grade', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('grade_test.');
      Directory('${root.path}/specs').createSync();
      Directory('${root.path}/benchmark/vectors').createSync(recursive: true);
      for (final name in [
        'specs/TS-01-bloc-emit-guard.md',
        'benchmark/vectors/TC-01_bloc.bad.dart',
        'benchmark/vectors/TC-01_bloc.good.dart',
      ]) {
        File('${root.path}/$name')
            .writeAsStringSync(File(name).readAsStringSync());
      }
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('grades the golden pair in an explicit root', () {
      expect(cli.grade(root: root.path), isZero);
      final lines = File('${root.path}/evidence.jsonl').readAsLinesSync();
      expect(lines, hasLength(2));
    });

    test('analyzer crash fails closed without killing the run', () {
      File('${root.path}/benchmark/vectors/TC-01_bloc.good.dart')
          .deleteSync();
      expect(cli.grade(root: root.path), isNonZero);
      final lines = File('${root.path}/evidence.jsonl').readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines[0], contains('TC-01_bloc.bad.dart'));
      expect(lines[0], contains('"status":"FAILED"'));
      expect(lines[0], isNot(contains('analyzer crashed')));
      expect(lines[1], contains('TC-01_bloc.good.dart'));
      expect(lines[1], contains('"status":"FAILED"'));
      expect(lines[1], contains('analyzer crashed on this file'));
    });

    test('one malformed spec fails the run without killing it', () {
      File('${root.path}/specs/TS-99-broken.md')
          .writeAsStringSync('---not-a-spec---\n');
      expect(cli.grade(root: root.path), isNonZero);
      final lines = File('${root.path}/evidence.jsonl').readAsLinesSync();
      expect(lines, hasLength(2));
      expect(lines.every((l) => l.contains('FG-BLOC-001')), isTrue);
    });
  });
}
