// SYS-MCP-001: `init --mcp` client registration (merge + writers).
//
// Root-scoped I/O only: the generic `mcp_config.json` always, plus
// `.cursor/mcp.json` when `.cursor/` exists. Global client configs
// (outside the root) are printed for manual install, never written.
import 'dart:convert';
import 'dart:io';

/// Server entry in client configs (global exe, PLAN-03 snippet).
const mcpServerCommand = 'flutterguard_mcp';

/// Key under `mcpServers`.
const mcpServerName = 'flutterguard';

/// Portable client-agnostic config, always written by `init --mcp`.
const mcpGenericConfig = 'mcp_config.json';

/// Cursor config, merged only when `.cursor/` exists.
const mcpCursorConfig = '.cursor/mcp.json';

/// Global-client snippet (Claude Code shape) printed for manual install.
const mcpGlobalSnippet = '''{
  "mcpServers": {
    "flutterguard": {
      "command": "flutterguard_mcp"
    }
  }
}''';

/// Outcome of [writeMcpConfigs]: written paths plus non-fatal errors.
class McpRegistration {
  const McpRegistration({required this.wrote, required this.errors});

  final List<String> wrote;
  final List<String> errors;
}

/// Merges the flutterguard server into existing client-config JSON
/// ([existing] null/blank → fresh config), preserving other servers.
///
/// Returns the rendered config. Throws [FormatException] on
/// unparseable input — the caller refuses the overwrite (fail-closed).
String mergeMcpConfig(String? existing) {
  Map<String, Object?> root;
  if (existing == null || existing.trim().isEmpty) {
    root = <String, Object?>{};
  } else {
    final parsed = jsonDecode(existing);
    if (parsed is! Map) {
      throw const FormatException('MCP config must be a JSON object');
    }
    root = <String, Object?>{};
    parsed.forEach((key, value) => root['$key'] = value);
  }
  final servers = <String, Object?>{};
  final prior = root['mcpServers'];
  if (prior is Map) prior.forEach((key, value) => servers['$key'] = value);
  servers[mcpServerName] = {'command': mcpServerCommand};
  root['mcpServers'] = servers;
  return '${const JsonEncoder.withIndent('  ').convert(root)}\n';
}

/// Writes the MCP registration under [root] (SYS-MCP-001 §2).
///
/// Never throws on config problems: failures collect into
/// [McpRegistration.errors] for the CLI to report.
McpRegistration writeMcpConfigs({required String root}) {
  final wrote = <String>[];
  final errors = <String>[];

  void writeOne(String relative) {
    final file = File('$root/$relative');
    String? existing;
    if (file.existsSync()) {
      try {
        existing = file.readAsStringSync();
      } catch (error) {
        errors.add('$relative: unreadable ($error)');
        return;
      }
    }
    late final String merged;
    try {
      merged = mergeMcpConfig(existing);
    } on FormatException catch (error) {
      errors.add('$relative: unparseable JSON, left untouched ($error)');
      return;
    }
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(merged);
      wrote.add('$root/$relative'.replaceAll(r'\', '/'));
    } catch (error) {
      errors.add('$relative: write failed ($error)');
    }
  }

  writeOne(mcpGenericConfig);
  if (Directory('$root/.cursor').existsSync()) writeOne(mcpCursorConfig);
  return McpRegistration(wrote: wrote, errors: errors);
}

/// True when [name] resolves on PATH. [pathEnv] injects a fake PATH
/// for tests; the ambient machine is never asserted on.
bool resolvesOnPath(String name, {String? pathEnv}) {
  final path = pathEnv ?? Platform.environment['PATH'] ?? '';
  if (path.isEmpty) return false;
  final separator = Platform.isWindows ? ';' : ':';
  final extensions =
      Platform.isWindows ? ['', '.exe', '.bat', '.cmd'] : [''];
  for (final entry in path.split(separator)) {
    final dir = entry.trim();
    if (dir.isEmpty) continue;
    for (final extension in extensions) {
      if (File('$dir/$name$extension').existsSync()) return true;
    }
  }
  return false;
}
