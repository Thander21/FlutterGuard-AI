// LicenseGuard (SYS-CAL-003 R2-5 medium list): pub-cache license
// classification vs a deny list.
//
// Reads each hosted dependency's license text from the pub cache
// and enforces the project's `licenses.deny` policy. Unknown
// texts and missing license files fail closed (a package with no
// readable license is the riskiest kind); per-package pins
// (`allow_pkgs`) beat both the classifier and the deny list.
// Roots without a lockfile pass silently (unauditable — run
// `pub get` to audit them); path/git/sdk dependencies are out
// of scope (no cache entry exists to read).
import 'dart:io';

import 'package:yaml/yaml.dart';

/// One package flagged by the audit.
class LicenseFinding {
  const LicenseFinding({required this.package, required this.message});

  /// Audited package name.
  final String package;

  /// Verdict detail (denied id, unknown text, missing file/cache).
  final String message;
}

/// Outcome of [runLicenseAudit] over one package root.
class LicenseAuditResult {
  const LicenseAuditResult({required this.root, required this.findings});

  /// Audited package directory.
  final String root;
  final List<LicenseFinding> findings;

  /// True when every hosted dependency passed the policy.
  bool get passed => findings.isEmpty;
}

/// SPDX ids for [texts] (possibly several: dual-licensed texts
/// match twice; possibly none: unrecognized stays empty).
Set<String> classifyLicenses(List<String> texts) {
  final ids = <String>{};
  for (final text in texts) {
    final lower = text.toLowerCase();
    if (lower.contains('gnu affero general public license')) {
      ids.add('AGPL-3.0-only');
    }
    if (lower.contains('gnu lesser general public license')) {
      if (lower.contains('version 2.1')) {
        ids.add('LGPL-2.1-only');
      } else if (lower.contains('version 3')) {
        ids.add('LGPL-3.0-only');
      } else {
        ids.add('LGPL');
      }
    }
    if (lower.contains('gnu general public license')) {
      if (lower.contains('version 3')) {
        ids.add('GPL-3.0-only');
      } else if (lower.contains('version 2')) {
        ids.add('GPL-2.0-only');
      } else {
        ids.add('GPL');
      }
    }
    if (lower.contains('apache license') && lower.contains('version 2.0')) {
      ids.add('Apache-2.0');
    }
    if (lower.contains('permission is hereby granted, free of charge')) {
      ids.add('MIT');
    }
    if (lower.contains('redistribution and use in source and binary forms')) {
      ids.add(
        lower.contains('neither the name') ? 'BSD-3-Clause' : 'BSD-2-Clause',
      );
    }
    if (lower.contains('mozilla public license') &&
        lower.contains('version 2.0')) {
      ids.add('MPL-2.0');
    }
    if (lower.contains('and/or distribute this software')) {
      ids.add('ISC');
    }
    if (lower.contains('this is free and unencumbered software')) {
      ids.add('Unlicense');
    }
    if (lower.contains('cc0 1.0 universal')) {
      ids.add('CC0-1.0');
    }
    if (lower.contains('eclipse public license')) {
      ids.add(lower.contains('version 2.0') ? 'EPL-2.0' : 'EPL-1.0');
    }
  }
  return ids;
}

/// Pub cache root: [override] (tests), `PUB_CACHE`, or the
/// platform default (`~/.pub-cache`, `%LOCALAPPDATA%/Pub/Cache`
/// on Windows).
String resolvePubCache({String? override}) {
  if (override != null) return override;
  final env = Platform.environment['PUB_CACHE'];
  if (env != null && env.isNotEmpty) return env;
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null && local.isNotEmpty) {
      return '$local/Pub/Cache'.replaceAll(r'\', '/');
    }
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) return '$home/.pub-cache';
  return '.pub-cache';
}

/// Audits hosted dependencies of the package at [root] against
/// [deny] (case-insensitive deny substrings: `GPL` catches the
/// whole family). [allowPkgs] pins per-package ids, beating the
/// classifier and the deny list. [pubCache] injects the cache
/// root (tests); without it the ambient cache is read.
LicenseAuditResult runLicenseAudit(
  String root, {
  Set<String> deny = const {},
  Map<String, String> allowPkgs = const {},
  String? pubCache,
}) {
  final findings = <LicenseFinding>[];
  dynamic lock;
  try {
    lock = loadYaml(File('$root/pubspec.lock').readAsStringSync());
  } catch (_) {
    return LicenseAuditResult(root: root, findings: findings);
  }
  if (lock is! Map || lock['packages'] is! Map) {
    return LicenseAuditResult(root: root, findings: findings);
  }
  final cache = resolvePubCache(override: pubCache);
  final packages = (lock['packages'] as Map).keys.toList()..sort();
  for (final name in packages) {
    if (name is! String) continue;
    if (allowPkgs.containsKey(name)) continue;
    final spec = (lock['packages'] as Map)[name];
    if (spec is! Map || spec['source'] != 'hosted') continue;
    final version = spec['version'];
    if (version is! String) continue;
    final dir = _cacheDir(cache, name, version);
    if (dir == null) {
      findings.add(
        LicenseFinding(
          package: name,
          message: '$version is missing from the pub cache; run `pub get`',
        ),
      );
      continue;
    }
    final texts = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final base = entity.path
          .replaceAll(r'\', '/')
          .split('/')
          .last
          .toLowerCase();
      if (base.startsWith('license') ||
          base.startsWith('licence') ||
          base.startsWith('copying')) {
        String? text;
        try {
          text = entity.readAsStringSync();
        } catch (_) {
          // A concurrently-vanished file reads as absent (fail-open
          // per file; the package still fails closed without texts).
          text = null;
        }
        if (text != null) texts.add(text);
      }
    }
    if (texts.isEmpty) {
      findings.add(
        LicenseFinding(
          package: name,
          message: 'no license file in the pub cache',
        ),
      );
      continue;
    }
    final ids = classifyLicenses(texts);
    final ok = ids.where((id) => !_denied(id, deny)).toList();
    if (ok.isNotEmpty) continue;
    final denied = ids.where((id) => _denied(id, deny)).toList();
    if (denied.isNotEmpty) {
      findings.add(
        LicenseFinding(
          package: name,
          message: '${denied.join(', ')} denied by policy',
        ),
      );
    } else {
      findings.add(
        LicenseFinding(
          package: name,
          message: 'Unrecognized license text; verify manually or pin via allow_pkgs',
        ),
      );
    }
  }
  return LicenseAuditResult(root: root, findings: findings);
}

/// True when [id] matches a [deny] substring (case-insensitive).
bool _denied(String id, Set<String> deny) {
  final lower = id.toLowerCase();
  return deny.any((d) => d.isNotEmpty && lower.contains(d.toLowerCase()));
}

/// `$cache/hosted/<host>/<name>-<version>/`, defaulting to the
/// pub.dev host with a mirror fallback scan. Null when absent.
Directory? _cacheDir(String cache, String name, String version) {
  final slug = '$name-$version';
  final primary = Directory('$cache/hosted/pub.dev/$slug');
  if (primary.existsSync()) return primary;
  final hosted = Directory('$cache/hosted');
  if (!hosted.existsSync()) return null;
  for (final entity in hosted.listSync()) {
    if (entity is! Directory) continue;
    final candidate = Directory('${entity.path}/$slug');
    if (candidate.existsSync()) return candidate;
  }
  return null;
}
