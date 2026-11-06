import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-I18N-021 i18n guard', () {
    test('flags hardcoded strings in the golden bad vector', () {
      final violations = analyzeI18nFile(
        'benchmark/vectors/tc21/TC-21_i18n.bad.dart',
      );
      expect(violations.map((v) => v.line), [6, 6, 6]);
      expect(violations.first.message, contains('Text(...)'));
      expect(violations.first.message, contains('appLocalizations'));
      expect(violations.last.message, contains('SelectableText(...)'));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeI18nFile(
        'benchmark/vectors/tc21/TC-21_i18n.good.dart',
      );
      expect(violations, isEmpty);
    });

    test('flags const, prefixed, and adjacent literals', () {
      final root = Directory.systemTemp.createTempSync('i18n_test.');
      try {
        final path = '${root.path}/shapes.dart';
        File(path).writeAsStringSync('''
Object build() {
  return Column(
    children: [
      const Text('a'),
      ui.Text('b'),
      Text('c' 'd'),
    ],
  );
}
''');
        final violations = analyzeI18nFile(
          path,
          config: const FlatRuleConfig(),
        );
        expect(violations.map((v) => v.line), [4, 5, 6]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('honors except, empty-map, and lenient degrade', () {
      final root = Directory.systemTemp.createTempSync('i18n_test.');
      try {
        File('${root.path}/flutterguard.yaml').writeAsStringSync('''
i18n:
  widgets: [Badge]
  except: ["l10n/**"]
  message: "use appLocalizations"
''');
        Directory('${root.path}/l10n').createSync();
        File('${root.path}/l10n/delegate.dart').writeAsStringSync('''
Object build() {
  return Text('x');
}
''');
        Directory('${root.path}/ui').createSync();
        final page = '${root.path}/ui/page.dart';
        File(page).writeAsStringSync('''
Object build() {
  return Column(
    children: [
      Text('x'),
      Badge('y'),
    ],
  );
}
''');
        Directory('${root.path}/empty').createSync();
        File('${root.path}/empty/flutterguard.yaml').writeAsStringSync('''
i18n: {}
''');
        File('${root.path}/empty/a.dart').writeAsStringSync('''
Object build() {
  return Column(
    children: [
      Text('x'),
      Badge('not configured here'),
    ],
  );
}
''');
        Directory('${root.path}/messy').createSync();
        File('${root.path}/messy/flutterguard.yaml').writeAsStringSync('''
i18n:
  widgets: "not-a-list"
  except: 42
  message: []
''');
        File('${root.path}/messy/b.dart').writeAsStringSync('''
Object build() {
  return Text('x');
}
''');

        expect(
          analyzeI18nFile('${root.path}/l10n/delegate.dart'),
          isEmpty,
          reason: 'except glob silences the catalog files',
        );
        final pageViolations = analyzeI18nFile(page);
        expect(pageViolations.map((v) => v.line), [4, 5]);
        expect(pageViolations.first.message, contains('appLocalizations'));
        final emptyViolations = analyzeI18nFile('${root.path}/empty/a.dart');
        expect(emptyViolations.map((v) => v.line), [
          4,
        ], reason: 'empty map enables Text only (Badge stays clean)');
        expect(emptyViolations.single.message, contains('l10n catalog'));
        expect(
          analyzeI18nFile('${root.path}/messy/b.dart').map((v) => v.line),
          [2],
          reason: 'malformed fields degrade leniently, defaults flag',
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('is silent without configuration', () {
      final root = Directory.systemTemp.createTempSync('i18n_test.');
      try {
        final path = '${root.path}/plain.dart';
        File(path).writeAsStringSync('''
Object build() {
  return Text('x');
}
''');
        expect(analyzeI18nFile(path), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
