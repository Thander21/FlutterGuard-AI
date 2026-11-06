// FG-ENC-022: sources must be clean UTF-8.
//
// A Latin-1-saved (or mis-decoded) file compiles fine and
// corrupts silently: accented words render with Latin-1 ghosts
// where the real letters should be. Strict UTF-8 decode must
// succeed, and the decoded text must contain none of the
// mojibake markers (U+FFFD, U+00C3, U+00C2). Legitimate
// accented text (U+00E3, U+00F5, U+00E7) never trips it: the
// markers are ghosts of multi-byte sequences, not the letters
// themselves. Byte-level, universal, no config.
//
// NOTE: this file spells every marker as a codepoint escape — a
// literal marker here would flag this very file (dogfood L0).
import 'dart:convert';
import 'dart:io';

import 'rule_violation.dart';

/// Mojibake markers, spelled as escapes (see NOTE above).
final _markerPattern = RegExp(
  '[${String.fromCharCodes([0xFFFD, 0xC3, 0xC2])}]',
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
    flagged.putIfAbsent(line, () => text[match.start]);
  }
  final violations = <EncViolation>[];
  for (final entry in flagged.entries) {
    final marker = entry.value;
    final code = marker
        .codeUnitAt(0)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    violations.add(
      EncViolation(
        line: entry.key,
        message:
            "mojibake marker '$marker' (U+$code) — text may be "
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
