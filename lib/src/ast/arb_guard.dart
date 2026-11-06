// FG-ARB-027: ARB placeholders must declare @key metadata.
//
// An `.arb` message using `{name}` without a sibling `@key`
// `placeholders` entry generates an untyped argument — or breaks
// `gen-l10n` outright for formatted placeholders. Every top-level
// brace head in a message value must be declared; nested spans
// inside plural/select cases are case text, not placeholders.
// Malformed JSON fails closed with a single finding (a broken
// catalog breaks codegen — never silently clean).
import 'dart:convert';
import 'dart:io';

import 'rule_violation.dart';

/// A single FG-ARB-027 violation.
class ArbViolation implements RuleViolation {
  const ArbViolation({required this.line, required this.message});

  /// 1-based line number of the message key.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ARB-027 violation found.
List<ArbViolation> analyzeArbFile(String path) {
  final source = File(path).readAsStringSync();
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    return [
      ArbViolation(
        line: _lineAt(source, error.offset ?? 0),
        message: 'invalid JSON: ${error.message}; fix the catalog',
      ),
    ];
  }
  if (decoded is! Map) {
    return const [
      ArbViolation(
        line: 1,
        message: 'invalid ARB catalog: top level must be an object',
      ),
    ];
  }
  final found = <ArbViolation>[];
  for (final entry in decoded.entries) {
    final key = entry.key;
    if (key is! String || key.startsWith('@')) continue;
    final value = entry.value;
    if (value is! String) continue;
    final declared = _declaredPlaceholders(decoded['@$key']);
    for (final head in _placeholderHeads(value)) {
      if (declared.contains(head)) continue;
      found.add(
        ArbViolation(
          line: _keyLine(source, key),
          message:
              "'$head' in '$key' lacks @key metadata; declare it under "
              "'@$key' placeholders",
        ),
      );
    }
  }
  // Line order, document order within a line (decorate-sort).
  final ranked = [for (var i = 0; i < found.length; i++) (i, found[i])];
  ranked.sort((a, b) {
    final byLine = a.$2.line.compareTo(b.$2.line);
    return byLine != 0 ? byLine : a.$1.compareTo(b.$1);
  });
  return [for (final r in ranked) r.$2];
}

/// Placeholder names declared under `@key` (`{}` when the metadata
/// or its `placeholders` entry is missing or not a map).
Set<String> _declaredPlaceholders(Object? meta) {
  if (meta is! Map) return const {};
  final placeholders = meta['placeholders'];
  if (placeholders is! Map) return const {};
  return placeholders.keys.whereType<String>().toSet();
}

/// Head identifiers of the top-level `{...}` spans in [value], in
/// occurrence order (`{name}` and `{count, plural, ...}` each yield
/// one head). Nested spans, stray closers, unclosed spans, and
/// non-identifier heads are ignored (ICU validation is not this
/// gate; the scan is quote-naive per TS-27 §3).
List<String> _placeholderHeads(String value) {
  final heads = <String>[];
  var depth = 0;
  var spanStart = 0;
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == '{') {
      if (depth == 0) spanStart = i + 1;
      depth++;
    } else if (char == '}') {
      if (depth == 0) continue;
      depth--;
      if (depth == 0) {
        final head = _headOf(value.substring(spanStart, i));
        if (head != null) heads.add(head);
      }
    }
  }
  return heads;
}

/// Head identifier of one top-level span body, or null when the
/// body opens with no identifier (`{}`, `{0}`, `{, ...}`).
String? _headOf(String body) {
  return RegExp(r'^\s*([A-Za-z_][A-Za-z0-9_]*)').firstMatch(body)?.group(1);
}

/// 1-based line of the `"key"` spelling (first occurrence; line 1
/// when absent, e.g. escaped-quote keys — the finding still fires).
int _keyLine(String source, String key) {
  final offset = source.indexOf('"$key"');
  return _lineAt(source, offset < 0 ? 0 : offset);
}

/// 1-based line of [offset] in [source].
int _lineAt(String source, int offset) {
  var line = 1;
  final end = offset < source.length ? offset : source.length;
  for (var i = 0; i < end; i++) {
    if (source.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}
