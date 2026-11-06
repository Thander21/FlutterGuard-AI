import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('FG-VER-031 version guard', () {
    test('flags the malformed version in the golden bad vector', () {
      final violations = analyzeVersionFile(
        'benchmark/vectors/TC-31_ver.bad.yaml',
      );
      expect(violations.map((v) => v.line), [2]);
      expect(violations.single.message, contains("'1.2'"));
    });

    test('spares the golden good vector (zero false positives)', () {
      final violations = analyzeVersionFile(
        'benchmark/vectors/TC-31_ver.good.yaml',
      );
      expect(violations, isEmpty);
    });

    test('flags free text, four-part, integer, and empty versions', () {
      final root = Directory.systemTemp.createTempSync('version_test.');
      try {
        for (final entry in {
          'latest': 'latest',
          '1.2.3.4': '1.2.3.4',
          '2': '2',
        }.entries) {
          File('${root.path}/pubspec.yaml')
              .writeAsStringSync('name: x\nversion: ${entry.key}\n');
          final violations = analyzeVersionFile('${root.path}/pubspec.yaml');
          expect(violations.map((v) => v.line), [2]);
          expect(violations.single.message, contains("'${entry.value}'"));
        }
        File('${root.path}/pubspec.yaml')
            .writeAsStringSync('name: x\nversion:\n');
        final empty = analyzeVersionFile('${root.path}/pubspec.yaml');
        expect(empty.map((v) => v.line), [2]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('accepts plain, build, and prerelease versions', () {
      final root = Directory.systemTemp.createTempSync('version_test.');
      try {
        for (final version in ['0.1.0', '1.0.0+42', '1.0.0-dev', '10.20.30']) {
          File('${root.path}/pubspec.yaml')
              .writeAsStringSync('name: x\nversion: $version\n');
          expect(
            analyzeVersionFile('${root.path}/pubspec.yaml'),
            isEmpty,
            reason: '$version must stay clean',
          );
        }
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('stays silent without a version key or on broken yaml', () {
      final root = Directory.systemTemp.createTempSync('version_test.');
      try {
        File('${root.path}/pubspec.yaml').writeAsStringSync('name: x\n');
        expect(analyzeVersionFile('${root.path}/pubspec.yaml'), isEmpty);
        File('${root.path}/pubspec.yaml')
            .writeAsStringSync('version: [unclosed\n');
        expect(analyzeVersionFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('tolerates CRLF', () {
      final root = Directory.systemTemp.createTempSync('version_test.');
      try {
        File('${root.path}/pubspec.yaml')
            .writeAsStringSync('name: x\r\nversion: 1.2.3\r\n');
        expect(analyzeVersionFile('${root.path}/pubspec.yaml'), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('pubspec scope keeps other yaml files out of check walks', () {
      final rule = ruleAnalyzers.singleWhere((r) => r.id == 'FG-VER-031');
      expect(rule.scopes('pkg/pubspec.yaml'), isTrue);
      expect(rule.scopes('pkg/other.yaml'), isFalse);
      expect(rule.scopes('pkg/pubspec.yaml.bak'), isFalse);
    });
  });
}
