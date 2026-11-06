// Shared-primitive tests (lib/src/util.dart): config discovery walks
// (see also test/config_test.dart, which pins discovery through the
// barrel) and the v1 glob matcher serving `except` lists.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('globMatches', () {
    test('matches exact paths and star segments', () {
      expect(globMatches('a.dart', 'a.dart'), isTrue);
      expect(globMatches('a.dart', 'b.dart'), isFalse);
      expect(globMatches('lib/*.dart', 'lib/x.dart'), isTrue);
      expect(globMatches('lib/*.dart', 'lib/a/x.dart'), isFalse);
      expect(globMatches('a?c.dart', 'abc.dart'), isTrue);
      expect(globMatches('a?c.dart', 'ac.dart'), isFalse);
    });

    test('crosses segments only on double star', () {
      expect(globMatches('lib/**', 'lib/x.dart'), isTrue);
      expect(globMatches('lib/**', 'lib/a/b.dart'), isTrue);
      expect(globMatches('lib/**', 'other/x.dart'), isFalse);
      expect(globMatches('**/notify.dart', 'a/b/notify.dart'), isTrue);
      expect(globMatches('**/notify.dart', 'notify.dart'), isTrue);
      expect(globMatches('service/**', 'service/notify.dart'), isTrue);
    });
  });

  group('collectScannableFiles', () {
    test('collects scoped extensions, skips the rest', () {
      final root = Directory.systemTemp.createTempSync('collect_test.');
      try {
        File('${root.path}/a.dart').writeAsStringSync('void main() {}\n');
        File('${root.path}/b.arb').writeAsStringSync('{}\n');
        File('${root.path}/c.txt').writeAsStringSync('x\n');
        final files = collectScannableFiles(
          root.path,
          extensions: const {'.dart', '.arb'},
        );
        expect(files.map((f) => f.split('/').last), ['a.dart', 'b.arb']);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('single non-matching file yields empty, missing throws', () {
      final root = Directory.systemTemp.createTempSync('collect_test.');
      try {
        File('${root.path}/c.txt').writeAsStringSync('x\n');
        expect(
          collectScannableFiles(root.path, extensions: const {'.dart'}),
          isEmpty,
        );
        expect(
          collectScannableFiles(
            '${root.path}/c.txt',
            extensions: const {'.dart', '.arb'},
          ),
          isEmpty,
        );
        expect(
          () => collectScannableFiles(
            '${root.path}/nope',
            extensions: const {'.dart'},
          ),
          throwsArgumentError,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('collects basename prefixes (.env*)', () {
      final root = Directory.systemTemp.createTempSync('collect_test.');
      try {
        File('${root.path}/.env').writeAsStringSync('A=1\n');
        File('${root.path}/.env.local').writeAsStringSync('A=1\n');
        File('${root.path}/a.dart').writeAsStringSync('void main() {}\n');
        File('${root.path}/notes.txt').writeAsStringSync('x\n');
        final files = collectScannableFiles(
          root.path,
          extensions: const {'.dart'},
          namePrefixes: const {'.env'},
        );
        expect(files.map((f) => f.split('/').last), [
          '.env',
          '.env.local',
          'a.dart',
        ]);
        expect(
          collectScannableFiles(
            '${root.path}/.env.local',
            extensions: const {'.dart'},
            namePrefixes: const {'.env'},
          ).map((f) => f.split('/').last),
          ['.env.local'],
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('collects exact basenames (pubspec.yaml)', () {
      final root = Directory.systemTemp.createTempSync('collect_test.');
      try {
        File('${root.path}/pubspec.yaml').writeAsStringSync('name: x\n');
        File('${root.path}/other.yaml').writeAsStringSync('x: 1\n');
        File('${root.path}/pubspec.yaml.bak').writeAsStringSync('name: x\n');
        final files = collectScannableFiles(
          root.path,
          extensions: const {'.dart'},
          names: const {'pubspec.yaml'},
        );
        expect(files.map((f) => f.split('/').last), ['pubspec.yaml']);
        expect(
          collectScannableFiles(
            '${root.path}/pubspec.yaml',
            extensions: const {'.dart'},
            names: const {'pubspec.yaml'},
          ).map((f) => f.split('/').last),
          ['pubspec.yaml'],
        );
        expect(
          collectScannableFiles(
            '${root.path}/other.yaml',
            extensions: const {'.dart'},
            names: const {'pubspec.yaml'},
          ),
          isEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('collectDartFiles stays dart-only (delegate parity)', () {
      final root = Directory.systemTemp.createTempSync('collect_test.');
      try {
        File('${root.path}/a.dart').writeAsStringSync('void main() {}\n');
        File('${root.path}/b.arb').writeAsStringSync('{}\n');
        expect(collectDartFiles(root.path).map((f) => f.split('/').last), [
          'a.dart',
        ]);
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });

  group('mirrorTestFor', () {
    test('maps lib files to mirror tests', () {
      expect(mirrorTestFor('lib/a.dart'), 'test/a_test.dart');
      expect(mirrorTestFor('lib/foo/bar.dart'), 'test/foo/bar_test.dart');
      expect(
        mirrorTestFor('pkg/lib/foo/bar.dart'),
        'pkg/test/foo/bar_test.dart',
      );
      expect(
        mirrorTestFor('/repo/lib/foo/bar.dart'),
        '/repo/test/foo/bar_test.dart',
      );
      expect(
        mirrorTestFor(r'C:\repo\lib\foo\bar.dart'),
        'C:/repo/test/foo/bar_test.dart',
      );
    });

    test('returns null outside the mapping', () {
      expect(mirrorTestFor('test/a_test.dart'), isNull);
      expect(mirrorTestFor('lib/a_test.dart'), isNull);
      expect(mirrorTestFor('lib/a.txt'), isNull);
      expect(mirrorTestFor('tool/a.dart'), isNull);
      expect(mirrorTestFor('a.dart'), isNull);
    });
  });
}
