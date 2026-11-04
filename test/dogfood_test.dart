// Dogfood L0 (PLAN-03 U1): the harness eats its own cooking —
// `check` over lib/bin/test reports zero error-severity findings,
// and checking never mutates the tree (read-only) nor depends on how
// paths are spelled (relative vs absolute).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Self-gated roots (vectors excluded by design: they MUST flag).
const _roots = ['lib', 'bin', 'test'];

void main() {
  group('dogfood L0 self-check', () {
    test('lib, bin, test carry zero error-severity findings', () {
      for (final root in _roots) {
        final result = checkPath(root);
        final errors =
            result.findings.where((f) => f.severity == 'error').toList();
        expect(errors, isEmpty, reason: '$root must be self-clean: $errors');
      }
    });

    test('vector exclusion is load-bearing (not vacuous)', () {
      final vectors = checkPath('benchmark/vectors');
      expect(vectors.findings.any((f) => f.severity == 'error'), isTrue,
          reason: 'golden .bad vectors must flag — exclusion is real');
    });
  });

  group('dogfood L0 non-pollution', () {
    test('checking is read-only (tree hash stable)', () {
      final watched = [..._roots, 'specs', 'benchmark'];
      final before = _treeHash(watched);
      for (final root in _roots) {
        checkPath(root);
      }
      checkPath('benchmark/vectors');
      expect(_treeHash(watched), before,
          reason: 'check must not write anywhere');
    });

    test('relative vs absolute paths find the same violations', () {
      final absolute = Directory('lib').absolute.path.replaceAll(r'\', '/');
      final relative = checkPath('lib');
      final absoluteResult = checkPath(absolute);
      Set<String> triples(CheckResult result) => {
            for (final f in result.findings)
              '${f.ruleId}:${f.line}:${f.message}'
          };
      expect(triples(absoluteResult), triples(relative));
      expect(absoluteResult.errors, isEmpty);
    });
  });
}

/// FNV-1a-64 over every file under [roots] (sorted paths; path +
/// bytes folded in). Hand-rolled: no crypto dependency for a test.
int _treeHash(List<String> roots) {
  var hash = 0xcbf29ce484222325;
  void fold(List<int> bytes) {
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
  }

  final files = <String>[];
  for (final root in roots) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File) files.add(entity.path);
    }
  }
  files.sort();
  for (final path in files) {
    fold(path.codeUnits);
    fold(File(path).readAsBytesSync());
  }
  return hash;
}
