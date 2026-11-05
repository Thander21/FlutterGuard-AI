// FG-FMT-016: flag files the formatter would rewrite.
//
// The oracle is the ambient SDK itself: one `dart format
// --output=none --set-exit-if-changed` batch over the target
// files, verdicts attributed from the `Changed ` stdout lines.
// Running on the originals preserves package context, so
// language-version resolution matches a manual CLI run exactly —
// skew is impossible by construction, with no added dependency
// (dart_style 3.x needs analyzer ^7+ vs analyzer ^6.0.0 here;
// 2.x formats short style).
import 'dart:io';

import 'rule_violation.dart';

/// Formatter exit codes with per-file verdicts: clean (0),
/// changed (1), or nothing formattable (65, e.g. unparseable-only
/// input — yields no findings, FG-SYN-017 owns that verdict).
const _verdictExitCodes = <int>{0, 1, 65};

/// A single FG-FMT-016 violation (whole-file verdict at line 1).
class FormatViolation implements RuleViolation {
  const FormatViolation({required this.message});

  /// Whole-file verdicts always report line 1.
  @override
  int get line => 1;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns the FG-FMT-016 verdict (empty when
/// clean). Registry entry point; batch-of-one over
/// [analyzeFormatBatch].
List<FormatViolation> analyzeFormatFile(String path) {
  // The read doubles as the existence check (FileSystemException
  // on missing files, like every AST visitor).
  File(path).readAsStringSync();
  return analyzeFormatBatch([path])[path] ?? const [];
}

/// Runs one formatter batch over [files] and maps `Changed ` lines
/// back to verdicts by normalized path.
///
/// Throws [FileSystemException] when a file is unreadable,
/// [StateError] when the formatter exits outside `{0, 1, 65}` or
/// reports a file outside [files]. Never spawns for an empty list
/// (`dart format` with no files reads stdin).
Map<String, List<FormatViolation>> analyzeFormatBatch(List<String> files) {
  if (files.isEmpty) return const {};
  final result = Process.runSync(Platform.resolvedExecutable, [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...files,
  ]);
  if (!_verdictExitCodes.contains(result.exitCode)) {
    throw StateError(
      'dart format failed with exit ${result.exitCode} '
      'over ${files.length} file(s)',
    );
  }
  final byPath = {for (final file in files) _normalizePath(file): file};
  final changed = <String>{};
  for (final line in (result.stdout as String).split('\n')) {
    if (!line.startsWith('Changed ')) continue;
    final reported = _normalizePath(line.substring('Changed '.length).trim());
    final original = byPath[reported];
    if (original == null) {
      throw StateError('unmappable formatter output: $line');
    }
    changed.add(original);
  }
  return {
    for (final file in files)
      file: changed.contains(file)
          ? const [
              FormatViolation(
                message:
                    'file is not dart-format clean; '
                    'run `dart format` to heal',
              ),
            ]
          : const <FormatViolation>[],
  };
}

/// Canonical spelling for formatter path mapping (the CLI echoes
/// arguments verbatim; separator and `./` noise is factored out).
String _normalizePath(String path) {
  var normalized = path.replaceAll(r'\', '/');
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}
