// DepAudit gate (SYS-CAL-003 R2-5 medium list).
//
// Runs `pub outdated --json` per package root under the target
// and flags discontinued, replaced, retracted, and
// advisory-affected dependencies. Merely behind-latest packages
// are maintenance, not gate failures, and never flag. Requires
// network (version listings live on the package host); without
// it the spawn fails and the gate exits 2 naming the cause —
// CI without network omits the flag.
import 'dart:convert';
import 'dart:io';

/// One package flagged by the audit.
class DepFinding {
  const DepFinding({required this.package, required this.message});

  /// Audited package name.
  final String package;

  /// Signal detail (discontinued/replaced/retracted/advisory).
  final String message;
}

/// Outcome of [runDepAudit] over one package root.
class DepAuditResult {
  const DepAuditResult({required this.root, required this.findings});

  /// Audited package directory.
  final String root;
  final List<DepFinding> findings;

  /// True when no package raised a signal.
  bool get passed => findings.isEmpty;
}

/// Parses `pub outdated --json` [stdout] into findings.
///
/// Throws [ArgumentError] on malformed JSON or shapes (fail
/// closed — unlike the analyzer step there is no exit-code
/// backstop, so a blind gate must say so loudly). Malformed
/// entries inside a well-formed list are skipped.
List<DepFinding> parseOutdatedJson(String stdout) {
  dynamic decoded;
  try {
    decoded = jsonDecode(stdout);
  } on FormatException catch (error) {
    throw ArgumentError('cannot parse pub outdated output: ${error.message}');
  }
  if (decoded is! Map || decoded['packages'] is! List) {
    throw ArgumentError(
      'cannot parse pub outdated output: missing packages list',
    );
  }
  final findings = <DepFinding>[];
  for (final entry in decoded['packages'] as List) {
    if (entry is! Map) continue;
    final package = entry['package'];
    if (package is! String) continue;
    if (entry['isDiscontinued'] == true) {
      final replacedBy = entry['replacedBy'];
      findings.add(
        DepFinding(
          package: package,
          message: replacedBy is String && replacedBy.isNotEmpty
              ? 'discontinued; replaced by $replacedBy'
              : 'discontinued',
        ),
      );
    }
    if (entry['isCurrentRetracted'] == true) {
      findings.add(
        DepFinding(package: package, message: 'current version retracted'),
      );
    }
    if (entry['isCurrentAffectedByAdvisory'] == true) {
      findings.add(
        DepFinding(
          package: package,
          message: 'current version has a security advisory',
        ),
      );
    }
  }
  return findings;
}

/// Runs `pub outdated --json` in [root] (a package directory).
/// Throws [ArgumentError] on spawn failure, non-zero exit, or
/// unparsable output.
DepAuditResult runDepAudit(String root) {
  ProcessResult result;
  try {
    result = Process.runSync(Platform.resolvedExecutable, [
      'pub',
      'outdated',
      '--json',
    ], workingDirectory: root);
  } on ProcessException catch (error) {
    throw ArgumentError('cannot run pub outdated: ${error.message}');
  }
  if (result.exitCode != 0) {
    throw ArgumentError('pub outdated failed: ${result.stderr}');
  }
  return DepAuditResult(
    root: root,
    findings: parseOutdatedJson(result.stdout as String),
  );
}
