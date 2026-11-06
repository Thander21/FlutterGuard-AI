import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-LYR-024 layer guard', () {
    test('flags the denied import in the golden bad vector', () {
      final violations = analyzeLayerFile(
        'benchmark/vectors/tc24/ui/TC-24_layer.bad.dart',
      );
      expect(violations.map((v) => v.line), [4]);
      expect(violations.single.message, contains('package:drift/drift.dart'));
      expect(violations.single.message, contains('ui/**'));
      expect(
        violations.single.message,
        contains('ui must not touch the database directly'),
      );
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeLayerFile(
        'benchmark/vectors/tc24/data/TC-24_layer.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('covers exports, relative URIs, parts, and unions', () {
      final root = Directory.systemTemp.createTempSync('lyr_test.');
      try {
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
layer_rules:
  - files: ["ui/**"]
    deny_imports: ["package:drift/**", "../data/**", "dart:io"]
    except: ["ui/di.dart"]
    message: "route through the repository"
  - files: ["ui/twin.dart"]
    deny_imports: ["package:drift/**"]
  - "not-a-map"
  - files: "not-a-list"
  - files: ["ui/**"]
  - files: []
    deny_imports: ["package:x/**"]
  - files: ["ui/**"]
    deny_imports: ["package:x/**", 42]
  - files: ["ui/**"]
    deny_imports: ["package:x/**"]
    except: "not-a-list"
''');
        Directory('${root.path}/ui').createSync();
        File('${root.path}/ui/di.dart').writeAsStringSync('''
import 'package:drift/drift.dart';

Object load() => queryAll();
''');
        final page = '${root.path}/ui/page.dart';
        File(page).writeAsStringSync('''
import 'package:drift/drift.dart' show User;
import '../data/db.dart';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'sibling.dart';
part 'page.part.dart';

Object load() => queryAll();
''');
        File('${root.path}/ui/twin.dart').writeAsStringSync('''
import 'package:drift/drift.dart';

Object load() => queryAll();
''');
        File('${root.path}/ui/shop.dart').writeAsStringSync('''
export 'package:drift/drift.dart';

Object load() => queryAll();
''');

        expect(
          analyzeLayerFile('${root.path}/ui/di.dart'),
          isEmpty,
          reason: 'except glob silences the injection file',
        );
        final pageViolations = analyzeLayerFile(page);
        expect(
          pageViolations.map((v) => v.line),
          [1, 2, 3],
          reason:
              'package, relative, and dart URIs flag; '
              'flutter, sibling, and part stay clean',
        );
        expect(
          pageViolations.first.message,
          contains('route through the repository'),
        );
        expect(
          analyzeLayerFile('${root.path}/ui/twin.dart').map((v) => v.line),
          [1, 1],
          reason: 'two matching rules union (one finding each)',
        );
        expect(
          analyzeLayerFile('${root.path}/ui/shop.dart').map((v) => v.line),
          [1],
          reason: 'exports leak layers too',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('is silent without configuration', () {
      final root = Directory.systemTemp.createTempSync('lyr_test.');
      try {
        final path = '${root.path}/plain.dart';
        File(path).writeAsStringSync('''
import 'package:drift/drift.dart';

Object load() => queryAll();
''');
        expect(analyzeLayerFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
