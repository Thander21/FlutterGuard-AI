// FG-ENC-022: sources must be clean UTF-8.
//
// A Latin-1-saved (or mis-decoded) file compiles fine and
// corrupts silently: accented words render with Latin-1 ghosts
// where the real letters should be. Strict UTF-8 decode must
// succeed, and the decoded text must contain no mojibake
// sequence: U+FFFD, or a lead ghost (U+00C3, U+00C2) followed
// by a continuation-byte ghost (U+0080-U+00BF, or the CP1252
// letters of bytes 0x80-0x9F), or the 3-byte smart-punctuation
// ghost U+00E2 U+20AC followed by a continuation-byte ghost.
// A lone U+00C3/U+00C2 is a real letter (uppercase PT-BR/FR
// words, character tables) and never trips it. Byte-level,
// universal, no config.
//
// NOTE: this file spells every marker as a codepoint escape — a
// literal marker here would flag this very file (dogfood L0).
import 'dart:convert';
import 'dart:io';

import 'rule_violation.dart';

/// CP1252 renderings of bytes 0x80-0x9F (0x81/0x8D/0x8F/0x90/0x9D
/// are undefined there and survive as C1 controls, which the
/// U+0080-U+009F range already covers).
const _cp1252Ghosts =
    r'\u20AC\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030'
    r'\u0160\u2039\u0152\u017D\u2018\u2019\u201C\u201D\u2022'
    r'\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u017E\u0178';

/// One continuation-byte ghost (regex class source).
const _ghost =
    r'[\u0080-\u00BF'
    '$_cp1252Ghosts]';

/// Mojibake sequences, spelled as escapes (see NOTE above).
final _markerPattern = RegExp(
  r'\uFFFD|[\u00C3\u00C2]'
  '$_ghost'
  r'|\u00E2\u20AC'
  '$_ghost',
  unicode: true,
);

/// A single FG-ENC-022 violation.
class EncViolation implements RuleViolation {
  const EncViolation({required this.line, required this.message});

  /// 1-based line number of the marker (1 for decode failure).
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ENC-022 violation found.
///
/// One violation per affected line (same-line hits dedupe);
/// decode failure reports line 1.
List<EncViolation> analyzeEncFile(String path) {
  final bytes = File(path).readAsBytesSync();
  String text;
  try {
    text = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return const [
      EncViolation(
        line: 1,
        message: 'file is not valid UTF-8; save it as UTF-8',
      ),
    ];
  }
  final matches = _markerPattern.allMatches(text).toList();
  if (matches.isEmpty) return const [];
  final starts = _lineStarts(text);
  final flagged = <int, String>{};
  for (final match in matches) {
    final line = _lineAt(starts, match.start);
    flagged.putIfAbsent(line, () => match[0]!);
  }
  final violations = <EncViolation>[];
  for (final entry in flagged.entries) {
    final marker = entry.value;
    final codes = marker.runes
        .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
        .join(' ');
    violations.add(
      EncViolation(
        line: entry.key,
        message:
            "mojibake sequence '$marker' ($codes) — text may be "
            'mis-decoded; save the file as UTF-8',
      ),
    );
  }
  return violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Offset of every line start in [text].
List<int> _lineStarts(String text) {
  final starts = <int>[0];
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) starts.add(i + 1);
  }
  return starts;
}

/// 1-based line number of [offset] (offsets ascend, so one walk).
int _lineAt(List<int> starts, int offset) {
  var line = 1;
  for (var i = 1; i < starts.length; i++) {
    if (starts[i] > offset) break;
    line = i + 1;
  }
  return line;
}
