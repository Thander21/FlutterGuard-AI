// FlutterGuard MCP server entry point (SYS-MCP-001).
//
// Usage: run over stdio from an MCP client (Cursor, Claude Code,
// Gemini CLI, Antigravity) after `dart pub global activate` exposes
// the `flutterguard_mcp` executable:
//
//   flutterguard_mcp
//
// Reads one JSON-RPC message per stdin line, writes one response line
// per request to stdout. stdout carries protocol bytes only; crashes
// go to stderr. stdin close = clean exit 0.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> main() async {
  final requests =
      stdin.transform(utf8.decoder).transform(const LineSplitter());
  final responses = StreamController<String>();
  responses.stream.listen(stdout.writeln);
  final channel = StreamChannel<String>(requests, responses.sink);
  final server = createMcpServer(channel);
  try {
    await server.listen();
  } catch (error) {
    stderr.writeln('flutterguard_mcp: $error');
    exit(1);
  } finally {
    await responses.close();
  }
}
