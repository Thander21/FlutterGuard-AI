// FG-SYN-017: fail closed on syntactic errors.
//
// The oracle is the parser's own error list (`throwIfDiagnostics:
// false`); each diagnostic becomes one finding at its offset.
// Before this rule, unparseable files sat in report-only `errors`
// and the light gate stayed green — a fail-open hole this rule
// closes (SYS-CLI-001a §5).
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';

import 'rule_violation.dart';

/// A single FG-SYN-017 violation.
class SyntaxViolation implements RuleViolation {
  const SyntaxViolation({required this.line, required this.message});

  /// 1-based line number of the parser diagnostic.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns one FG-SYN-017 violation per
/// syntactic error (empty when the file parses cleanly).
List<SyntaxViolation> analyzeSyntaxFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  final violations = [
    for (final error in result.errors)
      SyntaxViolation(
        line: result.lineInfo.getLocation(error.offset).lineNumber,
        message: '${error.diagnosticCode.lowerCaseName}: ${error.message}',
      ),
  ]..sort((a, b) => a.line.compareTo(b.line));
  return violations;
}
