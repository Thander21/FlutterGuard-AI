// FlutterGuard agent-loop hook (SYS-MCP-002 §2). Standalone: runs via
// `dart <this file>` with zero package context, so it imports only
// `dart:` libraries. Reads one hook event JSON from stdin.
//
// Modes: `--presence` (PreToolUse: CLI-on-PATH gate only) and default
// (PostToolUse: full `check` on the edited file). Exit 0 allows (or
// stays silent for non-Dart paths); exit 2 blocks (PreToolUse) or
// feeds findings back to the agent (PostToolUse).
import 'dart:convert';
import 'dart:io';

/// Governed CLI entry (global exe from the `executables` stanza).
const _cli = 'flutterguard';

/// Printed when the CLI is missing: fail with the fix, never silent.
const _installHint =
    'FlutterGuard CLI not found on PATH. Install it:\n'
    '  dart pub global activate --source git '
    'https://github.com/Thander21/FlutterGuard-AI.git\n'
    'then re-run the edit.';

Future<void> main(List<String> args) async {
  final presenceOnly = args.contains('--presence');
  final path = _editedFile(await stdin.transform(utf8.decoder).join());
  if (path == null || !path.endsWith('.dart')) exit(0);
  final cli = _resolveOnPath(_cli);
  if (cli == null) {
    stderr.writeln(_installHint);
    exit(2);
  }
  if (presenceOnly) exit(0);
  if (!File(path).existsSync()) exit(0); // Concurrent delete: §5.
  late final ProcessResult run;
  try {
    run = await Process.run(cli, ['check', '--json', path]);
  } catch (error) {
    stderr.writeln('FlutterGuard: could not run $cli: $error');
    exit(2);
  }
  if (run.exitCode == 0) exit(0);
  stderr.writeln(_report(path, run.stdout.toString()));
  exit(2);
}

/// Extracts the edited file from a hook event, or null when the event
/// carries none (foreign shape → stay silent, exit 0 upstream).
String? _editedFile(String input) {
  try {
    final event = jsonDecode(input);
    if (event is! Map) return null;
    final toolInput = event['tool_input'];
    if (toolInput is! Map) return null;
    final path = toolInput['file_path'];
    return path is String ? path : null;
  } on FormatException {
    return null;
  }
}

/// Resolves [name] to an executable path with extension, or null.
/// Mirrors `resolvesOnPath` (`lib/src/util.dart`): this script is
/// standalone (no `package:` imports), so the scan is ported, not
/// imported. Returns the path (not a bool) so the spawn below never
/// re-resolves: on Windows the global exe is a `.bat` shim, which only
/// spawns with its extension attached.
String? _resolveOnPath(String name) {
  final path = Platform.environment['PATH'] ?? '';
  if (path.isEmpty) return null;
  final separator = Platform.isWindows ? ';' : ':';
  final suffixes = Platform.isWindows
      ? const ['', '.exe', '.bat', '.cmd']
      : const [''];
  for (final entry in path.split(separator)) {
    final dir = entry.trim();
    if (dir.isEmpty) continue;
    for (final extension in suffixes) {
      final candidate = '$dir/$name$extension';
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return null;
}

/// Renders a `check --json` payload as agent feedback: one line per
/// finding plus its recipe pointer, analyzer errors included. Falls
/// back to raw output when the payload does not parse.
String _report(String path, String checkJson) {
  final buffer = StringBuffer('FlutterGuard: violations in $path\n');
  var detailed = false;
  try {
    final decoded = jsonDecode(checkJson);
    if (decoded is Map) {
      for (final entry in _rows(decoded['findings'])) {
        buffer.writeln(
          '- ${entry['rule_id']} ${entry['file']}:'
          '${entry['line']}: ${entry['message']} '
          '[${entry['severity']}]',
        );
        buffer.writeln("  fix: ${entry['recipe']}");
        detailed = true;
      }
      for (final entry in _rows(decoded['errors'])) {
        buffer.writeln("- analyzer error ${entry['file']}: ${entry['error']}");
        detailed = true;
      }
    }
  } on FormatException {
    detailed = false;
  }
  if (!detailed) buffer.writeln(checkJson.trim());
  buffer.writeln(
    'Fix the findings above, then continue. '
    'Do not finish with error-severity findings open.',
  );
  return buffer.toString();
}

/// Map rows of a decoded JSON array (foreign shapes yield none).
Iterable<Map> _rows(Object? value) =>
    value is List ? value.whereType<Map>() : const [];
