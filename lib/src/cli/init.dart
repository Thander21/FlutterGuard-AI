// Project onboarding: `init` installs the pre-commit hook (runs `check`),
// writes `flutterguard.yaml`, and prints the agent mandate
// (SYS-CLI-001b, SYS-MCP-001; moved from `bin/` by SYS-REL-001 R3).
import 'dart:io';

import 'package:args/args.dart';

import '../mcp/client_config.dart';
import '../util.dart';

/// `flutterguard.yaml` schema v1 (SYS-CLI-001b §2). Written once, never
/// overwritten.
const _flutterguardYaml =
    '''# FlutterGuard configuration (SYS-CLI-001b). Schema v1: version + gate
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
  final yaml = File(joinRoot(root, 'flutterguard.yaml'));
  if (yaml.existsSync()) {
    stdout.writeln('exists: ${yaml.path} (left untouched)');
  } else {
    yaml.writeAsStringSync(_flutterguardYaml);
    stdout.writeln('wrote: ${yaml.path}');
  }
  final hooksDir = Directory(joinRoot(root, '.git/hooks'));
  final hook = File(joinRoot(root, '.git/hooks/pre-commit'));
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
    Directory(joinRoot(root, '.flutterguard')).createSync(recursive: true);
    stdout.writeln('scaffold: ${joinRoot(root, '.flutterguard/')}');
  }
  if (parsed['agents'] as bool) {
    final agents = File(joinRoot(root, 'AGENTS.md'));
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
