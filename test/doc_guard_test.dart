import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-DOC-032 doc guard', () {
    test('flags dead links in the golden bad vector', () {
      final violations = analyzeDocFile('benchmark/vectors/tc32/bad/guide.md');
      expect(violations.map((v) => v.line), [3, 5]);
      expect(violations[0].message, contains('runbook.md'));
      expect(violations[1].message, contains('assets/flow.png'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeDocFile('benchmark/vectors/tc32/good/guide.md');
      expect(violations, isEmpty);
    });

    test('resolves titles and angle destinations on the path part', () {
      final root = Directory.systemTemp.createTempSync('doc_test.');
      try {
        File('${root.path}/real.md').writeAsStringSync('# real\n');
        File('${root.path}/my page.md').writeAsStringSync('# spaced\n');
        File('${root.path}/guide.md').writeAsStringSync(
          '[a](real.md "t")\n[b](<my page.md>)\n[c](gone.md "t")\n',
        );
        final violations = analyzeDocFile('${root.path}/guide.md');
        expect(violations.map((v) => v.line), [3]);
        expect(violations.single.message, contains('gone.md'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('reports one finding per dead link on shared lines', () {
      final root = Directory.systemTemp.createTempSync('doc_test.');
      try {
        File('${root.path}/guide.md')
            .writeAsStringSync('[a](gone-a.md) and [b](gone-b.md)\n');
        final violations = analyzeDocFile('${root.path}/guide.md');
        expect(violations.map((v) => v.line), [1, 1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('tolerates CRLF', () {
      final root = Directory.systemTemp.createTempSync('doc_test.');
      try {
        File('${root.path}/real.md').writeAsStringSync('# real\n');
        File('${root.path}/guide.md')
            .writeAsStringSync('# Guide\r\n\r\nSee [real](real.md).\r\n');
        expect(analyzeDocFile('${root.path}/guide.md'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('md scope keeps other files out of check walks', () {
      final rule = ruleAnalyzers.singleWhere((r) => r.id == 'FG-DOC-032');
      expect(rule.scopes('docs/guide.md'), isTrue);
      expect(rule.scopes('docs/guide.dart'), isFalse);
      expect(rule.scopes('docs/guide.md.bak'), isFalse);
    });
  });
}
