// FG-ENV-029: .env keys must match .env.example.
//
// A `.env` that drifts from its `.env.example` boots the next
// clone with a hole (or ships a key nobody documented). Every
// `.env*` file must set exactly the keys its sibling example
// documents. Keys only: the text after the first `=` is never
// read and findings name keys, never values. A missing or
// unreadable example fails open (parity is unjudgeable); the
// example oracle itself is never judged.
import 'dart:io';

import 'rule_violation.dart';

/// A single FG-ENV-029 violation.
class EnvViolation implements RuleViolation {
  const EnvViolation({required this.line, required this.message});

  /// 1-based line number of the extra key, or 1 for a missing key
  /// (file-level — the key has no line to land on).
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ENV-029 violation found.
List<EnvViolation> analyzeEnvFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final base = normalized.split('/').last;
  if (base == '.env.example') return const [];
  final dir = normalized.contains('/')
      ? normalized.substring(0, normalized.lastIndexOf('/'))
      : '.';
  final example = File('$dir/.env.example');
  if (!example.existsSync()) return const [];
  final String exampleSource;
  try {
    exampleSource = example.readAsStringSync();
  } catch (_) {
    return const [];
  }
  final exampleKeys = _keySet(exampleSource);
  final envKeys = _keyLines(File(path).readAsStringSync());
  final violations = <EnvViolation>[];
  for (final entry in envKeys.entries) {
    if (!exampleKeys.contains(entry.key)) {
      violations.add(
        EnvViolation(
          line: entry.value,
          message:
              "'$base' sets '${entry.key}' missing from '.env.example'; "
              'document it or drop it',
        ),
      );
    }
  }
  for (final key in exampleKeys) {
    if (!envKeys.containsKey(key)) {
      violations.add(
        EnvViolation(
          line: 1,
          message: "'$base' lacks '$key' from '.env.example'; add it",
        ),
      );
    }
  }
  return violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Keys bound in [source] (set semantics; first spelling wins).
Set<String> _keySet(String source) => _keyLines(source).keys.toSet();

/// Key bound per line in [source] (first spelling wins), tolerant
/// of CRLF and a leading BOM.
Map<String, int> _keyLines(String source) {
  final keys = <String, int>{};
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (i == 0 && line.startsWith('\uFEFF')) line = line.substring(1);
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    final key = _bindingKey(line);
    if (key != null) keys.putIfAbsent(key, () => i + 1);
  }
  return keys;
}

/// Key bound by [line], or null for comments, blanks, and
/// non-bindings. Only the text before the first `=` is ever read
/// (values stay unread); one optional `export` prefix strips.
String? _bindingKey(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
  var rest = trimmed;
  if (rest.startsWith('export ') || rest.startsWith('export\t')) {
    rest = rest.substring('export'.length).trim();
  }
  final equals = rest.indexOf('=');
  if (equals < 0) return null;
  final key = rest.substring(0, equals).trim();
  if (key.isEmpty) return null;
  if (key.contains(' ') || key.contains('\t')) return null;
  return key;
}
