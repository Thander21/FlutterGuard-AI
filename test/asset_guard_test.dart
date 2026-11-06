import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-ASSET-030 asset guard', () {
    test('flags missing entries in the golden bad vector', () {
      final violations = analyzeAssetFile(
        'benchmark/vectors/tc30/bad/pubspec.yaml',
      );
      expect(violations.map((v) => v.line), [9, 10]);
      expect(violations[0].message, contains('assets/images/missing.png'));
      expect(violations[1].message, contains('assets/fonts/'));
    });

    test('spares the golden good vector (zero false positives)', () {
      // The good tree also carries an undeclared file
      // (assets/unlisted.png): the v0-deferred vice-versa stays clean.
      final violations = analyzeAssetFile(
        'benchmark/vectors/tc30/good/pubspec.yaml',
      );
      expect(violations, isEmpty);
    });

    test('stays silent without a flutter section or assets key', () {
      final root = Directory.systemTemp.createTempSync('asset_test.');
      try {
        File('${root.path}/pubspec.yaml')
            .writeAsStringSync('name: pure\nversion: 1.0.0\n');
        expect(analyzeAssetFile('${root.path}/pubspec.yaml'), isEmpty);
        File('${root.path}/pubspec.yaml').writeAsStringSync(
          'name: x\nflutter:\n  uses-material-design: true\n',
        );
        expect(analyzeAssetFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('stays silent on unparseable yaml', () {
      final root = Directory.systemTemp.createTempSync('asset_test.');
      try {
        File('${root.path}/pubspec.yaml')
            .writeAsStringSync('flutter: [unclosed\n  assets: -x\n');
        expect(analyzeAssetFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('skips non-string entries', () {
      final root = Directory.systemTemp.createTempSync('asset_test.');
      try {
        File('${root.path}/pubspec.yaml').writeAsStringSync(
          'name: x\nflutter:\n  assets:\n    - 123\n    - {a: b}\n    - ~\n',
        );
        expect(analyzeAssetFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('ignores the fonts section', () {
      final root = Directory.systemTemp.createTempSync('asset_test.');
      try {
        Directory('${root.path}/assets').createSync();
        File('${root.path}/pubspec.yaml').writeAsStringSync(
          'name: x\n'
          'flutter:\n'
          '  assets:\n'
          '    - assets/\n'
          '  fonts:\n'
          '    - family: Gone\n'
          '      fonts:\n'
          '        - asset: fonts/missing.ttf\n',
        );
        expect(analyzeAssetFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('tolerates CRLF', () {
      final root = Directory.systemTemp.createTempSync('asset_test.');
      try {
        Directory('${root.path}/assets').createSync();
        File('${root.path}/assets/ok.png').writeAsStringSync('x');
        File('${root.path}/pubspec.yaml').writeAsStringSync(
          'name: x\r\nflutter:\r\n  assets:\r\n    - assets/ok.png\r\n',
        );
        expect(analyzeAssetFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('pubspec scope keeps other yaml files out of check walks', () {
      final rule = ruleAnalyzers.singleWhere((r) => r.id == 'FG-ASSET-030');
      expect(rule.scopes('pkg/pubspec.yaml'), isTrue);
      expect(rule.scopes('pkg/other.yaml'), isFalse);
      expect(rule.scopes('pkg/pubspec.yaml.bak'), isFalse);
    });
  });
}
