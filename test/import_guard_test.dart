// FG-IMP-015 contract test: flags dart:mirrors and lib-escape
// imports/exports, spares legal shapes.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-IMP-015 import guard', () {
    test('flags the .bad vector at exact lines', () {
      final violations =
          analyzeImportFile('benchmark/vectors/TC-15_imp.bad.dart');
      expect(violations.map((v) => v.line), [2, 4]);
      expect(violations.first.message, contains('dart:mirrors'));
    });

    test('spares the .good vector (zero false positives)', () {
      final violations =
          analyzeImportFile('benchmark/vectors/TC-15_imp.good.dart');
      expect(violations, isEmpty);
    });

    test('flags lib-escape imports and exports', () {
      final root = Directory.systemTemp.createTempSync('imp_test.');
      try {
        final page = File('${root.path}/lib/ui/page.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("import '../../tool/debug.dart';\n");
        final api = File('${root.path}/lib/api.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("export '../tool/types.dart';\n");
        final pageHits = analyzeImportFile(page.path);
        expect(pageHits.map((v) => v.line), [1]);
        expect(pageHits.first.message, contains('../../tool/debug.dart'));
        final apiHits = analyzeImportFile(api.path);
        expect(apiHits.map((v) => v.line), [1]);
        expect(apiHits.first.message, contains('../tool/types.dart'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('spares in-lib, outside-lib, and uppercase-LIB shapes', () {
      final root = Directory.systemTemp.createTempSync('imp_test.');
      try {
        final inLib = File('${root.path}/lib/ui/ok.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync(
              "import './sibling.dart';\nimport 'package:x/y.dart';\n");
        final outside = File('${root.path}/test/x_test.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("import '../lib/a.dart';\n");
        final upper = File('${root.path}/LIB/upper.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("import '../escape.dart';\n");
        final nested = File('${root.path}/lib/src/lib/inner.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("import './helper.dart';\n");
        for (final file in [inLib, outside, upper, nested]) {
          expect(analyzeImportFile(file.path), isEmpty, reason: file.path);
        }
        final nestedEscape = File('${root.path}/lib/src/lib/deep.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("import '../x.dart';\n");
        expect(analyzeImportFile(nestedEscape.path).map((v) => v.line), [1]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('flags conditional URIs, spares absolute and file: URIs', () {
      final root = Directory.systemTemp.createTempSync('imp_test.');
      try {
        final cond = File('${root.path}/lib/cond.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync("import './ok.dart'\n"
              "    if (dart.library.io) 'dart:mirrors';\n"
              "import 'package:x/y.dart'\n"
              "    if (dart.library.html) '../escape.dart';\n"
              "import 'file:///x.dart';\n"
              "import '/absolute/path.dart';\n");
        expect(analyzeImportFile(cond.path).map((v) => v.line), [2, 4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
