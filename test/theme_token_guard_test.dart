import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-TOK-020 theme token guard', () {
    test('flags hardcoded colors in the golden bad vector', () {
      final violations = analyzeTokFile('benchmark/vectors/TC-20_tok.bad.dart');
      expect(violations.map((v) => v.line), [6, 7, 8]);
      expect(violations.first.message, contains('Color(...)'));
      expect(violations.first.message, contains('theme'));
      expect(violations[1].message, contains('Color.fromARGB(...)'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeTokFile(
        'benchmark/vectors/TC-20_tok.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags variables and prefixes, spares schemes and text', () {
      final root = Directory.systemTemp.createTempSync('tok_test.');
      try {
        final path = '${root.path}/near_miss.dart';
        File(path).writeAsStringSync('''
Object build(Object theme, Object ui, int value) {
  return Tile(
    a: Color(value),
    b: ui.Color(0xFF),
    c: ColorScheme.fromSeed(seed: value),
    d: 'Color(0xFF)',
    // Color(0xFF)
  );
}
''');
        final violations = analyzeTokFile(path);
        expect(violations.map((v) => v.line), [3, 4]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('honors except, extras, and the default-on message', () {
      final root = Directory.systemTemp.createTempSync('tok_test.');
      try {
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
theme_tokens:
  except: ["theme/**"]
  extra_ctors: ["BorderRadius.circular", "EdgeInsets", "bad..entry", "", "lowercase", 42]
  message: "use AppTheme"
''');
        Directory('${root.path}/theme').createSync();
        File('${root.path}/theme/tokens.dart').writeAsStringSync('''
Object build() {
  return Tile(color: Color(0xFF0000));
}
''');
        Directory('${root.path}/ui').createSync();
        final page = '${root.path}/ui/page.dart';
        File(page).writeAsStringSync('''
Object build() {
  return Tile(color: Color(0xFF0000));
}
''');
        final pad = '${root.path}/ui/pad.dart';
        File(pad).writeAsStringSync('''
Object build() {
  return Tile(
    a: BorderRadius.circular(8),
    b: BorderRadius.only(topLeft: 1),
    c: EdgeInsets.all(8),
  );
}
''');
        Directory('${root.path}/bare').createSync();
        File('${root.path}/bare/flutterguard.yaml').writeAsStringSync('''
rules:
  all: true
''');
        File('${root.path}/bare/plain.dart').writeAsStringSync('''
Object build() {
  return Tile(color: Color(0xFF0000));
}
''');

        expect(
          analyzeTokFile('${root.path}/theme/tokens.dart'),
          isEmpty,
          reason: 'except glob silences the theme files',
        );
        final pageViolations = analyzeTokFile(page);
        expect(pageViolations.map((v) => v.line), [2]);
        expect(pageViolations.single.message, contains('use AppTheme'));
        expect(analyzeTokFile(pad).map((v) => v.line), [
          3,
          5,
        ], reason: 'dotted extra is precise; whole-type extra covers .all');
        final bareViolations = analyzeTokFile('${root.path}/bare/plain.dart');
        expect(bareViolations.map((v) => v.line), [
          2,
        ], reason: 'defaults fire without the section (default-on)');
        expect(bareViolations.single.message, contains('use a theme token'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
