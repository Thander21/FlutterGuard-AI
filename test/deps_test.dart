// DepAudit gate: `pub outdated` signals per package root.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

const _clean = '''
{"packages": [{"package": "args", "kind": "direct", "isDiscontinued": false, "replacedBy": null, "isCurrentRetracted": false, "isCurrentAffectedByAdvisory": false}]}
''';

const _flagged = '''
{"packages": [
  {"package": "old", "isDiscontinued": true, "replacedBy": "new_pkg", "isCurrentRetracted": false, "isCurrentAffectedByAdvisory": false},
  {"package": "gone", "isDiscontinued": true, "isCurrentRetracted": false, "isCurrentAffectedByAdvisory": false},
  {"package": "bad", "isDiscontinued": false, "isCurrentRetracted": true, "isCurrentAffectedByAdvisory": true}
]}
''';

/// Stages a dependency-free package (offline-safe `pub outdated`).
Directory _emptyPackage() {
  final root = Directory.systemTemp.createTempSync('deps_test.');
  File('${root.path}/pubspec.yaml')
      .writeAsStringSync('name: pkg\nenvironment:\n  sdk: ^3.13.0\n');
  return root;
}

void main() {
  group('parseOutdatedJson', () {
    test('clean entries yield no findings', () {
      expect(parseOutdatedJson(_clean), isEmpty);
      expect(parseOutdatedJson('{"packages": []}'), isEmpty);
    });

    test('flags discontinued, retracted, and advisory packages', () {
      final findings = parseOutdatedJson(_flagged);
      expect(findings.map((f) => f.package), ['old', 'gone', 'bad', 'bad']);
      expect(findings[0].message, contains('replaced by new_pkg'));
      expect(findings[1].message, contains('discontinued'));
      expect(findings[2].message, contains('retracted'));
      expect(findings[3].message, contains('advisory'));
    });

    test('skips malformed entries, fails closed on bad shapes', () {
      expect(
        parseOutdatedJson('{"packages": [42, {"package": 7}, "x"]}'),
        isEmpty,
      );
      expect(() => parseOutdatedJson('not json'), throwsArgumentError);
      expect(() => parseOutdatedJson('{"nope": []}'), throwsArgumentError);
      expect(() => parseOutdatedJson('[]'), throwsArgumentError);
    });
  });

  group('runDepAudit', () {
    test('empty package passes offline', () {
      final root = _emptyPackage();
      try {
        final result = runDepAudit(root.path);
        expect(result.passed, isTrue);
        expect(result.findings, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });

  group('check --dep-audit', () {
    test('clean package exits 0, missing target exits 2', () {
      final root = _emptyPackage();
      try {
        expect(check(['--dep-audit', root.path]), isZero);
        expect(check(['--dep-audit']), 2);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
