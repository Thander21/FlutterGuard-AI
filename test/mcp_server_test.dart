// SYS-MCP-001 contract test: per-tool dispatch (incl. every error
// code), embedded-recipes sync vs specs §2, client-config merge/write
// units, the method table over a memory channel, and one stdio smoke
// test spawning the real server against all 5 tools.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  group('callTool dispatch', () {
    test('analyze_ast flags .bad, spares .good', () async {
      final bad = await callTool(
          'analyze_ast', {'path': 'benchmark/vectors/TC-01_bloc.bad.dart'});
      expect(bad['status'], 'FAILED');
      expect((bad['findings'] as List), isNotEmpty);
      expect((bad['errors'] as List), isEmpty);

      final good = await callTool(
          'analyze_ast', {'path': 'benchmark/vectors/TC-01_bloc.good.dart'});
      expect(good['status'], 'PASSED');
      expect((good['findings'] as List), isEmpty);
    });

    test('analyze_ast rejects a missing path and bad args', () async {
      await expectLater(callTool('analyze_ast', {'path': 'nope.dart'}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
      await expectLater(callTool('analyze_ast', {}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
      await expectLater(callTool('analyze_ast', {'path': 42}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
    });

    test('get_canonical_recipe returns the §2 Before/After', () async {
      final result =
          await callTool('get_canonical_recipe', {'rule_id': 'FG-BLOC-001'});
      expect(result['rule_id'], 'FG-BLOC-001');
      expect(result['spec'], 'specs/TS-01-bloc-emit-guard.md');
      expect(result['recipe_markdown'], contains('if (isClosed) return;'));
      expect(result['recipe_markdown'], contains('```diff'));

      await expectLater(
          callTool('get_canonical_recipe', {'rule_id': 'FG-NOPE-000'}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
    });

    test('verify_viewport carries the degraded-mode note', () async {
      final bad = await callTool(
          'verify_viewport', {'path': 'benchmark/vectors/TC-07_lay.bad.dart'});
      expect(bad['status'], 'FAILED');
      expect(bad['files_scanned'], 1);
      expect(bad['sdk_available'], isA<bool>());
      expect(bad['note'], contains('Tier-1-lite'));

      final good = await callTool(
          'verify_viewport', {'path': 'benchmark/vectors/TC-07_lay.good.dart'});
      expect(good['status'], 'PASSED');
    });

    // No honest-pair subprocess here: the stdio smoke test below is the
    // subprocess proof for run_mutation_check. Nested `dart test`
    // processes contend on Windows (exit 255 under parallel load), so
    // each suite file spawns the minimum it must.
    test('run_mutation_check rejects caller errors', () async {
      await expectLater(
          callTool('run_mutation_check',
              {'source_file': 'nope.dart', 'test_file': 'nope_test.dart'}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
      await expectLater(
          callTool('run_mutation_check', {'source_file': 'a.dart'}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
    });

    test('get_telemetry filters, caps, and tolerates', () async {
      final dir = Directory.systemTemp.createTempSync('mcp_tele_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/evidence.jsonl').writeAsStringSync([
        '{"rule_id": "FG-BLOC-001", "status": "FAILED"}',
        'not json',
        '',
        '{"rule_id": "FG-RIV-001", "status": "PASSED"}',
        '{"rule_id": "FG-BLOC-001", "status": "PASSED"}',
      ].join('\n'));

      Future<Map<String, Object?>> run(Map<String, Object?> args) =>
          IOOverrides.runZoned(() => callTool('get_telemetry', args),
              getCurrentDirectory: () => dir);

      final all = await run({});
      expect(all['count'], 3);
      expect((all['lines'] as List), hasLength(3));

      final bloc = await run({'rule_id': 'FG-BLOC-001'});
      expect(bloc['count'], 2);

      final failed = await run({'status': 'FAILED'});
      expect(failed['count'], 1);

      final capped = await run({'limit': 2});
      expect(capped['count'], 3);
      expect((capped['lines'] as List), hasLength(2));

      await expectLater(
          IOOverrides.runZoned(() => callTool('get_telemetry', {'limit': 0}),
              getCurrentDirectory: () => dir),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
      await expectLater(
          IOOverrides.runZoned(() => callTool('get_telemetry', {'limit': 501}),
              getCurrentDirectory: () => dir),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32602)));
    });

    test('get_telemetry on a missing log is empty, never an error', () async {
      final dir = Directory.systemTemp.createTempSync('mcp_tele_empty_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final result = await IOOverrides.runZoned(
          () => callTool('get_telemetry', {}),
          getCurrentDirectory: () => dir);
      expect(result['lines'], isEmpty);
      expect(result['count'], 0);
      expect(result['note'], contains('no evidence.jsonl'));
    });

    test('unknown tool is -32601', () async {
      await expectLater(callTool('nope', {}),
          throwsA(isA<McpError>().having((e) => e.code, 'code', -32601)));
    });
  });

  group('embedded recipes sync', () {
    test('generator --check is green (specs §2 == embedded)', () async {
      final executable = Platform.resolvedExecutable.isNotEmpty
          ? Platform.resolvedExecutable
          : 'dart';
      final result =
          await Process.run(executable, ['tool/embed_recipes.dart', '--check']);
      expect(result.exitCode, 0,
          reason: 'run: dart tool/embed_recipes.dart\n${result.stderr}');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('keys match the registry, every recipe carries a diff', () {
      expect(canonicalRecipes.keys.toSet(),
          {for (final rule in ruleAnalyzers) rule.id});
      for (final entry in canonicalRecipes.entries) {
        expect(entry.value, contains('# 2. Canonical Auto-Heal Recipe'),
            reason: entry.key);
        expect(entry.value, contains('```diff'), reason: entry.key);
        expect(canonicalRecipeSpecs[entry.key], endsWith('.md'),
            reason: entry.key);
      }
    });

    test('server version mirrors pubspec', () {
      final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(File('pubspec.yaml').readAsStringSync());
      expect(match, isNotNull);
      expect(mcpServerVersion, match!.group(1));
    });
  });

  group('client config', () {
    test('merge writes fresh, preserves, refuses garbage', () {
      final fresh = jsonDecode(mergeMcpConfig(null)) as Map;
      expect(
          fresh['mcpServers']['flutterguard']['command'], 'flutterguard_mcp');

      final merged = jsonDecode(mergeMcpConfig(
          '{"mcpServers": {"other": {"command": "x"}}, "k": 1}')) as Map;
      expect(merged['k'], 1);
      expect(merged['mcpServers']['other'], {'command': 'x'});
      expect(
          merged['mcpServers']['flutterguard']['command'], 'flutterguard_mcp');

      expect(() => mergeMcpConfig('{nope'), throwsFormatException);
      expect(() => mergeMcpConfig('[1]'), throwsFormatException);
    });

    test('writer lands generic + cursor, fails closed per file', () {
      final root = Directory.systemTemp.createTempSync('mcp_cfg_');
      addTearDown(() => root.deleteSync(recursive: true));

      var reg = writeMcpConfigs(root: root.path);
      expect(reg.errors, isEmpty);
      expect(reg.wrote, hasLength(1));
      expect(File('${root.path}/mcp_config.json').existsSync(), isTrue);

      Directory('${root.path}/.cursor').createSync();
      reg = writeMcpConfigs(root: root.path);
      expect(reg.errors, isEmpty);
      expect(reg.wrote, hasLength(2));

      File('${root.path}/mcp_config.json').writeAsStringSync('{nope');
      reg = writeMcpConfigs(root: root.path);
      expect(reg.wrote, hasLength(1));
      expect(reg.errors, hasLength(1));
      expect(reg.errors.single, contains('mcp_config.json'));
      expect(File('${root.path}/mcp_config.json').readAsStringSync(), '{nope');
    });

    test('resolvesOnPath honors an injected PATH', () {
      final dir = Directory.systemTemp.createTempSync('mcp_path_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final name = Platform.isWindows ? 'fgmcp.exe' : 'fgmcp';
      File('${dir.path}/$name').writeAsStringSync('');
      final separator = Platform.isWindows ? ';' : ':';
      expect(
          resolvesOnPath('fgmcp', pathEnv: ' ${dir.path} $separator '), isTrue);
      expect(resolvesOnPath('fgmcp', pathEnv: dir.path + '_empty'), isFalse);
      expect(resolvesOnPath('fgmcp', pathEnv: ''), isFalse);
    });
  });

  group('method table over a memory channel', () {
    test('initialize, list, call, errors, notification', () async {
      final controller = StreamChannelController<String>();
      final server = createMcpServer(controller.foreign);
      unawaited(server.listen());
      final responses = <String, Map<String, Object?>>{};
      final subscription = controller.local.stream.listen((line) {
        final decoded = jsonDecode(line) as Map;
        responses['${decoded['id']}'] = {
          for (final e in decoded.entries) '${e.key}': e.value
        };
      });
      addTearDown(() async {
        await subscription.cancel();
        await controller.local.sink.close();
      });

      Future<Map<String, Object?>> request(int id, String method,
          [Object? params]) async {
        controller.local.sink.add(jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          if (params != null) 'params': params,
        }));
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (!responses.containsKey('$id')) {
          if (DateTime.now().isAfter(deadline)) {
            fail('no response for $method (#$id)');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        return responses['$id']!;
      }

      final hello = await request(
          1, 'initialize', {'protocolVersion': 'x', 'capabilities': {}});
      expect(_at(hello, 'result')['protocolVersion'], 'x');
      final serverInfo = _at(hello, 'result')['serverInfo'] as Map;
      expect(serverInfo['name'], 'flutterguard');
      expect(serverInfo['version'], mcpServerVersion);

      final list = await request(2, 'tools/list', {});
      final tools = _at(list, 'result')['tools'] as List;
      expect([
        for (final t in tools) t['name']
      ], [
        'analyze_ast',
        'get_canonical_recipe',
        'verify_viewport',
        'run_mutation_check',
        'get_telemetry',
      ]);
      for (final tool in tools) {
        expect(tool['inputSchema']['type'], 'object');
      }

      final call = await request(3, 'tools/call', {
        'name': 'get_canonical_recipe',
        'arguments': {'rule_id': 'FG-RIV-001'}
      });
      final text =
          (_at(call, 'result')['content'] as List).single['text'] as String;
      expect(jsonDecode(text)['rule_id'], 'FG-RIV-001');

      final badTool =
          await request(4, 'tools/call', {'name': 'nope', 'arguments': {}});
      expect(_at(badTool, 'error')['code'], -32601);

      final badParams = await request(5, 'tools/call', {
        'name': 'analyze_ast',
        'arguments': {'path': 'nope.dart'}
      });
      expect(_at(badParams, 'error')['code'], -32602);

      final badMethod = await request(6, 'nope/method', {});
      expect(_at(badMethod, 'error')['code'], -32601);

      controller.local.sink.add(jsonEncode(
          {'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(responses.containsKey('null'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('stdio smoke (real server, all 5 tools)', () {
    test('initialize, every tool, errors, clean exit', () async {
      final inputs = Directory.systemTemp.createTempSync('mcp_smoke_');
      final before = _sandboxNames();
      addTearDown(() {
        if (inputs.existsSync()) inputs.deleteSync(recursive: true);
        _deleteNewSandboxes(before);
      });
      final lib = Directory('${inputs.path}/lib')..createSync();
      final testDir = Directory('${inputs.path}/test')..createSync();
      final source = File('${lib.path}/target.dart')
        ..writeAsStringSync('bool isAboveZero(int n) => n > 0;\n');
      final testFile = File('${testDir.path}/target_test.dart')
        ..writeAsStringSync('''
import 'package:test/test.dart';
import '../lib/target.dart';
void main() {
  test('honest', () {
    expect(isAboveZero(1), isTrue);
    expect(isAboveZero(-1), isFalse);
  });
}
''');
      final executable = Platform.resolvedExecutable.isNotEmpty
          ? Platform.resolvedExecutable
          : 'dart';
      final server =
          await Process.start(executable, ['bin/flutterguard_mcp.dart']);
      final responses = <String, Map<String, Object?>>{};
      final lines =
          server.stdout.transform(utf8.decoder).transform(const LineSplitter());
      final subscription = lines.listen((line) {
        final decoded = jsonDecode(line) as Map;
        responses['${decoded['id']}'] = {
          for (final e in decoded.entries) '${e.key}': e.value
        };
      });

      Future<Map<String, Object?>> request(int id, String method,
          [Object? params]) async {
        server.stdin.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          if (params != null) 'params': params,
        }));
        final deadline = DateTime.now().add(const Duration(seconds: 120));
        while (!responses.containsKey('$id')) {
          if (DateTime.now().isAfter(deadline)) {
            fail('no response for $method (#$id)');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        return responses['$id']!;
      }

      String toolText(Map<String, Object?> response) =>
          ((response['result'] as Map)['content'] as List).single['text']
              as String;

      try {
        final hello = await request(
            1, 'initialize', {'protocolVersion': 'x', 'capabilities': {}});
        expect((_at(hello, 'result')['serverInfo'] as Map)['name'],
            'flutterguard');

        server.stdin.writeln(jsonEncode(
            {'jsonrpc': '2.0', 'method': 'notifications/initialized'}));

        final list = await request(2, 'tools/list', {});
        expect((_at(list, 'result')['tools'] as List), hasLength(5));

        final analyzed = await request(3, 'tools/call', {
          'name': 'analyze_ast',
          'arguments': {'path': 'benchmark/vectors/TC-02_riverpod.bad.dart'}
        });
        expect(jsonDecode(toolText(analyzed))['status'], 'FAILED');

        final recipe = await request(4, 'tools/call', {
          'name': 'get_canonical_recipe',
          'arguments': {'rule_id': 'FG-LIFE-001'}
        });
        expect(jsonDecode(toolText(recipe))['recipe_markdown'],
            contains('```diff'));

        final viewport = await request(5, 'tools/call', {
          'name': 'verify_viewport',
          'arguments': {'path': 'benchmark/vectors/TC-07_lay.good.dart'}
        });
        expect(jsonDecode(toolText(viewport))['status'], 'PASSED');

        final mutated = await request(6, 'tools/call', {
          'name': 'run_mutation_check',
          'arguments': {
            'source_file': source.path,
            'test_file': testFile.path,
          }
        });
        expect(jsonDecode(toolText(mutated))['passed'], isTrue);

        final tele = await request(7, 'tools/call', {
          'name': 'get_telemetry',
          'arguments': {'limit': 3}
        });
        final teleResult = jsonDecode(toolText(tele)) as Map;
        expect((teleResult['lines'] as List).length, lessThanOrEqualTo(3));

        final badTool =
            await request(8, 'tools/call', {'name': 'nope', 'arguments': {}});
        expect(_at(badTool, 'error')['code'], -32601);

        final badMethod = await request(9, 'nope', {});
        expect(_at(badMethod, 'error')['code'], -32601);
      } finally {
        await server.stdin.close();
        await subscription.cancel();
      }
      expect(await server.exitCode, 0);
    }, timeout: const Timeout(Duration(seconds: 300)));
  });
}

/// Nested map at [key] of a JSON-RPC [response] (test-only cast).
Map _at(Map<String, Object?> response, String key) => response[key] as Map;

/// Names under `fixtures/mutation/` (absent dir → empty).
Set<String> _sandboxNames() {
  final dir = Directory('fixtures/mutation');
  if (!dir.existsSync()) return const {};
  return {for (final e in dir.listSync()) e.path};
}

/// Deletes sandbox dirs that appeared after [before] was snapshotted.
void _deleteNewSandboxes(Set<String> before) {
  final dir = Directory('fixtures/mutation');
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync()) {
    if (!before.contains(entity.path) && entity is Directory) {
      entity.deleteSync(recursive: true);
    }
  }
}
