// SYS-VIEW-001 lite contract: flags the LAY-004 vector, spares its
// .good twin, filters the full registry down to the viewport
// vocabulary, and detects the SDK through an injected PATH (the
// ambient machine is never asserted on).
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('runTier1Lite', () {
    test('flags the viewport vector, spares the .good twin', () {
      final bad = runTier1Lite('benchmark/vectors/TC-07_lay.bad.dart');
      expect(bad.findings, isNotEmpty);
      expect(bad.findings.every((f) => f.ruleId == 'FG-LAY-004'), isTrue);
      expect(bad.filesScanned, 1);
      expect(bad.errors, isEmpty);

      final good = runTier1Lite('benchmark/vectors/TC-07_lay.good.dart');
      expect(good.findings, isEmpty);
    });

    test('reports only the viewport vocabulary over a directory', () {
      final result = runTier1Lite('benchmark/vectors');
      expect(result.findings, isNotEmpty);
      expect(result.findings.every((f) => f.ruleId == 'FG-LAY-004'), isTrue);
      expect(result.filesScanned, greaterThanOrEqualTo(26));
      expect(
        result.errors,
        hasLength(1),
        reason: 'only the intentional TC-17 syntax error throws visitors',
      );
      expect(result.errors.single.file, endsWith('TC-17_syn.bad.dart'));
      expect(result.errors.single.error, contains('missing_identifier'));
    });

    test('empty directory is clean', () {
      final dir = Directory.systemTemp.createTempSync('tier1_lite_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final result = runTier1Lite(dir.path);
      expect(result.findings, isEmpty);
      expect(result.filesScanned, 0);
    });

    test('missing target throws', () {
      expect(() => runTier1Lite('no/such/dir'), throwsArgumentError);
    });

    test('carries the degraded-mode note and the SDK flag', () {
      final result = runTier1Lite('benchmark/vectors/TC-07_lay.good.dart');
      expect(result.sdkAvailable, isA<bool>());
      expect(result.note, contains('Tier-1-lite'));
    });
  });

  group('isFlutterSdkAvailable', () {
    test('finds a flutter executable on an injected PATH', () {
      final dir = Directory.systemTemp.createTempSync('tier1_sdk_');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final name in ['flutter', 'flutter.exe', 'flutter.bat']) {
        File('${dir.path}/$name').writeAsStringSync('');
      }
      final separator = Platform.isWindows ? ';' : ':';
      expect(
        isFlutterSdkAvailable(pathEnv: ' ${dir.path} $separator '),
        isTrue,
      );
    });

    test('misses on an empty or SDK-less PATH', () {
      final dir = Directory.systemTemp.createTempSync('tier1_nosdk_');
      addTearDown(() => dir.deleteSync(recursive: true));
      expect(isFlutterSdkAvailable(pathEnv: dir.path), isFalse);
      expect(isFlutterSdkAvailable(pathEnv: ''), isFalse);
    });

    test('skips config-disabled lite rules (SYS-CAL-002 P3-1)', () {
      final root = Directory.systemTemp.createTempSync('lite_test.');
      try {
        File('${root.path}/lay.dart').writeAsStringSync(
          File('benchmark/vectors/TC-07_lay.bad.dart').readAsStringSync(),
        );
        expect(runTier1Lite(root.path).findings, isNotEmpty);
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('version: 2\nrules:\n  FG-LAY-004: false\n');
        expect(runTier1Lite(root.path).findings, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
