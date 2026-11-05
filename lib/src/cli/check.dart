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

/// Result of [checkPath]: findings plus per-file errors.
class CheckResult {
  const CheckResult({required this.findings, required this.errors});

  final List<CheckFinding> findings;
  final List<CheckError> errors;

  Map<String, Object?> toJson() => {
    'findings': [for (final f in findings) f.toJson()],
    'errors': [for (final e in errors) e.toJson()],
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
/// is true (see [collectDartFiles]).
/// Results are sorted by file, then rule id, then line for determinism.
CheckResult checkPath(String target, {bool includeGenerated = false}) {
  final files = collectDartFiles(target, includeGenerated: includeGenerated);
  final batched = ruleAnalyzers.where((r) => r.id == batchRuleId).toList();
  final immediate = ruleAnalyzers.where((r) => r.id != batchRuleId).toList();
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
              severity: rule.severity,
            ),
          );
        }
      }
    } catch (error) {
      errors.add(CheckError(file: target, error: '$error'));
    }
  }
  all.sort(_byFileRuleLine);
  return CheckResult(findings: all, errors: errors);
}

/// Deterministic finding order: file, then rule id, then line.
int _byFileRuleLine(CheckFinding a, CheckFinding b) {
  final byFile = a.file.compareTo(b.file);
  if (byFile != 0) return byFile;
  final byRule = a.ruleId.compareTo(b.ruleId);
  if (byRule != 0) return byRule;
  return a.line.compareTo(b.line);
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
              severity: rule.severity,
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
    'Usage: dart run bin/flutterguard.dart check <path> [--json] [--include-generated] [--help]';

/// Audits one target with every registered visitor. Returns 1 when any
/// error-severity violation is found, 0 when clean or warnings-only,
/// 2 on bad arguments.
int check(List<String> args) {
  final parser = ArgParser()
    ..addFlag('json', negatable: false, help: 'Report findings as JSON.')
    ..addFlag(
      'include-generated',
      negatable: false,
      help: 'Scan generated files too.',
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
  late final CheckResult result;
  try {
    result = checkPath(targets.single, includeGenerated: includeGenerated);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    return 2;
  }
  for (final error in result.errors) {
    stderr.writeln('error: ${error.file}: ${error.error}');
  }
  if (asJson) {
    stdout.writeln(jsonEncode(result.toJson()));
  } else {
    for (final finding in result.findings) {
      final prefix = finding.severity == 'warning' ? 'warning: ' : '';
      stdout.writeln(
        '$prefix${finding.ruleId} ${finding.file}:${finding.line} ${finding.message}',
      );
    }
    stdout.writeln(
      '${result.findings.length} violation(s) in ${targets.single}.',
    );
  }
  return result.findings.any((f) => f.severity == 'error') ? 1 : 0;
}
