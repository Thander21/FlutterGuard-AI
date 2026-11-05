// SYS-MCP-001: JSON-RPC method table for the MCP server.
//
// stdio-agnostic: the table runs over any `StreamChannel<String>` (the
// real server wires stdin/stdout; tests drive a memory channel).
import 'dart:convert';

import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:stream_channel/stream_channel.dart';

import 'tools.dart';

/// Server version, mirrored from `pubspec.yaml` (the mcp test enforces
/// equality — a global install cannot see the checkout's pubspec, so
/// runtime reads are out).
const mcpServerVersion = '0.1.0';

/// MCP protocol version echoed when the client omits it.
const mcpProtocolVersion = '2024-11-05';

/// Creates the MCP method table over [channel] (SYS-MCP-001 §2).
Server createMcpServer(StreamChannel<String> channel) {
  final server = Server(channel);
  server.registerMethod('initialize', (Parameters params) {
    final requested = params.asMap['protocolVersion'];
    return {
      'protocolVersion': requested is String ? requested : mcpProtocolVersion,
      'capabilities': {'tools': <String, Object?>{}},
      'serverInfo': {'name': 'flutterguard', 'version': mcpServerVersion},
    };
  });
  server.registerMethod('notifications/initialized', (_) {});
  server.registerMethod(
    'tools/list',
    (_) => {
      'tools': [for (final t in mcpToolDefs) t.toJson()],
    },
  );
  server.registerMethod('tools/call', (Parameters params) async {
    final map = params.asMap;
    final name = map['name'];
    if (name is! String || name.isEmpty) {
      throw RpcException.invalidParams(
        'tools/call needs "name: string" (non-empty).',
      );
    }
    final raw = map['arguments'];
    final args = <String, Object?>{};
    if (raw != null) {
      if (raw is! Map) {
        throw RpcException.invalidParams(
          'tools/call "arguments" must be an object.',
        );
      }
      raw.forEach((key, value) => args['$key'] = value);
    }
    try {
      final result = await callTool(name, args);
      return {
        'content': [
          {'type': 'text', 'text': jsonEncode(result)},
        ],
      };
    } on McpError catch (error) {
      throw RpcException(error.code, error.message);
    } catch (error) {
      throw RpcException(-32603, 'Internal error in "$name": $error');
    }
  });
  return server;
}
