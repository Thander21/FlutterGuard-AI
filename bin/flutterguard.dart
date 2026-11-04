// FlutterGuard CLI entry point.
//
// Usage (from the repository root, after `dart pub get`):
//   dart run bin/flutterguard.dart grade
//   dart run bin/flutterguard.dart check <path> [--json] [--help]
//   dart run bin/flutterguard.dart init [--scaffold] [--agents] [--help]
//   dart run bin/flutterguard.dart sandbox <load|reset|check>
//
// `grade` scans specs/*.md, runs the registered rule visitor over each
// golden vector pair, and appends the gate results to evidence.jsonl. It
// exits 0 only when every vector passes its eval.
//
// `check` runs every registered visitor over a target .dart file or
// directory (recursive) and reports violations as text or JSON. It exits
// 1 when any violation is found, 0 when clean.
//
// `init` installs the pre-commit hook (runs `check`), writes
// flutterguard.yaml, and prints the agent mandate. `sandbox` manages the
// volatile agent playground under fixtures/sandbox/.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
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
  if (args.isNotEmpty && args.first == 'init') {
    return init(args.sublist(1));
  }
  if (args.isNotEmpty && args.first == 'sandbox') {
    return sandbox(args.sublist(1));
  }
  stderr.writeln(
      'Usage: dart run bin/flutterguard.dart <grade|check|init|sandbox>');
  stderr.writeln('  grade                 Run golden evals, append evidence.jsonl.');
  stderr.writeln(
      '  check <path> [--json] [--help] Audit a .dart file or directory.');
  stderr.writeln('  init [--scaffold] [--agents] [--help] Init a project.');
  stderr.writeln('  sandbox <load|reset|check> Manage the agent playground.');
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

/// CLI usage for `check` (SYS-CLI-001a).
const _checkUsage =
    'Usage: dart run bin/flutterguard.dart check <path> [--json] [--help]';

/// Audits one target with every registered visitor. Returns 1 when any
/// error-severity violation is found, 0 when clean or warnings-only,
/// 2 on bad arguments.
int check(List<String> args) {
  final parser = ArgParser()
    ..addFlag('json', negatable: false, help: 'Report findings as JSON.')
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
      final prefix = finding.severity == 'warning' ? 'warning: ' : '';
      stdout.writeln(
          '$prefix${finding.ruleId} ${finding.file}:${finding.line} ${finding.message}');
    }
    stdout.writeln(
        '${result.findings.length} violation(s) in ${targets.single}.');
  }
  return result.findings.any((f) => f.severity == 'error') ? 1 : 0;
}

/// Runs golden evals over `<root>/specs` and appends the results to
/// `<root>/evidence.jsonl`. [root] exists so tests can grade a fixture;
/// the CLI always grades the current directory. A malformed spec or a
/// missing visitor fails the run but never aborts it: every other spec is
/// still graded.
int grade({String root = '.'}) {
  final specsDir = Directory(_join(root, 'specs'));
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
    failures += _gradeVector(lines, spec.id, analyzer,
        _join(root, spec.failing), expectFlagged: true);
    failures += _gradeVector(lines, spec.id, analyzer,
        _join(root, spec.passing), expectFlagged: false);
  }
  File(_join(root, 'evidence.jsonl'))
      .writeAsStringSync('${lines.join('\n')}\n', mode: FileMode.append);

  if (failures == 0 && specErrors == 0) {
    stdout.writeln('All golden evals passed.');
  } else {
    stdout.writeln(
        '$failures golden eval(s) failed, $specErrors spec error(s).');
  }
  return failures == 0 && specErrors == 0 ? 0 : 1;
}

/// Joins [root] with a repo-relative [path], leaving CLI behavior and
/// output byte-identical when [root] is the default '.'.
String _join(String root, String path) => root == '.' ? path : '$root/$path';

/// `flutterguard.yaml` schema v1 (SYS-CLI-001b §2). Written once, never
/// overwritten.
const _flutterguardYaml = '''# FlutterGuard configuration (SYS-CLI-001b). Schema v1: version + gate
# toggles. Toggles are declared here; enforcement lands with the gate
# runner — unknown keys are ignored for forward compatibility.
version: 1
gates:
  validate-light: true
  test: true
  validate: true
  commit-check: true
''';

/// Marker guarding the generated pre-commit hook (SYS-CLI-001b).
const _hookMarker = '# FlutterGuard pre-commit hook (SYS-CLI-001b)';

const _hookScript = '''#!/bin/sh
$_hookMarker: blocks commits with violations.
# Override the CLI checkout for tests and custom installs:
# FLUTTERGUARD_ROOT="/path/to/flutterguard-ai" (quoted: spaces safe).
if [ -n "\$FLUTTERGUARD_ROOT" ]; then
  exec dart run "\$FLUTTERGUARD_ROOT/bin/flutterguard.dart" check .
elif command -v flutterguard >/dev/null 2>&1; then
  exec flutterguard check .
else
  exec dart run bin/flutterguard.dart check .
fi
''';

/// Marker guarding the injected agent mandate (Architecture §3.1).
const _agentsMarker = '<!-- FLUTTERGUARD MCP HARNESS CONTRACT -->';

const _agentsMandate = '''$_agentsMarker
## FlutterGuard engineering contract
1. After editing Dart/Flutter code, run the static gate (`check`); never ignore findings.
2. If the gate fails, apply the spec §2 canonical recipe for the flagged rule id.
3. No task is done while `check` reports violations.
''';

/// CLI usage for `init` (SYS-CLI-001b, SYS-MCP-001).
const _initUsage = '''
Usage: dart run bin/flutterguard.dart init [--scaffold] [--agents] [--mcp] [--help]
  Installs the pre-commit hook (runs check), writes flutterguard.yaml,
  and prints the agent mandate. --scaffold also creates .flutterguard/;
  --agents also appends the mandate to AGENTS.md;
  --mcp also registers the flutterguard MCP server in IDE clients.''';

/// Initializes [root] for FlutterGuard. Returns 0 when every applicable
/// step lands, 1 when a step fails, 2 on bad arguments.
int init(List<String> args, {String root = '.'}) {
  final parser = ArgParser()
    ..addFlag('scaffold', negatable: false, help: 'Create .flutterguard/.')
    ..addFlag('agents',
        negatable: false, help: 'Append the mandate to AGENTS.md.')
    ..addFlag('mcp',
        negatable: false, help: 'Register the MCP server in IDE clients.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  late final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_initUsage);
    return 2;
  }
  if (parsed['help'] as bool) {
    stdout.writeln(_initUsage);
    return 0;
  }
  if (parsed.rest.isNotEmpty) {
    stderr.writeln(_initUsage);
    return 2;
  }
  var failed = false;
  final yaml = File(_join(root, 'flutterguard.yaml'));
  if (yaml.existsSync()) {
    stdout.writeln('exists: ${yaml.path} (left untouched)');
  } else {
    yaml.writeAsStringSync(_flutterguardYaml);
    stdout.writeln('wrote: ${yaml.path}');
  }
  final hooksDir = Directory(_join(root, '.git/hooks'));
  final hook = File(_join(root, '.git/hooks/pre-commit'));
  if (!hooksDir.existsSync()) {
    stderr.writeln('error: no .git/hooks under $root — hook skipped');
    failed = true;
  } else if (hook.existsSync() &&
      !hook.readAsStringSync().contains(_hookMarker)) {
    stderr.writeln('error: ${hook.path} is foreign — refusing to overwrite');
    failed = true;
  } else {
    hook.writeAsStringSync(_hookScript);
    if (!Platform.isWindows) {
      try {
        Process.runSync('chmod', ['+x', hook.path]);
      } catch (error) {
        stderr.writeln('warning: chmod skipped: $error');
      }
    }
    stdout.writeln('wrote: ${hook.path}');
  }
  if (parsed['scaffold'] as bool) {
    Directory(_join(root, '.flutterguard')).createSync(recursive: true);
    stdout.writeln('scaffold: ${_join(root, '.flutterguard/')}');
  }
  if (parsed['agents'] as bool) {
    final agents = File(_join(root, 'AGENTS.md'));
    final prior = agents.existsSync() ? agents.readAsStringSync() : '';
    if (prior.contains(_agentsMarker)) {
      stdout.writeln('exists: ${agents.path} (mandate already present)');
    } else {
      agents.writeAsStringSync(
          prior.isEmpty ? _agentsMandate : '$prior\n$_agentsMandate');
      stdout.writeln('wrote: ${agents.path}');
    }
  } else {
    stdout.writeln(_agentsMandate);
  }
  if (parsed['mcp'] as bool) {
    final registration = writeMcpConfigs(root: root);
    for (final path in registration.wrote) {
      stdout.writeln('wrote: $path');
    }
    for (final error in registration.errors) {
      stderr.writeln('error: $error');
      failed = true;
    }
    if (!resolvesOnPath(mcpServerCommand)) {
      stdout.writeln('warning: $mcpServerCommand is not on PATH — '
          'registration lands once the package is installed '
          '(dart pub global activate).');
    }
    stdout.writeln('global-client snippet (manual install, never '
        'written outside the root):');
    stdout.writeln(mcpGlobalSnippet);
  }
  return failed ? 1 : 0;
}

/// CLI usage for `sandbox` (SYS-CLI-001b).
const _sandboxUsage = '''
Usage: dart run bin/flutterguard.dart sandbox <load|reset|check>
  load: copy golden .bad vectors into fixtures/sandbox/ (volatile).
  reset: wipe fixtures/sandbox/.
  check: run check over fixtures/sandbox/.''';

/// Manages the volatile agent playground (SYS-CLI-001b). Returns 0 on
/// success, 1 when the vectors source is missing, 2 on bad arguments.
/// `check` follows check() exit codes (1 = violations present, the
/// expected state right after load).
int sandbox(List<String> args, {String root = '.'}) {
  if (args.length != 1 ||
      !const {'load', 'reset', 'check'}.contains(args.first)) {
    stderr.writeln(_sandboxUsage);
    return 2;
  }
  final box = Directory(_join(root, 'fixtures/sandbox'));
  switch (args.first) {
    case 'reset':
      if (box.existsSync()) box.deleteSync(recursive: true);
      box.createSync(recursive: true);
      stdout.writeln('reset: ${box.path}');
      return 0;
    case 'load':
      final vectors = Directory(_join(root, 'benchmark/vectors'));
      if (!vectors.existsSync()) {
        stderr.writeln('error: no benchmark/vectors under $root');
        return 1;
      }
      if (box.existsSync()) box.deleteSync(recursive: true);
      box.createSync(recursive: true);
      var count = 0;
      for (final entity in vectors.listSync()) {
        if (entity is File && entity.path.endsWith('.bad.dart')) {
          final name = entity.uri.pathSegments.last;
          entity.copySync(_join(box.path, name));
          count++;
        }
      }
      stdout.writeln('loaded: $count vectors into ${box.path}');
      return 0;
    case 'check':
      return check([box.path]);
  }
  return 2; // Unreachable: args.first is one of load/reset/check.
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
