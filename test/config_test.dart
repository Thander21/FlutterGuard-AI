// Schema-v2 config loader contract test: walk-up discovery plus
// per-rule toggles (absent/non-bool/unknown/broken all default on).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

RuleAnalyzer _rule(String id) =>
    RuleAnalyzer(id: id, spec: 'specs/x.md', analyze: (_) => const []);

void main() {
  group('config loader', () {
    test('findConfig walks up from files and directories', () {
      final root = Directory.systemTemp.createTempSync('config_test.');
      try {
        final nested = Directory('${root.path}/a/b')
          ..createSync(recursive: true);
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('version: 2\n');
        final target = File('${nested.path}/x.dart')
          ..writeAsStringSync('void f() {}\n');
        final want = '${root.path.replaceAll(r'\', '/')}/flutterguard.yaml';
        expect(findConfig(target.path), want);
        expect(findConfig(nested.path), want);
        expect(findConfig(root.path), want);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('findConfig returns null without a config', () {
      final root = Directory.systemTemp.createTempSync('config_test.');
      try {
        expect(findConfig(root.path), isNull);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('enabledAnalyzers honors disables and the all default', () {
      final root = Directory.systemTemp.createTempSync('config_test.');
      try {
        final rules = [_rule('FG-A'), _rule('FG-B'), _rule('FG-C')];
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
version: 2
rules:
  FG-A: false
  FG-B: true
''');
        expect(enabledAnalyzers(root.path, rules).map((r) => r.id), [
          'FG-B',
          'FG-C',
        ]);
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
version: 2
rules:
  all: false
  FG-A: true
''');
        expect(enabledAnalyzers(root.path, rules).map((r) => r.id), ['FG-A']);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('broken configs default to all enabled', () {
      final root = Directory.systemTemp.createTempSync('config_test.');
      try {
        final rules = [_rule('FG-A'), _rule('FG-B')];
        final broken = [
          '{{{unparseable',
          '[1, 2]',
          'version: 2\nrules: false\n',
          'version: 2\nrules:\n  FG-A: maybe\n',
          'version: 2\nrules:\n  FG-NOPE: false\n',
          'version: 1\ngates:\n  test: true\n',
        ];
        for (final content in broken) {
          File('${root.path}/flutterguard.yaml').writeAsStringSync(content);
          expect(enabledAnalyzers(root.path, rules).map((r) => r.id), [
            'FG-A',
            'FG-B',
          ], reason: 'broken config defaults on: $content');
        }
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
