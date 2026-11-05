// FG-FMT-016: flag files the formatter would rewrite.
//
// The oracle is the ambient SDK itself: bounded `dart format
// --output=none --set-exit-if-changed` batches over the target
// files, verdicts attributed from the `Changed ` stdout lines.
// Running on the originals preserves package context, so
// language-version resolution matches a manual CLI run exactly —
// skew is impossible by construction, with no added dependency
// (no dart_style dependency: a second formatting implementation
// could skew from the ambient SDK).
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

/// Maximum files per formatter spawn.
///
/// The Windows command line caps at 32,767 characters; 50 files keep
/// even deep-tree batches (50 x ~300-char paths) under half that
/// budget with margin (SYS-CAL-002 P0-2).
const formatBatchSize = 50;

/// Runs the formatter over [files] in bounded batches and maps
/// `Changed ` lines back to verdicts by normalized path.
///
/// [batchSize] overrides the chunk size (tests pin multi-chunk
/// merging without spawning 50+ fixtures); it must be positive.
/// Throws [ArgumentError] on a non-positive [batchSize],
/// [FileSystemException] when a file is unreadable, [StateError]
/// when the formatter exits outside `{0, 1, 65}` or reports a file
/// outside [files]. Never spawns for an empty list (`dart format`
/// with no files reads stdin).
Map<String, List<FormatViolation>> analyzeFormatBatch(
  List<String> files, {
  int batchSize = formatBatchSize,
}) {
  if (files.isEmpty) return const {};
  if (batchSize < 1) {
    throw ArgumentError('batchSize must be positive: $batchSize');
  }
  final merged = <String, List<FormatViolation>>{};
  for (var start = 0; start < files.length; start += batchSize) {
    merged.addAll(
      _analyzeFormatChunk(files.skip(start).take(batchSize).toList()),
    );
  }
  return merged;
}

/// Runs one formatter spawn over [chunk] and maps `Changed ` lines
/// back to verdicts by normalized path.
Map<String, List<FormatViolation>> _analyzeFormatChunk(List<String> chunk) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...chunk,
  ]);
  if (!_verdictExitCodes.contains(result.exitCode)) {
    throw StateError(
      'dart format failed with exit ${result.exitCode} '
      'over ${chunk.length} file(s)',
    );
  }
  final byPath = {for (final file in chunk) _normalizePath(file): file};
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
    for (final file in chunk)
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
