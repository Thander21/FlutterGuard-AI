// SYS-HEAL-001: heal dispatcher — fast-path mechanical patches with
// snapshot rollback and a diagnostic report.
//
// Pure library code (file effects limited to the healed target plus its
// `.heal-report.md` on rollback) so the behavior is unit-testable.
import 'dart:io';

import '../ast/rule_violation.dart';

/// Mechanical patch strategies with fixed semantics (SYS-HEAL-001 §2).
enum HealStrategy { insertBeforeInvocation, replaceInvocation }

/// A heal recipe: rule id, strategy, and strategy payload.
class HealRecipe {
  /// Insert [guard] as its own line above the violation's line.
  const HealRecipe.insert({required this.ruleId, required this.guard})
    : strategy = HealStrategy.insertBeforeInvocation,
      from = null,
      to = null;

  /// Replace the first [from] with [to] on the violation's line.
  const HealRecipe.replace({
    required this.ruleId,
    required this.from,
    required this.to,
  }) : strategy = HealStrategy.replaceInvocation,
       guard = null;

  final String ruleId;
  final HealStrategy strategy;
  final String? guard;
  final String? from;
  final String? to;
}

/// One structured capture (SYS-HEAL-001 §2).
class HealError {
  const HealError({
    required this.attempt,
    required this.phase,
    required this.target,
    required this.ruleId,
    required this.error,
  });

  final int attempt;
  final String phase;
  final String target;
  final String ruleId;
  final String error;

  Map<String, Object?> toJson() => {
    'attempt': attempt,
    'phase': phase,
    'target': target,
    'rule_id': ruleId,
    'error': error,
  };
}

/// Outcome of [HealDispatcher.healFile].
class HealResult {
  const HealResult({
    required this.success,
    required this.attempts,
    required this.rolledBack,
    required this.errors,
    required this.report,
  });

  final bool success;
  final int attempts;
  final bool rolledBack;
  final List<HealError> errors;
  final String report;
}

/// Fast-path mechanical dispatcher with snapshot rollback.
///
/// Each attempt heals the first remaining violation, then re-verifies.
/// A no-op patch means the premise is exhausted: the run stops without
/// burning the cap, restores the snapshot, and emits the diagnostic
/// report carrying the Attack-the-Premise prompt.
class HealDispatcher {
  HealDispatcher({this.maxAttempts = 3});

  final int maxAttempts;

  HealResult healFile({
    required String path,
    required HealRecipe recipe,
    required List<RuleViolation> Function(String) analyze,
  }) {
    final snapshot = File(path).readAsStringSync();
    final errors = <HealError>[];
    var attempts = 0;

    List<RuleViolation>? detect(int attempt, String phase) {
      try {
        return analyze(path);
      } catch (error) {
        errors.add(
          HealError(
            attempt: attempt,
            phase: phase,
            target: path,
            ruleId: recipe.ruleId,
            error: '$error',
          ),
        );
        return null;
      }
    }

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      attempts = attempt;
      final violations = detect(attempt, 'detect');
      if (violations == null) break;
      if (violations.isEmpty) {
        return HealResult(
          success: true,
          attempts: attempts,
          rolledBack: false,
          errors: errors,
          report: '',
        );
      }
      if (!_apply(path, violations.first, recipe)) {
        errors.add(
          HealError(
            attempt: attempt,
            phase: 'patch',
            target: path,
            ruleId: recipe.ruleId,
            error: 'no-op: premise exhausted',
          ),
        );
        break;
      }
      final reverified = detect(attempt, 'verify');
      if (reverified == null) break;
      if (reverified.isEmpty) {
        return HealResult(
          success: true,
          attempts: attempts,
          rolledBack: false,
          errors: errors,
          report: '',
        );
      }
    }

    File(path).writeAsStringSync(snapshot);
    final report = _report(path, recipe, attempts, maxAttempts, errors);
    File('$path.heal-report.md').writeAsStringSync(report);
    return HealResult(
      success: false,
      attempts: attempts,
      rolledBack: true,
      errors: errors,
      report: report,
    );
  }

  /// Applies [recipe] to [violation]; false when the patch is a no-op.
  bool _apply(String path, RuleViolation violation, HealRecipe recipe) {
    final lines = File(path).readAsLinesSync();
    final index = violation.line - 1;
    if (index < 0 || index >= lines.length) return false;
    switch (recipe.strategy) {
      case HealStrategy.insertBeforeInvocation:
        final indent = _indentOf(lines[index]);
        final insertion = '$indent${recipe.guard}';
        if (index > 0 && lines[index - 1] == insertion) return false;
        lines.insert(index, insertion);
      case HealStrategy.replaceInvocation:
        final from = recipe.from!;
        if (!lines[index].contains(from)) return false;
        lines[index] = lines[index].replaceFirst(from, recipe.to!);
    }
    File(path).writeAsStringSync('${lines.join('\n')}\n');
    return true;
  }

  String _indentOf(String line) => RegExp(r'^\s*').firstMatch(line)!.group(0)!;

  String _report(
    String path,
    HealRecipe recipe,
    int attempts,
    int cap,
    List<HealError> errors,
  ) {
    final rows = errors
        .map((e) => '| ${e.attempt} | ${e.phase} | ${e.error} |')
        .join('\n');
    return '''# Heal diagnostic report (SYS-HEAL-001)

- At: ${DateTime.now().toUtc().toIso8601String()}
- Target: $path
- Rule: ${recipe.ruleId} (${recipe.strategy.name})
- Result: FAILED after $attempts/$cap attempts — snapshot restored, no files changed.
- No auto-commit: human review required.

## Attempts

| attempt | phase | error |
|---|---|---|
${rows.isEmpty ? '| — | — | patches applied without convergence |' : rows}

## Attack the Premise

Repeated attempts failed the same gate. Before editing again: state the
shared technical premise in one sentence, name the architectural
contradiction, and redefine the fix from first principles.
''';
  }
}
