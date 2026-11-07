// Doc-count pins: user-facing counts track the registry, not memory.
// The R2-5 rules landed while README/LEIAME/CHANGELOG still quoted the
// old totals (29/17 vs 33); this test fails the suite the next time a
// count drifts (audit D1-D4).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

String _read(String path) => File(path).readAsStringSync();

/// MCP chat-skills (SYS-MCP-001 table): closed by design. Adding a
/// chat-skill updates this list and the docs together; harness-only
/// skills (learn, audit, …) never join it.
const _chatSkills = {
  'fg-grade',
  'fg-spec',
  'fg-use',
  'fg-vector',
  'fg-visitor',
};

void main() {
  final total = ruleAnalyzers.length;
  final blocking = ruleAnalyzers
      .where((rule) => rule.severity == 'error')
      .length;
  final advisory = [
    for (final rule in ruleAnalyzers)
      if (rule.severity != 'error') rule.id,
  ]..sort();

  group('doc counts track the registry', () {
    test('README scope quotes registry totals', () {
      final readme = _read('README.md');
      expect(readme, contains('$total rules implemented ($blocking blocking'));
      final head = readme.split('\n').take(25).join('\n');
      for (final id in advisory) {
        expect(head, contains('`$id`'));
      }
    });

    test('README MCP row quotes the rule total', () {
      expect(_read('README.md'), contains('all $total AST rules'));
    });

    test('LEIAME scope quotes registry totals', () {
      final leiame = _read('LEIAME.md');
      expect(
        leiame,
        contains('$total regras implementadas ($blocking bloqueantes'),
      );
      final head = leiame.split('\n').take(25).join('\n');
      for (final id in advisory) {
        expect(head, contains('`$id`'));
      }
    });

    test('LEIAME MCP row quotes the rule total', () {
      expect(_read('LEIAME.md'), contains('as $total regras AST'));
    });

    test('CHANGELOG 0.1.0 quotes registry totals', () {
      final changelog = _read('CHANGELOG.md');
      expect(changelog, contains('- $total AST rules ($blocking blocking'));
      for (final id in advisory) {
        expect(changelog, contains('`$id`'));
      }
    });

    test('chat-skill count matches the pinned table', () {
      for (final id in _chatSkills) {
        expect(
          File('.agents/skills/$id/SKILL.md').existsSync(),
          isTrue,
          reason: 'missing skill dir for $id',
        );
      }
      final count = '${_chatSkills.length} chat-skills';
      expect(_read('README.md'), contains(count));
      expect(_read('LEIAME.md'), contains(count));
      expect(_read('CHANGELOG.md'), contains(count));
    });

    test('typed-tool count matches the MCP registry', () {
      final count = '${mcpToolDefs.length} typed tools';
      expect(_read('README.md'), contains(count));
      expect(
        _read('LEIAME.md'),
        contains('${mcpToolDefs.length} ferramentas tipadas'),
      );
    });
  });
}
