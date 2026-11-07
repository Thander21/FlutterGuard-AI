// LicenseGuard: pub-cache license classification vs a deny list.
import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

const _texts = {
  'MIT': 'Permission is hereby granted, free of charge, to any person.',
  'Apache-2.0': 'Apache License\nVersion 2.0, January 2004.',
  'BSD-3-Clause': 'Redistribution and use in source and binary forms. Neither the name of the authors.',
  'BSD-2-Clause': 'Redistribution and use in source and binary forms.',
  'GPL-3.0-only': 'GNU GENERAL PUBLIC LICENSE\nVersion 3, 29 June 2007.',
  'GPL-2.0-only': 'GNU GENERAL PUBLIC LICENSE\nVersion 2, June 1991.',
  'LGPL-3.0-only': 'GNU LESSER GENERAL PUBLIC LICENSE\nVersion 3.',
  'LGPL-2.1-only': 'GNU LESSER GENERAL PUBLIC LICENSE\nVersion 2.1.',
  'AGPL-3.0-only': 'GNU AFFERO GENERAL PUBLIC LICENSE\nVersion 3.',
  'MPL-2.0': 'Mozilla Public License\nVersion 2.0.',
  'ISC': 'Permission to use, copy, modify, and/or distribute this software.',
  'Unlicense': 'This is free and unencumbered software released.',
  'CC0-1.0': 'CC0 1.0 Universal Public Domain Dedication.',
  'EPL-2.0': 'Eclipse Public License\nVersion 2.0.',
};

/// Stages `$root/pkg` (pubspec + lock for [hosted]) plus a fake pub
/// cache with [licenses] (`{dir-name: text}`).
Directory _stage({
  required List<String> hosted,
  required Map<String, String> licenses,
}) {
  final root = Directory.systemTemp.createTempSync('licenses_test.');
  final lock = StringBuffer('packages:\n');
  for (final package in hosted) {
    lock.writeln('  $package:\n    source: hosted\n    version: "1.0.0"');
  }
  File('${root.path}/pkg/pubspec.yaml').createSync(recursive: true);
  File('${root.path}/pkg/pubspec.yaml').writeAsStringSync('name: pkg\n');
  File('${root.path}/pkg/pubspec.lock').writeAsStringSync(lock.toString());
  for (final entry in licenses.entries) {
    final dir = Directory('${root.path}/cache/hosted/pub.dev/${entry.key}');
    dir.createSync(recursive: true);
    File('${dir.path}/LICENSE').writeAsStringSync(entry.value);
  }
  return root;
}

void main() {
  group('classifyLicenses', () {
    test('recognizes the v0 SPDX set', () {
      _texts.forEach((id, text) {
        expect(
          classifyLicenses([text]),
          contains(id),
          reason: '$id must classify',
        );
      });
    });

    test('unknown text classifies to nothing', () {
      expect(
        classifyLicenses(['All rights reserved. Buy a license.']),
        isEmpty,
      );
      expect(classifyLicenses([]), isEmpty);
    });
  });

  group('runLicenseAudit', () {
    test('passes allowed licenses, flags denied ones', () {
      final root = _stage(
        hosted: ['mitpkg', 'gplpkg'],
        licenses: {
          'mitpkg-1.0.0': _texts['MIT']!,
          'gplpkg-1.0.0': _texts['GPL-3.0-only']!,
        },
      );
      try {
        final result = runLicenseAudit(
          '${root.path}/pkg',
          deny: const {'GPL'},
          pubCache: '${root.path}/cache',
        );
        expect(result.passed, isFalse);
        expect(result.findings.map((f) => f.package), ['gplpkg']);
        expect(result.findings.single.message, contains('GPL-3.0-only'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('deny substrings catch license families', () {
      final root = _stage(
        hosted: ['lgplpkg'],
        licenses: {'lgplpkg-1.0.0': _texts['LGPL-2.1-only']!},
      );
      try {
        final result = runLicenseAudit(
          '${root.path}/pkg',
          deny: const {'GPL'},
          pubCache: '${root.path}/cache',
        );
        expect(result.findings.map((f) => f.package), ['lgplpkg']);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('dual licenses pass on any acceptable twin', () {
      final root = _stage(
        hosted: ['dualpkg'],
        licenses: {
          'dualpkg-1.0.0': '${_texts['MIT']!}\n---\n${_texts['GPL-3.0-only']!}',
        },
      );
      try {
        final result = runLicenseAudit(
          '${root.path}/pkg',
          deny: const {'GPL'},
          pubCache: '${root.path}/cache',
        );
        expect(result.findings, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('unknown licenses fail closed unless pinned', () {
      final root = _stage(
        hosted: ['mystery'],
        licenses: {'mystery-1.0.0': 'Custom license. Ask legal.'},
      );
      try {
        final closed = runLicenseAudit(
          '${root.path}/pkg',
          deny: const {'GPL'},
          pubCache: '${root.path}/cache',
        );
        expect(closed.findings.map((f) => f.package), ['mystery']);
        expect(closed.findings.single.message, contains('Unrecognized'));
        final pinned = runLicenseAudit(
          '${root.path}/pkg',
          deny: const {'GPL'},
          allowPkgs: const {'mystery': 'LicenseRef-Legal'},
          pubCache: '${root.path}/cache',
        );
        expect(pinned.findings, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('missing cache entries and license files fail closed', () {
      final root = _stage(hosted: ['gone'], licenses: {});
      try {
        final result = runLicenseAudit(
          '${root.path}/pkg',
          deny: const {'GPL'},
          pubCache: '${root.path}/cache',
        );
        expect(result.findings.map((f) => f.package), ['gone']);
        expect(result.findings.single.message, contains('pub cache'));
      } finally {
        root.deleteSync(recursive: true);
      }
      final bare = _stage(hosted: ['bare'], licenses: {});
      try {
        Directory('${bare.path}/cache/hosted/pub.dev/bare-1.0.0')
            .createSync(recursive: true);
        final result = runLicenseAudit(
          '${bare.path}/pkg',
          deny: const {'GPL'},
          pubCache: '${bare.path}/cache',
        );
        expect(result.findings.single.message, contains('no license file'));
      } finally {
        bare.deleteSync(recursive: true);
      }
    });

    test('missing lockfiles and non-hosted deps pass silently', () {
      final root = Directory.systemTemp.createTempSync('licenses_test.');
      try {
        Directory('${root.path}/pkg').createSync();
        File('${root.path}/pkg/pubspec.yaml').writeAsStringSync('name: pkg\n');
        expect(
          runLicenseAudit(
            '${root.path}/pkg',
            deny: const {'GPL'},
            pubCache: '${root.path}/cache',
          ).findings,
          isEmpty,
        );
        File('${root.path}/pkg/pubspec.lock').writeAsStringSync(
          'packages:\n  local:\n    source: path\n    version: "0.0.0"\n',
        );
        expect(
          runLicenseAudit(
            '${root.path}/pkg',
            deny: const {'GPL'},
            pubCache: '${root.path}/cache',
          ).findings,
          isEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });

  group('resolvePubCache', () {
    test('override wins, default smells like a pub cache', () {
      expect(resolvePubCache(override: '/tmp/cache'), '/tmp/cache');
      expect(resolvePubCache().toLowerCase(), matches(RegExp('pub[/-]cache')));
    });
  });

  group('check --license-audit', () {
    test('missing deny list exits 2', () async {
      final root = Directory.systemTemp.createTempSync('licenses_test.');
      try {
        Directory('${root.path}/pkg').createSync();
        File('${root.path}/pkg/pubspec.yaml').writeAsStringSync('name: pkg\n');
        expect(await check(['--license-audit', '${root.path}/pkg']), 2);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('denied package fails end to end (subprocess)', () {
      final root = _stage(
        hosted: ['gplpkg'],
        licenses: {'gplpkg-1.0.0': _texts['GPL-3.0-only']!},
      );
      try {
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('licenses:\n  deny: [GPL]\n');
        final result = Process.runSync(
          'dart',
          [
            'run',
            'bin/flutterguard.dart',
            'check',
            '--license-audit',
            '--json',
            '${root.path}/pkg',
          ],
          workingDirectory: Directory.current.path,
          environment: {
            ...Platform.environment,
            'PUB_CACHE': '${root.path}/cache',
          },
        );
        expect(result.exitCode, 1);
        final decoded =
            jsonDecode(result.stdout as String) as Map<String, dynamic>;
        final errors = decoded['errors'] as List;
        expect(
          errors.any(
            (e) => (e as Map)['error'].toString().contains('licenses: gplpkg'),
          ),
          isTrue,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });
  });
}
