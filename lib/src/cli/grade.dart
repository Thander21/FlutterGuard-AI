// Golden-eval runner (SYS-CLI-001a; moved from `bin/` by SYS-REL-001 R3).
//
// Scans `specs/*.md`, runs the registered rule visitor over each golden
// vector pair, and appends the gate results to `evidence.jsonl`. It exits
// 0 only when every vector passes its eval.
import 'dart:convert';
import 'dart:io';

import '../ast/rule_violation.dart';
import '../util.dart';
import 'rules.dart';

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

/// Runs golden evals over `<root>/specs` and appends the results to
/// `<root>/evidence.jsonl`. [root] exists so tests can grade a fixture;
/// the CLI always grades the current directory. A malformed spec or a
/// missing visitor fails the run but never aborts it: every other spec is
/// still graded.
int grade({String root = '.'}) {
  final specsDir = Directory(joinRoot(root, 'specs'));
  if (!specsDir.existsSync()) {
    stderr.writeln('No specs found in specs/.');
    return 1;
  }
  final specs = <_Spec>[];
  var specErrors = 0;
  for (final entity in specsDir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    if (entity.path.endsWith('_template.md')) continue;
    _Spec spec;
    try {
      spec = _readSpec(entity);
    } catch (error) {
      stderr.writeln('error: ${entity.path}: $error');
      specErrors++;
      continue;
    }
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
      stderr.writeln('error: no visitor registered for ${spec.id}.');
      specErrors++;
      continue;
    }
    failures += _gradeVector(
      lines,
      spec.id,
      analyzer,
      joinRoot(root, spec.failing),
      expectFlagged: true,
    );
    failures += _gradeVector(
      lines,
      spec.id,
      analyzer,
      joinRoot(root, spec.passing),
      expectFlagged: false,
    );
  }
  File(joinRoot(root, 'evidence.jsonl'))
      .writeAsStringSync('${lines.join('\n')}\n', mode: FileMode.append);

  if (failures == 0 && specErrors == 0) {
    stdout.writeln('All golden evals passed.');
  } else {
    stdout.writeln(
      '$failures golden eval(s) failed, $specErrors spec error(s).',
    );
  }
  return failures == 0 && specErrors == 0 ? 0 : 1;
}

/// Grades one vector: a `.bad` file passes only when flagged, a `.good`
/// file passes only when clean. Returns 1 on eval failure, else 0.
/// An analyzer crash fails the eval but never kills the run.
int _gradeVector(
  List<String> lines,
  String ruleId,
  List<RuleViolation> Function(String path) analyzer,
  String file, {
  required bool expectFlagged,
}) {
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
  lines.add(
    jsonEncode({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'phase': 'DETERMINISTIC_GATE',
      'rule_id': ruleId,
      'file': file,
      'status': gateStatus,
      'error_message': flagged ? violations.first.message : '',
      'recipe_injected': '',
      'iteration': 1,
      'action': 'EVAL_RECORDED',
    }),
  );
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
    final match = RegExp(r'^\s*(\w+):\s*"?([^"]+)"?\s*$').firstMatch(line);
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
  return _Spec(
    id: id,
    failing: failing,
    passing: passing,
    kind: kind ?? 'rule',
  );
}
