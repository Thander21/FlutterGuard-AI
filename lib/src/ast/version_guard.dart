// FG-VER-031: pubspec version must be semver.
//
// `version: 1.2` (a YAML float), `version: latest`, and
// `version: 1.2.3.4` all sail through editing and explode at
// publish or release-tag time. A present `version:` key must be
// a string shaped `X.Y.Z` with an optional `-pre`/`+build`
// suffix. A missing key stays silent (not every pubspec ships
// a version), and unparseable YAML fails open.
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'rule_violation.dart';

/// A single FG-VER-031 violation.
class VersionViolation implements RuleViolation {
  const VersionViolation({required this.line, required this.message});

  /// 1-based line number of the version entry.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// `X.Y.Z` with an optional `-pre`/`+build` suffix (the pub shape).
final _semver = RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$');

/// Analyzes [path] and returns every FG-VER-031 violation found.
List<VersionViolation> analyzeVersionFile(String path) {
  YamlNode? doc;
  try {
    doc = loadYamlNode(File(path).readAsStringSync());
  } catch (_) {
    return const [];
  }
  if (doc is! YamlMap || !doc.containsKey('version')) return const [];
  final version = doc.nodes['version'];
  final line = version == null ? 1 : version.span.start.line + 1;
  final value = version is YamlScalar ? version.value : version;
  if (value is String && _semver.hasMatch(value)) return const [];
  return [
    VersionViolation(
      line: line,
      message: "version '$value' is not semver X.Y.Z; use the '1.2.0' shape",
    ),
  ];
}
