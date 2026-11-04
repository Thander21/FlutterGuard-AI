// `check` core: run every registered visitor over a file or directory.
//
// Pure library code (no stdout/stderr side effects) so the CLI stays thin
// and the behavior is unit-testable.
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

/// Runs every registered visitor over [target] (one `.dart` file or a
/// directory scanned recursively for `.dart` files, sorted).
///
/// One bad file never kills the run: per-file failures are collected once
/// per file in [CheckResult.errors]. Throws [ArgumentError] when [target]
/// is missing.
/// Results are sorted by file, then rule id, then line for determinism.
CheckResult checkPath(String target) {
  final files = collectDartFiles(target);
  final (:findings, :errors) =
      analyzeFilesWithRules(files, ruleAnalyzers);
  return CheckResult(findings: findings, errors: errors);
}

/// Runs [analyzers] over [files], collecting findings and one error
/// per broken file. Shared `check`/lite loop: findings sort by file,
/// then rule id, then line for determinism.
({List<CheckFinding> findings, List<CheckError> errors})
    analyzeFilesWithRules(
        List<String> files, List<RuleAnalyzer> analyzers) {
  final findings = <CheckFinding>[];
  final errors = <CheckError>[];
  final seenErrors = <(String, String)>{};
  for (final file in files) {
    for (final rule in analyzers) {
      try {
        for (final violation in rule.analyze(file)) {
          findings.add(CheckFinding(
            ruleId: rule.id,
            spec: rule.spec,
            file: file,
            line: violation.line,
            message: violation.message,
            severity: rule.severity,
          ));
        }
      } catch (error) {
        // One broken file fails every visitor the same way; record it once.
        if (seenErrors.add((file, '$error'))) {
          errors.add(CheckError(file: file, error: '$error'));
        }
      }
    }
  }
  findings.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    if (byFile != 0) return byFile;
    final byRule = a.ruleId.compareTo(b.ruleId);
    if (byRule != 0) return byRule;
    return a.line.compareTo(b.line);
  });
  return (findings: findings, errors: errors);
}
