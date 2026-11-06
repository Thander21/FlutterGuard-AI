// Opt-in analyzer step for `check` (SYS-CAL-003 R2-5 medium list).
//
// Runs the ambient SDK's `dart analyze --fatal-infos` over the
// target and parses `--format machine` issues into per-file
// groups. The ambient SDK is the oracle (the format-guard
// precedent: skew is impossible by construction, no added
// dependency). Findings stay rule-pure: analyzer issues surface
// as `analyzer:`-prefixed gate errors, never as findings.
import 'dart:io';

/// One analyzer issue parsed from `--format machine` output.
class AnalyzerIssue {
  const AnalyzerIssue({
    required this.file,
    required this.line,
    required this.message,
  });

  /// Forward-slash file path (machine output escapes Windows
  /// separators — unescaped here).
  final String file;

  /// 1-based line number.
  final int line;

  /// `SEVERITY: message` as reported.
  final String message;
}

/// Outcome of [runAnalyzer].
class AnalyzerResult {
  const AnalyzerResult({required this.exitCode, required this.issues});

  /// Analyzer process exit code (non-zero means issues at or
  /// above the fatal level).
  final int exitCode;

  /// Parsed machine-format issues (possibly empty on failure —
  /// the exit code gates, not the parse).
  final List<AnalyzerIssue> issues;

  /// True when the analyzer reported no fatal issues.
  bool get passed => exitCode == 0;
}

/// Parses `dart analyze --format machine` [stdout] into issues.
///
/// Lines are shaped
/// `SEVERITY|KIND|CODE|FILE|LINE|COL|LENGTH|MESSAGE`; messages
/// may carry pipes (rejoined). Malformed lines are skipped
/// (fail-open on format drift — the exit code still gates).
List<AnalyzerIssue> parseAnalyzerOutput(String stdout) {
  final issues = <AnalyzerIssue>[];
  for (var line in stdout.split('\n')) {
    line = line.trim();
    if (line.isEmpty) continue;
    final parts = line.split('|');
    if (parts.length < 8) continue;
    final lineNo = int.tryParse(parts[4]);
    if (lineNo == null) continue;
    issues.add(
      AnalyzerIssue(
        file: parts[3].replaceAll('\\\\', '\\').replaceAll(r'\', '/'),
        line: lineNo,
        message: '${parts[0]}: ${parts.sublist(7).join('|')}',
      ),
    );
  }
  return issues;
}

/// Groups [issues] per file (`file → 'L2: msg; ...'`), files and
/// lines sorted, so runs are byte-stable.
Map<String, String> groupAnalyzerIssues(List<AnalyzerIssue> issues) {
  final byFile = <String, List<AnalyzerIssue>>{};
  for (final issue in issues) {
    byFile.putIfAbsent(issue.file, () => []).add(issue);
  }
  final grouped = <String, String>{};
  for (final file in byFile.keys.toList()..sort()) {
    final lines = byFile[file]!..sort((a, b) => a.line.compareTo(b.line));
    grouped[file] = lines.map((i) => 'L${i.line}: ${i.message}').join('; ');
  }
  return grouped;
}

/// Runs `dart analyze --fatal-infos` over [target] (one file or a
/// directory) and parses the machine-format issues. Throws
/// [ArgumentError] when the SDK cannot be spawned; analyzer
/// findings are data (gated by [AnalyzerResult.passed]), never
/// throws.
AnalyzerResult runAnalyzer(String target) {
  ProcessResult result;
  try {
    result = Process.runSync(Platform.resolvedExecutable, [
      'analyze',
      '--fatal-infos',
      '--format',
      'machine',
      target,
    ]);
  } on ProcessException catch (error) {
    throw ArgumentError('cannot run dart analyze: ${error.message}');
  }
  return AnalyzerResult(
    exitCode: result.exitCode,
    issues: parseAnalyzerOutput(result.stdout as String),
  );
}
