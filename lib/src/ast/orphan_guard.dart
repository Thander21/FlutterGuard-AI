// FG-ORP-023: orphaned generated files.
//
// A deleted source leaves its .g.dart behind: it still
// compiles, still confuses searches, and still gets
// resurrected by a careless checkout. Every generated-suffix
// file (.g/.freezed/.gr/.mocks) must have its source sibling
// (suffix stripped + .dart) next to it. Per-file, universal,
// no config.
import 'dart:io';

import '../util.dart';
import 'rule_violation.dart';

/// A single FG-ORP-023 violation.
class OrpViolation implements RuleViolation {
  const OrpViolation({required this.line, required this.message});

  /// Always 1 (the whole file is the finding).
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ORP-023 violation found.
List<OrpViolation> analyzeOrpFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  String? source;
  for (final suffix in generatedFileSuffixes) {
    if (normalized.endsWith(suffix)) {
      source =
          '${normalized.substring(0, normalized.length - suffix.length)}.dart';
      break;
    }
  }
  if (source == null) return const [];
  if (File(source).existsSync()) return const [];
  final file = normalized.split('/').last;
  final want = source.split('/').last;
  return [
    OrpViolation(
      line: 1,
      message:
          "orphaned generated file '$file' — source '$want' is "
          'missing; delete it or regenerate',
    ),
  ];
}
