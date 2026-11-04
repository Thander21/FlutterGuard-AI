import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../bin/flutterguard.dart' as cli;

const _blocBad = '''
class CartCubit extends Cubit<CartState> {
  Future<void> checkout() async {
    await _repository.save();
    emit(CartSaved());
  }
}
''';

void main() {
  group('SYS-CLI-001b init', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('init_test.');
      Directory('${root.path}/.git/hooks').createSync(recursive: true);
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('writes yaml and hook, skips opt-ins by default', () {
      expect(cli.init([], root: root.path), isZero);
      final yaml = File('${root.path}/flutterguard.yaml');
      expect(yaml.existsSync(), isTrue);
      final yamlText = yaml.readAsStringSync();
      for (final key in [
        'version: 1',
        'validate-light',
        'test:',
        'validate:',
        'commit-check'
      ]) {
        expect(yamlText, contains(key));
      }
      final hook = File('${root.path}/.git/hooks/pre-commit');
      expect(hook.existsSync(), isTrue);
      final hookText = hook.readAsStringSync();
      expect(hookText, contains('SYS-CLI-001b'));
      expect(hookText, contains('check .'));
      expect(hookText, contains('FLUTTERGUARD_ROOT'));
      expect(Directory('${root.path}/.flutterguard').existsSync(), isFalse);
      expect(File('${root.path}/AGENTS.md').existsSync(), isFalse);
    });

    test('reinstall is idempotent', () {
      expect(cli.init([], root: root.path), isZero);
      final before =
          File('${root.path}/.git/hooks/pre-commit').readAsStringSync();
      expect(cli.init([], root: root.path), isZero);
      expect(File('${root.path}/.git/hooks/pre-commit').readAsStringSync(),
          before);
    });

    test('scaffold and agents flags are opt-in and idempotent', () {
      expect(cli.init(['--scaffold', '--agents'], root: root.path), isZero);
      expect(Directory('${root.path}/.flutterguard').existsSync(), isTrue);
      final agents = File('${root.path}/AGENTS.md');
      expect(agents.existsSync(), isTrue);
      const marker = 'FLUTTERGUARD MCP HARNESS CONTRACT';
      expect(agents.readAsStringSync(), contains(marker));
      expect(cli.init(['--agents'], root: root.path), isZero);
      expect(marker.allMatches(agents.readAsStringSync()), hasLength(1));
    });

    test('fails closed outside a git repo, yaml still lands', () {
      final plain = Directory.systemTemp.createTempSync('init_plain.');
      try {
        expect(cli.init([], root: plain.path), 1);
        expect(File('${plain.path}/flutterguard.yaml').existsSync(), isTrue);
        expect(Directory('${plain.path}/.git').existsSync(), isFalse);
      } finally {
        plain.deleteSync(recursive: true);
      }
    });

    test('refuses to overwrite a foreign hook', () {
      File('${root.path}/.git/hooks/pre-commit')
          .writeAsStringSync('foreign\n');
      expect(cli.init([], root: root.path), 1);
      expect(File('${root.path}/.git/hooks/pre-commit').readAsStringSync(),
          'foreign\n');
    });

    test('usage errors', () {
      expect(cli.init(['--help'], root: root.path), isZero);
      expect(cli.init(['extra'], root: root.path), 2);
    });

    test('--mcp writes the generic config, skips cursor undetected', () {
      expect(cli.init(['--mcp'], root: root.path), isZero);
      final generic = File('${root.path}/mcp_config.json');
      expect(generic.existsSync(), isTrue);
      final decoded = jsonDecode(generic.readAsStringSync());
      expect(decoded['mcpServers']['flutterguard']['command'],
          'flutterguard_mcp');
      expect(
          File('${root.path}/.cursor/mcp.json').existsSync(), isFalse);
    });

    test('--mcp merges cursor config, preserving other servers', () {
      Directory('${root.path}/.cursor').createSync();
      File('${root.path}/.cursor/mcp.json').writeAsStringSync(
          '{"mcpServers": {"other": {"command": "x"}}}');
      expect(cli.init(['--mcp'], root: root.path), isZero);
      final decoded = jsonDecode(
          File('${root.path}/.cursor/mcp.json').readAsStringSync());
      expect(decoded['mcpServers']['other'], {'command': 'x'});
      expect(decoded['mcpServers']['flutterguard']['command'],
          'flutterguard_mcp');
    });

    test('--mcp fails closed on unparseable config', () {
      File('${root.path}/mcp_config.json').writeAsStringSync('{nope');
      expect(cli.init(['--mcp'], root: root.path), 1);
      expect(File('${root.path}/mcp_config.json').readAsStringSync(),
          '{nope');
    });

    test('existing yaml is left untouched', () {
      File('${root.path}/flutterguard.yaml').writeAsStringSync('custom\n');
      expect(cli.init([], root: root.path), isZero);
      expect(File('${root.path}/flutterguard.yaml').readAsStringSync(),
          'custom\n');
    });
  });

  group('SYS-CLI-001b sandbox', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('sandbox_test.');
      Directory('${root.path}/benchmark/vectors').createSync(recursive: true);
      File('${root.path}/benchmark/vectors/x.bad.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync());
      File('${root.path}/benchmark/vectors/y.good.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.good.dart').readAsStringSync());
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('load, check, reset cycle', () {
      expect(cli.sandbox(['load'], root: root.path), isZero);
      final box = Directory('${root.path}/fixtures/sandbox');
      expect(box.listSync().map((e) => e.path), hasLength(1));
      expect(cli.sandbox(['check'], root: root.path), 1,
          reason: 'violations are the expected state right after load');
      expect(cli.sandbox(['reset'], root: root.path), isZero);
      expect(box.listSync(), isEmpty);
    });

    test('load fails without a vectors source', () {
      final empty = Directory.systemTemp.createTempSync('sandbox_empty.');
      try {
        expect(cli.sandbox(['load'], root: empty.path), 1);
      } finally {
        empty.deleteSync(recursive: true);
      }
    });

    test('usage errors', () {
      expect(cli.sandbox([], root: root.path), 2);
      expect(cli.sandbox(['bogus'], root: root.path), 2);
    });
  });

  group('SYS-CLI-001b install scripts', () {
    test('ship with the real repo url and no placeholders', () {
      for (final name in ['install.sh', 'install.ps1']) {
        final content = File(name).readAsStringSync();
        expect(content, contains('Thander21/FlutterGuard-AI'));
        expect(content, isNot(contains('SEU-USER')));
      }
    });
  });

  group('SYS-CLI-001b hook', () {
    test('hook blocks a planted violation commit in a scratch clone',
        () async {
      final scratch = Directory.systemTemp.createTempSync('hook_clone.');
      try {
        Future<ProcessResult> git(List<String> args,
            {Map<String, String>? env}) {
          return Process.run(
            'git',
            args,
            workingDirectory: scratch.path,
            environment: env,
          );
        }

        expect((await git(['init', '-b', 'main'])).exitCode, isZero);
        await git(['config', 'user.email', 'hook@test']);
        await git(['config', 'user.name', 'hook']);
        await git(['config', 'commit.gpgsign', 'false']);
        expect(cli.init([], root: scratch.path), isZero);

        final repo = Directory.current.path.replaceAll(r'\', '/');
        final env = {
          ...Platform.environment,
          'FLUTTERGUARD_ROOT': repo,
        };

        File('${scratch.path}/bad.dart').writeAsStringSync(_blocBad);
        await git(['add', '-A']);
        final blocked = await git(['commit', '-m', 'planted'], env: env);
        expect(blocked.exitCode, isNot(0),
            reason: 'hook must block the violation commit');

        File('${scratch.path}/bad.dart').deleteSync();
        File('${scratch.path}/clean.dart').writeAsStringSync('void main() {}\n');
        await git(['add', '-A']);
        final allowed = await git(['commit', '-m', 'clean'], env: env);
        expect(allowed.exitCode, isZero,
            reason: 'hook must allow the clean commit');
      } finally {
        scratch.deleteSync(recursive: true);
      }
    }, timeout: const Timeout(Duration(seconds: 180)));
  });
}
