// SYS-MCP-001: typed tool implementations over the lib gate APIs.
//
// Pure dispatch input/output (JSON-encodable maps); no stdio. Failures
// are [McpError] with JSON-RPC codes; the server translates them into
// error responses.
import 'dart:convert';
import 'dart:io';

import '../cli/check.dart';
import '../mutation/runner.dart';
import '../viewport/lite.dart';
import 'recipes.dart';

/// A tool failure with its JSON-RPC error code (`-32601` unknown tool,
/// `-32602` caller error, `-32603` internal).
class McpError implements Exception {
  const McpError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'MCP $code: $message';
}

/// One tool's `tools/list` entry.
class McpToolDef {
  const McpToolDef({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;

  /// JSON Schema (object) for the tool's arguments.
  final Map<String, Object?> inputSchema;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}

/// The reconciled 5-tool surface (SYS-MCP-001 §2).
const mcpToolDefs = <McpToolDef>[
  McpToolDef(
    name: 'analyze_ast',
    description:
        'Run every FlutterGuard AST rule over a .dart file or '
        'directory (recursive). FAILED means a violation was caught.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Target .dart file or directory.',
        },
      },
      'required': ['path'],
    },
  ),
  McpToolDef(
    name: 'get_canonical_recipe',
    description:
        'Return the Before/After auto-heal recipe (§2) for a '
        'rule id (e.g. FG-BLOC-001). Apply it in one turn.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'rule_id': {
          'type': 'string',
          'description': 'Rule id from a finding (FG-XXX-NNN).',
        },
      },
      'required': ['rule_id'],
    },
  ),
  McpToolDef(
    name: 'verify_viewport',
    description:
        'Viewport gate v1 (Tier-1-lite AST vocabulary) over a '
        '.dart file or directory. Degraded stand-in: PASS never claims '
        'rendered-clean; see the note.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'path': {
          'type': 'string',
          'description': 'Target .dart file or directory.',
        },
      },
      'required': ['path'],
    },
  ),
  McpToolDef(
    name: 'run_mutation_check',
    description:
        'Judge a test file against surgical mutants of its '
        'source. passed=false means a complacent test survived. Writes '
        'volatile fixtures/mutation/ sandboxes under the server cwd.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'source_file': {
          'type': 'string',
          'description': 'Mutated source file.',
        },
        'test_file': {
          'type': 'string',
          'description': 'Test file relatively importing the source.',
        },
      },
      'required': ['source_file', 'test_file'],
    },
  ),
  McpToolDef(
    name: 'get_telemetry',
    description:
        'Read the newest evidence.jsonl lines under the server '
        'cwd, optionally filtered. A query, never a gate.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'rule_id': {'type': 'string', 'description': 'Keep only this rule id.'},
        'status': {
          'type': 'string',
          'description': 'Keep only this status (PASSED/FAILED).',
        },
        'limit': {
          'type': 'integer',
          'description': 'Newest lines to return (1-500, default 50).',
        },
      },
    },
  ),
];

/// Dispatches the tool [name] with [args]; throws [McpError] on any
/// tool-level failure.
Future<Map<String, Object?>> callTool(
  String name,
  Map<String, Object?> args,
) async {
  switch (name) {
    case 'analyze_ast':
      return _analyzeAst(args);
    case 'get_canonical_recipe':
      return _recipe(args);
    case 'verify_viewport':
      return _viewport(args);
    case 'run_mutation_check':
      return await _mutation(args);
    case 'get_telemetry':
      return _telemetry(args);
    default:
      throw McpError(-32601, 'Unknown tool "$name".');
  }
}

Map<String, Object?> _analyzeAst(Map<String, Object?> args) {
  final path = _stringArg(args, 'analyze_ast', 'path');
  late final CheckResult result;
  try {
    result = checkPath(path);
  } on ArgumentError catch (error) {
    throw McpError(-32602, '$error');
  }
  return {
    'status': result.findings.any((f) => f.severity == 'error')
        ? 'FAILED'
        : 'PASSED',
    'findings': [for (final f in result.findings) f.toJson()],
    'errors': [for (final e in result.errors) e.toJson()],
  };
}

Map<String, Object?> _recipe(Map<String, Object?> args) {
  final id = _stringArg(args, 'get_canonical_recipe', 'rule_id');
  final recipe = canonicalRecipes[id];
  if (recipe == null) {
    throw McpError(
      -32602,
      'Unknown rule_id "$id". Known: ${canonicalRecipes.keys.join(', ')}.',
    );
  }
  return {
    'rule_id': id,
    'spec': canonicalRecipeSpecs[id],
    'recipe_markdown': recipe,
  };
}

Map<String, Object?> _viewport(Map<String, Object?> args) {
  final path = _stringArg(args, 'verify_viewport', 'path');
  late final Tier1LiteResult result;
  try {
    result = runTier1Lite(path);
  } on ArgumentError catch (error) {
    throw McpError(-32602, '$error');
  } on StateError catch (error) {
    throw McpError(-32603, 'Lite vocabulary unwired: $error');
  }
  return {
    'status': result.findings.any((f) => f.severity == 'error')
        ? 'FAILED'
        : 'PASSED',
    'findings': [for (final f in result.findings) f.toJson()],
    'errors': [for (final e in result.errors) e.toJson()],
    'files_scanned': result.filesScanned,
    'sdk_available': result.sdkAvailable,
    'note': result.note,
  };
}

Future<Map<String, Object?>> _mutation(Map<String, Object?> args) async {
  final source = _stringArg(args, 'run_mutation_check', 'source_file');
  final test = _stringArg(args, 'run_mutation_check', 'test_file');
  late final MutationVerdict verdict;
  try {
    verdict = await MutationRunner().run(sourcePath: source, testPath: test);
  } on ArgumentError catch (error) {
    throw McpError(-32602, '$error');
  } on StateError catch (error) {
    throw McpError(-32602, '$error');
  }
  return {
    'passed': verdict.passed,
    'results': [
      for (final r in verdict.results)
        {
          'line': r.mutant.line,
          'original': r.mutant.original,
          'replacement': r.mutant.replacement,
          'status': r.status.name,
          'exit_code': r.exitCode,
        },
    ],
  };
}

Map<String, Object?> _telemetry(Map<String, Object?> args) {
  final ruleId = _optionalString(args, 'rule_id', 'get_telemetry');
  final status = _optionalString(args, 'status', 'get_telemetry');
  final limit = _limit(args);
  // Explicit Directory.current (not a bare relative path): bare paths
  // resolve against the process cwd, bypassing zone overrides in tests.
  final file = File('${Directory.current.path}/evidence.jsonl');
  if (!file.existsSync()) {
    return {
      'lines': const [],
      'count': 0,
      'note': 'no evidence.jsonl under ${Directory.current.path}',
    };
  }
  final matching = <Map<String, Object?>>[];
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue; // Tolerant read: writer bugs must not break audits.
    }
    if (decoded is! Map) continue;
    if (ruleId != null && decoded['rule_id'] != ruleId) continue;
    if (status != null && decoded['status'] != status) continue;
    matching.add({for (final e in decoded.entries) '${e.key}': e.value});
  }
  final tail = matching.length <= limit
      ? matching
      : matching.sublist(matching.length - limit);
  return {'lines': tail, 'count': matching.length};
}

/// Required non-empty string arg; `-32602` naming the culprit.
String _stringArg(Map<String, Object?> args, String tool, String key) {
  final value = args[key];
  if (value is! String || value.isEmpty) {
    throw McpError(-32602, '$tool needs "$key: string" (non-empty).');
  }
  return value;
}

/// Optional string arg; `-32602` on wrong type, null when absent.
String? _optionalString(Map<String, Object?> args, String key, String tool) {
  final value = args[key];
  if (value == null) return null;
  if (value is! String) {
    throw McpError(-32602, '$tool "$key" must be a string.');
  }
  return value;
}

/// `limit` in 1..500 (default 50); `-32602` otherwise.
int _limit(Map<String, Object?> args) {
  final value = args['limit'];
  if (value == null) return 50;
  if (value is! int || value <= 0 || value > 500) {
    throw McpError(-32602, 'get_telemetry "limit" must be an integer 1..500.');
  }
  return value;
}
