// `heal` core: thin CLI over HealDispatcher + fast-path recipes, plus
// the thin `heal()` wrapper (SYS-HEAL-001 §2 Wave 2).
//
// Resolves rule → recipe → analyzer, runs one healFile, prints the
// outcome. Zero heal logic here: patch/verify/rollback live in
// `HealDispatcher`; only outcome printing is CLI-owned.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../ast/rule_violation.dart';
import '../heal/dispatcher.dart';
import '../heal/recipes.dart';
import 'rules.dart';

/// CLI usage for `heal` (SYS-HEAL-001 §2).
const _healUsage = 'Usage: dart run bin/flutterguard.dart heal <file.dart> '
    '--rule <RULE-ID> [--attempts N] [--json] [--help]';

/// Default ForceField attempt cap (SYS-HEAL-001 §2).
const _defaultAttempts = 3;

/// Override ceiling: above is a runaway budget, refused.
const _maxAttempts = 10;

/// Machine-readable outcome of a heal run (printed with `--json`).
Map<String, Object?> healResultJson({
  required String target,
  required String ruleId,
  required HealResult result,
}) =>
    {
      'success': result.success,
      'attempts': result.attempts,
      'rolled_back': result.rolledBack,
      'rule_id': ruleId,
      'target': target,
      'errors': [for (final e in result.errors) e.toJson()],
      'report': result.report,
    };

/// Heals one file with a fast-path recipe. Returns 0 when healed (or
/// already green), 1 on rollback, 2 on bad arguments or rules.
int heal(List<String> args) {
  final parser = ArgParser()
    ..addOption('rule', help: 'Rule id to heal (fast-path only).')
    ..addOption('attempts',
        defaultsTo: '$_defaultAttempts', help: 'Attempt cap, 1..10.')
    ..addFlag('json', negatable: false, help: 'Report the outcome as JSON.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  late final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_healUsage);
    return 2;
  }
  if (parsed['help'] as bool) {
    stdout.writeln(_healUsage);
    stdout.writeln(parser.usage);
    return 0;
  }
  if (parsed.rest.length != 1) {
    stderr.writeln(_healUsage);
    return 2;
  }
  final target = parsed.rest.single;
  if (FileSystemEntity.typeSync(target) != FileSystemEntityType.file) {
    stderr.writeln('No such file: $target');
    return 2;
  }
  if (!target.endsWith('.dart')) {
    stderr.writeln('heal takes one .dart file, got: $target');
    return 2;
  }
  final attempts = int.tryParse(parsed['attempts'] as String);
  if (attempts == null || attempts < 1 || attempts > _maxAttempts) {
    stderr.writeln('--attempts must be 1..$_maxAttempts');
    return 2;
  }
  final byId = {for (final rule in ruleAnalyzers) rule.id: rule};
  final ruleId = parsed['rule'] as String?;
  if (ruleId == null) return _guide(target, byId);
  final analyzer = byId[ruleId];
  if (analyzer == null) {
    stderr.writeln('unknown rule: $ruleId '
        '(mechanical: ${fastPathRecipes.keys.join(', ')})');
    return 2;
  }
  final recipe = healRecipeFor(ruleId);
  if (recipe == null) {
    stderr.writeln('no fast-path recipe for $ruleId (agent-dispatched); '
        'canonical recipe: ${analyzer.spec} (§2)');
    return 2;
  }
  List<RuleViolation>? before;
  try {
    before = analyzer.analyze(target);
  } catch (_) {
    // Unanalyzable: let the dispatcher record the detect crash
    // (rollback + report) instead of guessing here.
    before = null;
  }
  final asJson = parsed['json'] as bool;
  if (before != null && before.isEmpty) {
    if (asJson) {
      stdout.writeln(jsonEncode(healResultJson(
          target: target,
          ruleId: ruleId,
          result: const HealResult(
              success: true,
              attempts: 1,
              rolledBack: false,
              errors: [],
              report: ''))));
    } else {
      stdout.writeln('clean: $target (no $ruleId violations; no writes)');
    }
    return 0;
  }
  final result = HealDispatcher(maxAttempts: attempts).healFile(
    path: target,
    recipe: recipe,
    analyze: analyzer.analyze,
  );
  if (asJson) {
    stdout.writeln(jsonEncode(
        healResultJson(target: target, ruleId: ruleId, result: result)));
  } else if (result.success) {
    stdout.writeln('healed: $target ($ruleId, ${result.attempts} attempt(s))');
  } else {
    stdout.writeln('rolled back: $target ($ruleId, '
        '${result.attempts}/$attempts attempts; '
        'report: $target.heal-report.md)');
    for (final error in result.errors) {
      stdout
          .writeln('  attempt ${error.attempt} ${error.phase}: ${error.error}');
    }
  }
  return result.success ? 0 : 1;
}

/// Guided exit when `--rule` is missing: lists the target's mechanical
/// violations (exit 2), or reports clean (exit 0) when none exist.
int _guide(String target, Map<String, RuleAnalyzer> byId) {
  final lines = <String>[];
  for (final id in fastPathRecipes.keys) {
    final analyzer = byId[id];
    if (analyzer == null) {
      throw StateError('no analyzer for fast-path rule $id');
    }
    try {
      for (final violation in analyzer.analyze(target)) {
        lines.add('  $id line ${violation.line}: ${violation.message}');
      }
    } catch (error) {
      stderr.writeln('error: $target: $error');
      return 1;
    }
  }
  if (lines.isEmpty) {
    stdout.writeln('clean: $target (no mechanical violations; no writes)');
    return 0;
  }
  stderr.writeln('mechanical violations in $target:');
  for (final line in lines) {
    stderr.writeln(line);
  }
  stderr.writeln('re-run with --rule <RULE-ID>');
  return 2;
}
