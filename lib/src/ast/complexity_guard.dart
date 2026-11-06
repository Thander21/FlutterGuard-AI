// FG-CC-025: cyclomatic complexity ceiling.
//
// A god-function with eighty branches is untestable and
// review-proof. Named declarations with bodies score above
// the ceiling of 80 fail, reusing the trusted SYS-COV-001
// counter (closures fold into the enclosing entry; bodiless
// declarations are unscored). The ceiling is fixed (no
// config); [maxComplexity] is injectable for tests only.
import 'dart:io';

import '../coverage/complexity.dart';
import 'rule_violation.dart';

/// Default complexity ceiling (campodeforca fail line).
const defaultMaxComplexity = 80;

/// A single FG-CC-025 violation.
class CcViolation implements RuleViolation {
  const CcViolation({required this.line, required this.message});

  /// 1-based line number of the declaration.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-CC-025 violation found.
List<CcViolation> analyzeCcFile(String path, {int? maxComplexity}) {
  final ceiling = maxComplexity ?? defaultMaxComplexity;
  final source = File(path).readAsStringSync();
  final violations = <CcViolation>[];
  for (final scored in analyzeComplexity(source, path: path)) {
    if (scored.complexity > ceiling) {
      violations.add(
        CcViolation(
          line: scored.line,
          message:
              "'${scored.name}' has cyclomatic complexity "
              '${scored.complexity}, exceeding the budget of $ceiling; '
              'split it into smaller functions',
        ),
      );
    }
  }
  return violations;
}
