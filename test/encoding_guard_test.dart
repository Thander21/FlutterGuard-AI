import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

// NOTE: mojibake markers below are spelled as codepoints — a
// literal U+FFFD or mojibake pair here would flag this very file
// (dogfood L0). Legitimate ã/ç/Ê below are literal on purpose:
// they prove the rule does not fire on real accented text.
String _m(List<int> points) => String.fromCharCodes(points);

void main() {
  group('FG-ENC-022 encoding guard', () {
    test('flags mojibake in the golden bad vector', () {
      final violations = analyzeEncFile('benchmark/vectors/TC-22_enc.bad.dart');
      expect(violations.map((v) => v.line), [2, 5]);
      expect(violations.first.message, contains('U+00C3'));
      expect(violations.first.message, contains('UTF-8'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeEncFile(
        'benchmark/vectors/TC-22_enc.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags invalid bytes, replacement chars, and U+00C2', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final raw = '${root.path}/raw.dart';
        File(raw).writeAsBytesSync([0x63, 0x6C, 0x61, 0x73, 0x73, 0xFF, 0x0A]);
        final rawViolations = analyzeEncFile(raw);
        expect(rawViolations.map((v) => v.line), [1]);
        expect(rawViolations.single.message, contains('not valid UTF-8'));

        final fffd = '${root.path}/fffd.dart';
        File(fffd).writeAsStringSync('x${_m([0xFFFD])}\n');
        final fffdViolations = analyzeEncFile(fffd);
        expect(fffdViolations.map((v) => v.line), [1]);
        expect(fffdViolations.single.message, contains('U+FFFD'));

        final circumflex = '${root.path}/circumflex.dart';
        // U+00C2 U+00A0: the ghost of a UTF-8 no-break space.
        File(circumflex).writeAsStringSync('a${_m([0xC2, 0xA0])}b\n');
        final circumflexViolations = analyzeEncFile(circumflex);
        expect(circumflexViolations.map((v) => v.line), [1]);
        expect(circumflexViolations.single.message, contains('U+00C2 U+00A0'));

        // A lone U+00C2 before ASCII is a letter, not a ghost.
        final lone = '${root.path}/lone.dart';
        File(lone).writeAsStringSync('a${_m([0xC2])} b\n');
        expect(analyzeEncFile(lone), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('dedupes same-line hits and reports each line', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final path = '${root.path}/multi.dart';
        final ghost = _m([0xC3, 0xA7]);
        File(path).writeAsStringSync('a${ghost}b${ghost}c\nok\n${ghost}d\n');
        expect(analyzeEncFile(path).map((v) => v.line), [1, 3]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('K1 spares legitimate uppercase U+00C3/U+00C2 words and tables', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final a = _m([0xC3]);
        final c = _m([0xC2]);
        final path = '${root.path}/upper.dart';
        File(path).writeAsStringSync(
          'N${a}O\n'
          'A${_m([0xC7])}${a}O\n'
          '${c}NGULO\n'
          'PERMISS${a}O,\n'
          "'${_m([0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5])}"
          "${_m([0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5])}'\n",
        );
        expect(analyzeEncFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('K2 flags U+00C3/U+00C2 followed by a continuation-byte ghost', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final path = '${root.path}/ghosts.dart';
        File(path).writeAsStringSync(
          'caf${_m([0xC3, 0xA9])}\n'
          '${_m([0xC3, 0x161])}ltimo\n'
          '${_m([0xC3, 0x8D])}cone\n'
          '${_m([0xC3, 0xA7])}\n',
        );
        final violations = analyzeEncFile(path);
        expect(violations.map((v) => v.line), [1, 2, 3, 4]);
        expect(violations[0].message, contains('U+00C3 U+00A9'));
        expect(violations[1].message, contains('U+00C3 U+0161'));
        expect(violations[2].message, contains('U+00C3 U+008D'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('K4 ghost range boundary: U+00C0 spared, U+00BF flagged', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final spared = '${root.path}/c0.dart';
        File(spared).writeAsStringSync('x${_m([0xC3, 0xC0])}\n');
        expect(analyzeEncFile(spared), isEmpty);

        final flagged = '${root.path}/bf.dart';
        File(flagged).writeAsStringSync('x${_m([0xC3, 0xBF])}\n');
        expect(analyzeEncFile(flagged).map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags the 3-byte smart-punctuation ghost family', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final path = '${root.path}/smart.dart';
        File(path).writeAsStringSync(
          'it${_m([0xE2, 0x20AC, 0x2122])}s\n'
          '${_m([0xE2, 0x20AC, 0x201C])}dash\n'
          'pre${_m([0xE2])}mio ${_m([0xE2, 0x20AC])} 10\n',
        );
        final violations = analyzeEncFile(path);
        expect(violations.map((v) => v.line), [1, 2]);
        expect(violations.first.message, contains('U+00E2 U+20AC U+2122'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares ASCII and accented text', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final ascii = '${root.path}/ascii.dart';
        File(ascii).writeAsStringSync('void main() {}\n');
        expect(analyzeEncFile(ascii), isEmpty);

        final accented = '${root.path}/accented.dart';
        File(
          accented,
        ).writeAsStringSync(utf8.decode(utf8.encode('coração Êxodo maçã\n')));
        expect(analyzeEncFile(accented), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
