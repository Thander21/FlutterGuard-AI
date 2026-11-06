// `check` core: run every registered visitor over a file or directory,
// plus the thin `check()` CLI wrapper (moved from `bin/` by SYS-REL-001
// R3).
//
// `checkPath` is pure library code (no stdout/stderr side effects) so the
// behavior is unit-testable; only the `check()` wrapper touches stdio.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../ast/format_guard.dart';
import '../util.dart';
import 'baseline.dart';
import 'config.dart';
import 'rules.dart';

/// One violation found by `check`.
class CheckFinding {
  const CheckFinding({
    required this.ruleId,
    required this.spec,
    required this.file,
    required this.line,
    required this.message,
    this.severity = 'error',
  });

  final String ruleId;
  final String spec;
  final String file;
  final int line;
  final String message;

  /// Gate impact: `error` fails the gate, `warning` is advisory-only
  /// (reported but never fails; FG-MET-007 until SYS-CAL-001).
  final String severity;

  /// Pointer to the Before/After recipe (§2 of the spec contract).
  String get recipe => '$spec (§2)';

  Map<String, Object?> toJson() => {
    'rule_id': ruleId,
    'spec': spec,
    'recipe': recipe,
    'file': file,
    'line': line,
    'message': message,
    'severity': severity,
  };
}

/// One file `check` could not analyze (unreadable or unparseable).
class CheckError {
  const CheckError({required this.file, required this.error});

  final String file;
  final String error;

  Map<String, Object?> toJson() => {'file': file, 'error': error};
}

/// Findings in [findings] carrying [severity].
int _countSeverity(List<CheckFinding> findings, String severity) =>
    findings.where((finding) => finding.severity == severity).length;

/// Result of [checkPath]: findings plus per-file errors.
class CheckResult {
  const CheckResult({required this.findings, required this.errors});

  final List<CheckFinding> findings;
  final List<CheckError> errors;

  Map<String, Object?> toJson() => {
    'findings': [for (final f in findings) f.toJson()],
    'errors': [for (final e in errors) e.toJson()],
    'summary': {
      'errors': _countSeverity(findings, 'error'),
      'warnings': _countSeverity(findings, 'warning'),
    },
  };
}

/// Rule id judged by subprocess batches instead of the per-file loop
/// (FG-FMT-016: bounded `dart format` spawns per run, not per file).
const batchRuleId = 'FG-FMT-016';

/// Runs every registered visitor over [target] (one `.dart` file or a
/// directory scanned recursively for `.dart` files, sorted).
///
/// One bad file never kills the run: per-file failures are collected once
/// per file in [CheckResult.errors]. Throws [ArgumentError] when [target]
/// is missing. Generated files are skipped unless [includeGenerated]
/// is true (see [collectDartFiles]). Rules disabled by the nearest
/// `flutterguard.yaml` are skipped (see [enabledAnalyzers]).
/// Results sort by file, rule id, line, and message, then deduplicate
/// on (file, line, rule) (see [deduplicateFindings]).
CheckResult checkPath(String target, {bool includeGenerated = false}) {
  final files = collectDartFiles(target, includeGenerated: includeGenerated);
  return checkFiles(files, target);
}

/// Runs every enabled visitor over [files] (already walked);
/// [target] anchors config discovery. Findings sort and dedup
/// per SYS-CLI-001a §2.
CheckResult checkFiles(List<String> files, String target) {
  final enabled = enabledAnalyzers(target, ruleAnalyzers);
  final batched = enabled.where((r) => r.id == batchRuleId).toList();
  final immediate = enabled.where((r) => r.id != batchRuleId).toList();
  final (:findings, :errors) = analyzeFilesWithRules(files, immediate);
  final all = [...findings];
  for (final rule in batched) {
    try {
      final verdicts = analyzeFormatBatch(files);
      for (final entry in verdicts.entries) {
        for (final violation in entry.value) {
          all.add(
            CheckFinding(
              ruleId: rule.id,
              spec: rule.spec,
              file: entry.key,
              line: violation.line,
              message: violation.message,
              severity: rule.severityFor?.call(violation) ?? rule.severity,
            ),
          );
        }
      }
    } catch (error) {
      errors.add(CheckError(file: target, error: '$error'));
    }
  }
  all.sort(_byFileRuleLine);
  return CheckResult(findings: deduplicateFindings(all), errors: errors);
}

/// Deterministic finding order: file, rule id, line, then message
/// (the message tiebreak keeps the dedup collapse byte-stable).
int _byFileRuleLine(CheckFinding a, CheckFinding b) {
  final byFile = a.file.compareTo(b.file);
  if (byFile != 0) return byFile;
  final byRule = a.ruleId.compareTo(b.ruleId);
  if (byRule != 0) return byRule;
  final byLine = a.line.compareTo(b.line);
  if (byLine != 0) return byLine;
  return a.message.compareTo(b.message);
}

/// Collapses [sorted] findings on (file, line, rule), joining distinct
/// messages with `; `. Input must be in [_byFileRuleLine] order so the
/// collapse is byte-stable (SYS-CLI-001a §2).
List<CheckFinding> deduplicateFindings(List<CheckFinding> sorted) {
  final merged = <CheckFinding>[];
  final seen = <String>{};
  for (final finding in sorted) {
    final last = merged.isEmpty ? null : merged.last;
    final same =
        last != null &&
        last.file == finding.file &&
        last.line == finding.line &&
        last.ruleId == finding.ruleId;
    if (!same) {
      seen.clear();
      merged.add(finding);
      seen.add(finding.message);
    } else if (seen.add(finding.message)) {
      merged[merged.length - 1] = CheckFinding(
        ruleId: last.ruleId,
        spec: last.spec,
        file: last.file,
        line: last.line,
        message: '${last.message}; ${finding.message}',
        severity: last.severity,
      );
    }
  }
  return merged;
}

/// Runs [analyzers] over [files], collecting findings and one error
/// per broken file. Shared `check`/lite loop: findings sort by file,
/// then rule id, then line for determinism.
({List<CheckFinding> findings, List<CheckError> errors}) analyzeFilesWithRules(
  List<String> files,
  List<RuleAnalyzer> analyzers,
) {
  final findings = <CheckFinding>[];
  final errors = <CheckError>[];
  final seenErrors = <(String, String)>{};
  for (final file in files) {
    for (final rule in analyzers) {
      try {
        for (final violation in rule.analyze(file)) {
          findings.add(
            CheckFinding(
              ruleId: rule.id,
              spec: rule.spec,
              file: file,
              line: violation.line,
              message: violation.message,
              severity: rule.severityFor?.call(violation) ?? rule.severity,
            ),
          );
        }
      } catch (error) {
        // One broken file fails every visitor the same way; record it once.
        if (seenErrors.add((file, '$error'))) {
          errors.add(CheckError(file: file, error: '$error'));
        }
      }
    }
  }
  findings.sort(_byFileRuleLine);
  return (findings: findings, errors: errors);
}

/// CLI usage for `check` (SYS-CLI-001a).
const _checkUsage =
    'Usage: dart run bin/flutterguard.dart check <path> [--json] [--include-generated] [--baseline=<path>] [--update-baseline] [--diff] [--diff-base=<ref>] [--help]';

/// Audits one target with every registered visitor. Returns 1 when any
/// error-severity violation is found, 0 when clean or warnings-only,
/// 2 on bad arguments. R2-2: `--baseline`/`--update-baseline` ratchet
/// plus `--diff` scope, with error/warning counts in the output.
int check(List<String> args) {
  final parser = ArgParser()
    ..addFlag('json', negatable: false, help: 'Report findings as JSON.')
    ..addFlag(
      'include-generated',
      negatable: false,
      help: 'Scan generated files too.',
    )
    ..addOption(
      'baseline',
      help: 'Suppress findings ratcheted in this baseline file.',
    )
    ..addFlag(
      'update-baseline',
      negatable: false,
      help: 'Rewrite the --baseline file from this run.',
    )
    ..addFlag(
      'diff',
      negatable: false,
      help: 'Check only files changed vs the merge-base.',
    )
    ..addOption(
      'diff-base',
      help: 'Diff base ref (default origin/main; implies --diff).',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  late final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_checkUsage);
    return 2;
  }
  if (parsed['help'] as bool) {
    stdout.writeln(_checkUsage);
    stdout.writeln(parser.usage);
    return 0;
  }
  final targets = parsed.rest;
  if (targets.length != 1) {
    stderr.writeln(_checkUsage);
    return 2;
  }
  final asJson = parsed['json'] as bool;
  final includeGenerated = parsed['include-generated'] as bool;
  final baselinePath = parsed['baseline'] as String?;
  final updateBaseline = parsed['update-baseline'] as bool;
  final diffBase = parsed['diff-base'] as String?;
  final diffMode = (parsed['diff'] as bool) || diffBase != null;
  if (updateBaseline && diffMode) {
    stderr.writeln('--update-baseline cannot be combined with --diff.');
    stderr.writeln(_checkUsage);
    return 2;
  }
  final updatePath = updateBaseline ? baselinePath : null;
  if (updateBaseline && updatePath == null) {
    stderr.writeln('--update-baseline requires --baseline <path>.');
    stderr.writeln(_checkUsage);
    return 2;
  }
  final target = targets.single;
  late final CheckResult result;
  try {
    var files = collectDartFiles(target, includeGenerated: includeGenerated);
    if (diffMode) {
      final changed = resolveChangedFiles(target, diffBase ?? 'origin/main');
      files = [
        for (final file in files)
          if (changed.contains(absoluteNormalized(file))) file,
      ];
    }
    result = checkFiles(files, target);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    return 2;
  }
  var findings = result.findings;
  if (baselinePath != null && !updateBaseline) {
    try {
      findings = applyBaseline(findings, loadBaseline(baselinePath));
    } on ArgumentError catch (error) {
      stderr.writeln(error.message);
      return 2;
    }
  }
  if (updatePath != null) {
    try {
      writeBaseline(updatePath, result.findings);
    } on ArgumentError catch (error) {
      stderr.writeln(error.message);
      return 2;
    }
    final files = baselineCounts(result.findings).length;
    if (asJson) {
      stdout.writeln(
        jsonEncode({
          'baseline': updatePath,
          'files': files,
          'summary': {
            'errors': _countSeverity(result.findings, 'error'),
            'warnings': _countSeverity(result.findings, 'warning'),
          },
        }),
      );
    } else {
      stdout.writeln(
        'Baseline written to $updatePath: $files files, '
        '${result.findings.length} findings '
        '(${_countSeverity(result.findings, 'error')} errors, '
        '${_countSeverity(result.findings, 'warning')} warnings).',
      );
    }
    return 0;
  }
  final shown = CheckResult(findings: findings, errors: result.errors);
  for (final error in shown.errors) {
    stderr.writeln('error: ${error.file}: ${error.error}');
  }
  if (asJson) {
    stdout.writeln(jsonEncode(shown.toJson()));
  } else {
    for (final finding in shown.findings) {
      final prefix = finding.severity == 'warning' ? 'warning: ' : '';
      stdout.writeln(
        '$prefix${finding.ruleId} ${finding.file}:${finding.line} ${finding.message}',
      );
    }
    stdout.writeln(
      '${shown.findings.length} violation(s) '
      '(${_countSeverity(shown.findings, 'error')} errors, '
      '${_countSeverity(shown.findings, 'warning')} warnings) '
      'in $target.',
    );
  }
  return shown.findings.any((f) => f.severity == 'error') ? 1 : 0;
}
