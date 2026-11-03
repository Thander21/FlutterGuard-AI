import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('SYS-RECIPE-001 recipe coverage', () {
    test('every registered rule resolves to a spec with a §2 recipe', () {
      expect(ruleAnalyzers, isNotEmpty);
      for (final rule in ruleAnalyzers) {
        final file = File(rule.spec);
        expect(file.existsSync(), isTrue,
            reason: '${rule.id}: missing spec file ${rule.spec}');
        final text = file.readAsStringSync();
        expect(_frontMatterId(text), rule.id,
            reason: '${rule.id}: front-matter id mismatch in ${rule.spec}');
        expect(text, contains('# 2. Canonical Auto-Heal Recipe'),
            reason: '${rule.id}: ${rule.spec} carries no §2 recipe');
        final diff = _firstDiffBlock(text);
        expect(diff, isNotNull,
            reason: '${rule.id}: §2 without a Before/After diff block');
        expect(
            diff!.any((l) =>
                (l.startsWith('-') || l.startsWith('+')) &&
                l.trim().length > 1),
            isTrue,
            reason: '${rule.id}: §2 diff without a changed line');
      }
    });

    test('every rule spec is registered (no orphans)', () {
      final specs = Directory('specs')
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.endsWith('.md') && !f.path.endsWith('_template.md'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      expect(specs, isNotEmpty);
      final registered = {for (final rule in ruleAnalyzers) rule.spec};
      for (final spec in specs) {
        expect(registered, contains(spec),
            reason: '$spec has no registry entry');
      }
    });

    test('template mandates the §2 recipe', () {
      final text = File('specs/_template.md').readAsStringSync();
      expect(text, contains('# 2. Canonical Auto-Heal Recipe'));
      expect(_firstDiffBlock(text), isNotNull);
    });

    test('methodology catalog stays resolvable as frozen reference', () {
      expect(
          File('docs/_origem/CanonicalRecipesCatalog.md').existsSync(),
          isTrue);
    });
  });
}

/// `id` value from a spec's YAML front matter (minimal line parser,
/// mirroring the grader: no yaml dependency).
String? _frontMatterId(String text) {
  var inMatter = false;
  for (final line in text.split('\n')) {
    if (line.trim() == '---') {
      if (inMatter) break;
      inMatter = true;
      continue;
    }
    if (!inMatter) continue;
    final match =
        RegExp(r'^\s*id:\s*"?([^"\s]+)"?\s*$').firstMatch(line);
    if (match != null) return match.group(1);
  }
  return null;
}

/// Lines of the first `diff` fence in [text], or null when absent.
List<String>? _firstDiffBlock(String text) {
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() == '```diff') {
      final block = <String>[];
      for (var j = i + 1; j < lines.length; j++) {
        if (lines[j].trim() == '```') return block;
        block.add(lines[j]);
      }
      return block;
    }
  }
  return null;
}
