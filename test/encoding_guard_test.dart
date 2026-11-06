import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

// NOTE: mojibake markers below are spelled as codepoints — a
// literal U+FFFD/U+00C3/U+00C2 here would flag this very file
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
        File(circumflex).writeAsStringSync('a${_m([0xC2])} b\n');
        final circumflexViolations = analyzeEncFile(circumflex);
        expect(circumflexViolations.map((v) => v.line), [1]);
        expect(circumflexViolations.single.message, contains('U+00C2'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('dedupes same-line hits and reports each line', () {
      final root = Directory.systemTemp.createTempSync('enc_test.');
      try {
        final path = '${root.path}/multi.dart';
        final ghost = _m([0xC3]);
        File(path).writeAsStringSync('a${ghost}b${ghost}c\nok\n${ghost}d\n');
        expect(analyzeEncFile(path).map((v) => v.line), [1, 3]);
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
