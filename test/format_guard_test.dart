// FG-FMT-016 contract test: flags files the formatter would
// rewrite, spares clean content (endings never attribute).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-FMT-016 format guard', () {
    test('flags the .bad vector at line 1 (whole-file verdict)', () {
      final violations =
          analyzeFormatFile('benchmark/vectors/TC-16_fmt.bad.dart');
      expect(violations.map((v) => v.line), [1]);
      expect(violations.first.message, contains('dart format'));
    });

    test('spares the .good vector (zero false positives)', () {
      final violations =
          analyzeFormatFile('benchmark/vectors/TC-16_fmt.good.dart');
      expect(violations, isEmpty);
    });

    test('spares CRLF-normalized content (endings never attribute)', () {
      final root = Directory.systemTemp.createTempSync('fmt_test.');
      try {
        final clean = File('${root.path}/clean.dart')
          ..writeAsStringSync(File('benchmark/vectors/TC-16_fmt.good.dart')
              .readAsStringSync()
              .replaceAll('\n', '\r\n'));
        expect(analyzeFormatFile(clean.path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares unparseable files (FG-SYN-017 owns them)', () {
      final root = Directory.systemTemp.createTempSync('fmt_test.');
      try {
        final broken = File('${root.path}/broken.dart')
          ..writeAsStringSync('class { !!!');
        expect(analyzeFormatFile(broken.path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags empty files (CLI truth, never special-cased)', () {
      final root = Directory.systemTemp.createTempSync('fmt_test.');
      try {
        final empty = File('${root.path}/empty.dart')..writeAsStringSync('');
        expect(analyzeFormatFile(empty.path).map((v) => v.line), [1]);
        final spaces = File('${root.path}/spaces.dart')
          ..writeAsStringSync('   \n');
        expect(analyzeFormatFile(spaces.path).map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('throws on missing files (never silently clean)', () {
      expect(() => analyzeFormatFile('does/not/exist.dart'),
          throwsA(isA<FileSystemException>()));
    });

    test('batch equals per-file CLI verdicts (mapping test)', () {
      final root = Directory.systemTemp.createTempSync('fmt_test.');
      try {
        final clean = File('${root.path}/a_clean.dart')
          ..writeAsStringSync('void main() {}\n');
        final dirty = File('${root.path}/b_dirty.dart')
          ..writeAsStringSync('void  main()  {}\n');
        final broken = File('${root.path}/c_broken.dart')
          ..writeAsStringSync('class { !!!');
        final crlf = File('${root.path}/d_crlf.dart')
          ..writeAsStringSync('void main() {}\r\n');
        final files = [clean.path, dirty.path, broken.path, crlf.path];

        int cliExit(String path) => Process.runSync(Platform.resolvedExecutable,
                ['format', '--output=none', '--set-exit-if-changed', path])
            .exitCode;
        expect(cliExit(clean.path), 0);
        expect(cliExit(dirty.path), 1);
        expect(cliExit(broken.path), 65);
        expect(cliExit(crlf.path), 0,
            reason: 'CLI and gate agree: endings never attribute');

        final batched = analyzeFormatBatch(files);
        expect(batched[clean.path] ?? [], isEmpty);
        expect(batched[dirty.path]?.map((v) => v.line), [1]);
        expect(batched[broken.path] ?? [], isEmpty);
        expect(batched[crlf.path] ?? [], isEmpty);

        for (final file in files) {
          expect(batched[file]?.map((v) => v.line),
              analyzeFormatFile(file).map((v) => v.line),
              reason: 'batch/single equivalence for $file');
        }
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
