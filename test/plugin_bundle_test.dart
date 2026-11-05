// Plugin bundle contract (SYS-MCP-002 §2/§3): marketplace + manifest +
// hooks + embedded skill + matrix docs. Hermetic: spawns `dart` and a
// stub CLI only — no global install, no network, no claude/muse CLIs.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Standalone hook script under test (zero package context at runtime).
const _hookScript = 'plugin/hooks/check_guard.dart';

/// Canned `check --json` payload served by the stub CLI in fail mode
/// (single line, `cmd`-safe: no `%`, no block-breaking parens).
const _stubPayload = '{"findings":[{"rule_id":"FG-ST-001",'
    '"spec":"specs/TS-08.md","recipe":"specs/TS-08.md #2",'
    '"file":"C:/stub/victim.dart","line":3,'
    '"message":"setState outside handler","severity":"error"}],'
    '"errors":[]}';

/// One hook run: exit code plus decoded stdio.
Future<({int exitCode, String stdout, String stderr})> _runHook(
  String stdinPayload, {
  List<String> args = const [],
  Map<String, String>? environment,
}) async {
  final process = await Process.start('dart', [_hookScript, ...args],
      environment: environment);
  process.stdin.write(stdinPayload);
  await process.stdin.close();
  final out = process.stdout.transform(utf8.decoder).join();
  final err = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode;
  return (exitCode: code, stdout: await out, stderr: await err);
}

/// Minimal hook event for an edit of [path].
String _event(String path) => jsonEncode({
      'hook_event_name': 'PostToolUse',
      'tool_name': 'Edit',
      'tool_input': {'file_path': path},
    });

/// Writes a stub `flutterguard` into [dir] (shell on POSIX, `.bat` on
/// Windows). `FG_STUB=fail` prints canned violations + exit 1, any
/// other value exits 0. Returns [dir] for PATH wiring.
String _writeStub(Directory dir) {
  if (Platform.isWindows) {
    File('${dir.path}/flutterguard.bat').writeAsStringSync('@echo off\r\n'
        'if not "%FG_STUB%"=="fail" exit /b 0\r\n'
        'echo $_stubPayload\r\n'
        'exit /b 1\r\n');
    return dir.path;
  }
  final stub = File('${dir.path}/flutterguard')
    ..writeAsStringSync("#!/bin/sh\n"
        'if [ "\$FG_STUB" = "fail" ]; then echo \'$_stubPayload\'; '
        'exit 1; fi\n'
        'exit 0\n');
  Process.runSync('chmod', ['+x', stub.path]);
  return dir.path;
}

void main() {
  group('marketplace + manifest', () {
    test('marketplace catalogs the plugin at ./plugin', () {
      final catalog =
          jsonDecode(File('.claude-plugin/marketplace.json').readAsStringSync())
              as Map;
      expect(catalog['name'], 'flutterguard');
      final plugins = catalog['plugins'] as List;
      expect(plugins, hasLength(1));
      expect(plugins.single['name'], 'flutterguard');
      expect(plugins.single['source'], './plugin');
      expect(plugins.single['description'], isNotEmpty);
    });

    test('plugin manifest mirrors pubspec and wires the MCP server', () {
      final manifest = jsonDecode(
          File('plugin/.claude-plugin/plugin.json').readAsStringSync()) as Map;
      final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(File('pubspec.yaml').readAsStringSync());
      expect(match, isNotNull);
      expect(manifest['version'], match!.group(1));
      expect(manifest['name'], 'flutterguard');
      expect(manifest['license'], 'MIT');
      for (final key in ['description', 'author', 'homepage', 'repository']) {
        expect(manifest[key], isNotNull, reason: key);
      }
      expect(manifest['mcpServers']['flutterguard']['command'],
          'flutterguard_mcp');
    });
  });

  group('embedded skill', () {
    test('plugin fg-use copy is byte-identical to the repo skill', () {
      final repo = File('.agents/skills/fg-use/SKILL.md').readAsBytesSync();
      final bundled = File('plugin/skills/fg-use/SKILL.md').readAsBytesSync();
      expect(bundled, orderedEquals(repo));
    });
  });

  group('hooks wiring', () {
    test('both gates call the standalone script with timeouts', () {
      final wired =
          jsonDecode(File('plugin/hooks/hooks.json').readAsStringSync()) as Map;
      final hooks = wired['hooks'] as Map;

      final pre = (hooks['PreToolUse'] as List).single as Map;
      expect(pre['matcher'], contains('Edit'));
      final preCommand =
          ((pre['hooks'] as List).single as Map)['command'] as String;
      expect(preCommand, startsWith('dart '));
      expect(preCommand, contains('CLAUDE_PLUGIN_ROOT'));
      expect(preCommand, contains('check_guard.dart'));
      expect(preCommand, contains('--presence'));
      expect(((pre['hooks'] as List).single as Map)['timeout'], 10);

      final post = (hooks['PostToolUse'] as List).single as Map;
      final postCommand =
          ((post['hooks'] as List).single as Map)['command'] as String;
      expect(postCommand, contains('check_guard.dart'));
      expect(postCommand, isNot(contains('--presence')));
      expect(((post['hooks'] as List).single as Map)['timeout'], 60);
    });

    test('hook script imports dart: only (standalone)', () {
      final imports = RegExp(r"^import '([^']+)'", multiLine: true)
          .allMatches(File(_hookScript).readAsStringSync())
          .map((match) => match.group(1));
      expect(imports, isNotEmpty);
      for (final uri in imports) {
        expect(uri, startsWith('dart:'));
      }
    });
  });

  group('hook behavior', () {
    late Directory scratch;

    setUp(() {
      scratch = Directory.systemTemp.createTempSync('fg_hook');
    });

    tearDown(() {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    test('non-dart path exits 0 silently', () async {
      final run = await _runHook(_event('/tmp/notes.md'));
      expect(run.exitCode, 0);
      expect(run.stderr, isEmpty);
    });

    test('malformed stdin exits 0 silently', () async {
      final run = await _runHook('not json');
      expect(run.exitCode, 0);
      expect(run.stderr, isEmpty);
    });

    test('event without a file exits 0 silently', () async {
      final run = await _runHook('{"hook_event_name":"SessionStart"}');
      expect(run.exitCode, 0);
      expect(run.stderr, isEmpty);
    });

    test('missing CLI fails closed with the install command', () async {
      final empty = Directory('${scratch.path}/empty')..createSync();
      for (final args in [
        const ['--presence'],
        const <String>[]
      ]) {
        final run = await _runHook(_event('/tmp/a.dart'),
            args: args, environment: {'PATH': empty.path});
        expect(run.exitCode, 2, reason: '$args');
        expect(run.stderr, contains('dart pub global activate'));
      }
    });

    test('presence mode never runs the gate', () async {
      final stubDir = _writeStub(scratch);
      final run = await _runHook(_event('/tmp/a.dart'),
          args: const ['--presence'],
          environment: {'PATH': stubDir, 'FG_STUB': 'fail'});
      expect(run.exitCode, 0);
      expect(run.stderr, isEmpty);
    });

    test('clean verdict exits 0', () async {
      final stubDir = _writeStub(scratch);
      final target = File(_hookScript).absolute.path;
      final run = await _runHook(_event(target),
          environment: {'PATH': stubDir, 'FG_STUB': 'pass'});
      expect(run.exitCode, 0);
      expect(run.stderr, isEmpty);
    });

    test('violations exit 2 with findings plus recipe pointers', () async {
      final stubDir = _writeStub(scratch);
      final target = File(_hookScript).absolute.path;
      final run = await _runHook(_event(target),
          environment: {'PATH': stubDir, 'FG_STUB': 'fail'});
      expect(run.exitCode, 2);
      expect(run.stderr, contains('FG-ST-001'));
      expect(run.stderr, contains('fix:'));
      expect(run.stderr, contains('Do not finish'));
    });

    test('missing file exits 0 (nothing to verify)', () async {
      final stubDir = _writeStub(scratch);
      final run = await _runHook(_event('${scratch.path}/gone.dart'),
          environment: {'PATH': stubDir, 'FG_STUB': 'fail'});
      expect(run.exitCode, 0);
    });
  });

  group('bundle hygiene', () {
    test('no lib/ code is vendored into the plugin', () {
      final dartFiles = Directory('plugin')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.path.replaceAll(r'\', '/'))
          .toList();
      expect(dartFiles, orderedEquals([_hookScript]));
    });

    test('plugin/ is self-clean under check', () {
      final result = checkPath('plugin');
      final errors =
          result.findings.where((f) => f.severity == 'error').toList();
      expect(errors, isEmpty, reason: 'shipped hook must be self-clean');
    });

    test('matrix docs name every client', () {
      for (final doc in ['README.md', 'LEIAME.md']) {
        final text = File(doc).readAsStringSync();
        for (final marker in [
          'flutterguard@flutterguard',
          'muse skills install',
          '.cursor/mcp.json',
          'Gemini CLI / Antigravity',
        ]) {
          expect(text, contains(marker), reason: '$doc misses $marker');
        }
      }
    });
  });
}
