// FG-DOC-032: local Markdown links must resolve.
//
// Docs link the file the plan promised instead of the file that
// landed, and nobody clicks every link before merging. Every
// inline link `[text](target)` and image `![alt](target)` with a
// local target must resolve to an existing file or directory
// next to the analyzed file. Fenced blocks and inline code
// spans are stripped before matching, so literal text never
// flags; remote, anchor-only, empty, and absolute targets are
// skipped (unresolvable without a doc root or a network).
import 'dart:io';

import 'rule_violation.dart';

/// A single FG-DOC-032 violation.
class DocViolation implements RuleViolation {
  const DocViolation({required this.line, required this.message});

  /// 1-based line number of the dead link.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Inline link/image destinations, with optional `<angle>`
/// wrapping (which may carry spaces) and trailing `"titles"`.
final _link = RegExp(r'!?\[[^\]]*\]\(\s*(?:<([^>]+)>|([^)\s>]+))[^)]*\)');

/// Inline code spans (stripped before matching).
final _span = RegExp(r'`[^`\n]*`');

/// Fence opener/closer (indent plus 3+ backticks or tildes).
final _fence = RegExp(r'^\s*(```+|~~~+)');

/// Remote schemes skipped without resolution (the `C:` arm also
/// skips Windows drive targets, meaningless portably).
final _remote = RegExp(r'^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)');

/// Analyzes [path] and returns every FG-DOC-032 violation found.
List<DocViolation> analyzeDocFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final dir = normalized.contains('/')
      ? normalized.substring(0, normalized.lastIndexOf('/'))
      : '.';
  final lines = File(path).readAsStringSync().split('\n');
  final violations = <DocViolation>[];
  var fenced = false;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    if (_fence.hasMatch(line)) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;
    final prose = line.replaceAll(_span, '');
    for (final match in _link.allMatches(prose)) {
      final target = match.group(1) ?? match.group(2)!;
      if (_remote.hasMatch(target)) continue;
      if (target.startsWith('/')) continue;
      final file = target.split('#').first;
      if (file.isEmpty) continue;
      if (File('$dir/$file').existsSync()) continue;
      if (Directory('$dir/$file').existsSync()) continue;
      violations.add(
        DocViolation(
          line: i + 1,
          message:
              "link target '$target' does not resolve; "
              'fix the path or drop the link',
        ),
      );
    }
  }
  return violations..sort((a, b) => a.line.compareTo(b.line));
}
