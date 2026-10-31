// FlutterGuard CLI entry point.
//
// Usage (from the repository root, after `dart pub get`):
//   dart run bin/flutterguard.dart grade
//   dart run bin/flutterguard.dart check <path> [--json]
//
// `grade` scans specs/*.md, runs the registered rule visitor over each
// golden vector pair, and appends the gate results to evidence.jsonl. It
// exits 0 only when every vector passes its eval.
//
// `check` runs every registered visitor over a target .dart file or
// directory (recursive) and reports violations as text or JSON. It exits
// 1 when any violation is found, 0 when clean.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';

/// Explicit [exit] (instead of returning the code from `main`) so the
/// process exit code propagates through `dart` batch-file launchers that
/// swallow a returned code.
void main(List<String> args) {
  exit(_run(args));
}

int _run(List<String> args) {
  if (args.length == 1 && args.first == 'grade') {
    return grade();
  }
  if (args.isNotEmpty && args.first == 'check') {
    return check(args.sublist(1));
  }
  stderr.writeln('Usage: dart run bin/flutterguard.dart <grade|check>');
  stderr.writeln('  grade                 Run golden evals, append evidence.jsonl.');
  stderr.writeln('  check <path> [--json] Audit a .dart file or directory.');
  return 2;
}

/// Minimal OpenSpec front-matter needed by the grader.
class _Spec {
  const _Spec({
    required this.id,
    required this.failing,
    required this.passing,
    this.kind = 'rule',
  });

  final String id;
  final String failing;
  final String passing;
  final String kind;
}

/// Audits [target] with every registered visitor. Returns 1 when any
/// violation is found, 0 when clean, 2 on bad arguments.
int check(List<String> args) {
  final asJson = args.contains('--json');
  final targets = args.where((a) => a != '--json').toList();
  if (targets.length != 1) {
    stderr.writeln('Usage: dart run bin/flutterguard.dart check <path> [--json]');
    return 2;
  }
  late final CheckResult result;
  try {
    result = checkPath(targets.single);
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
      stdout.writeln(
          '${finding.ruleId} ${finding.file}:${finding.line} ${finding.message}');
    }
    stdout.writeln(
        '${result.findings.length} violation(s) in ${targets.single}.');
  }
  return result.findings.isEmpty ? 0 : 1;
}

int grade() {
  final specsDir = Directory('specs');
  if (!specsDir.existsSync()) {
    stderr.writeln('No specs found in specs/.');
    return 1;
  }
  final specs = <_Spec>[];
  for (final entity in specsDir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    if (entity.path.endsWith('_template.md')) continue;
    final spec = _readSpec(entity);
    if (spec.kind == 'system') continue; // interface contracts, not evals
    specs.add(spec);
  }
  specs.sort((a, b) => a.id.compareTo(b.id));
  if (specs.isEmpty) {
    stderr.writeln('No rule specs found in specs/.');
    return 1;
  }

  final analyzers = {for (final rule in ruleAnalyzers) rule.id: rule.analyze};
  final lines = <String>[];
  var failures = 0;
  for (final spec in specs) {
    final analyzer = analyzers[spec.id];
    if (analyzer == null) {
      stderr.writeln('No visitor registered for ${spec.id}.');
      return 1;
    }
    failures += _gradeVector(
        lines, spec.id, analyzer, spec.failing, expectFlagged: true);
    failures += _gradeVector(
        lines, spec.id, analyzer, spec.passing, expectFlagged: false);
  }
  File('evidence.jsonl')
      .writeAsStringSync('${lines.join('\n')}\n', mode: FileMode.append);

  if (failures == 0) {
    stdout.writeln('All golden evals passed.');
  } else {
    stdout.writeln('$failures golden eval(s) failed.');
  }
  return failures == 0 ? 0 : 1;
}

/// Grades one vector: a `.bad` file passes only when flagged, a `.good`
/// file passes only when clean. Returns 1 on eval failure, else 0.
/// An analyzer crash fails the eval but never kills the run.
int _gradeVector(List<String> lines, String ruleId,
    List<RuleViolation> Function(String path) analyzer, String file,
    {required bool expectFlagged}) {
  List<RuleViolation> violations;
  try {
    violations = analyzer(file);
  } catch (error) {
    stderr.writeln('error: $file: $error');
    violations = const [_CrashedViolation._()];
  }
  final flagged = violations.isNotEmpty;
  final gateStatus = flagged ? 'FAILED' : 'PASSED';
  final passed = flagged == expectFlagged;
  lines.add(jsonEncode({
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'phase': 'DETERMINISTIC_GATE',
    'rule_id': ruleId,
    'file': file,
    'status': gateStatus,
    'error_message': flagged ? violations.first.message : '',
    'recipe_injected': '',
    'iteration': 1,
    'action': 'EVAL_RECORDED',
  }));
  stdout.writeln('${passed ? 'PASS' : 'FAIL'} $file (gate: $gateStatus)');
  return passed ? 0 : 1;
}

/// Placeholder violation that fails the eval when a visitor crashes.
class _CrashedViolation implements RuleViolation {
  const _CrashedViolation._();

  @override
  int get line => 0;

  @override
  String get message => 'analyzer crashed on this file';
}

/// Reads `id`, `kind`, `golden_vectors.failing`, and
/// `golden_vectors.passing` from a spec's YAML front matter (minimal line
/// parser, no yaml dependency).
_Spec _readSpec(File file) {
  final lines = file.readAsLinesSync();
  String? id, failing, passing, kind;
  var inMatter = false;
  for (final line in lines) {
    if (line.trim() == '---') {
      if (inMatter) break;
      inMatter = true;
      continue;
    }
    if (!inMatter) continue;
    final match =
        RegExp(r'^\s*(\w+):\s*"?([^"]+)"?\s*$').firstMatch(line);
    if (match == null) continue;
    switch (match.group(1)) {
      case 'id':
        id = match.group(2);
      case 'kind':
        kind = match.group(2);
      case 'failing':
        failing = match.group(2);
      case 'passing':
        passing = match.group(2);
    }
  }
  if (id == null || failing == null || passing == null) {
    throw StateError('Incomplete front matter in ${file.path}.');
  }
  return _Spec(id: id, failing: failing, passing: passing, kind: kind ?? 'rule');
}
