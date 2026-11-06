// FG-ASSET-030: pubspec assets must exist on disk.
//
// A declared asset that is missing compiles fine and crashes at
// runtime ("Unable to load asset"). Every entry under `flutter:
// assets:` must resolve to an existing file — or, with a trailing
// `/`, an existing directory — next to the analyzed pubspec.
// Pure-Dart pubspecs and unparseable YAML stay silent (fail-open);
// the vice-versa direction (undeclared files) is v0-deferred.
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'rule_violation.dart';

/// A single FG-ASSET-030 violation.
class AssetViolation implements RuleViolation {
  const AssetViolation({required this.line, required this.message});

  /// 1-based line number of the missing entry.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ASSET-030 violation found.
List<AssetViolation> analyzeAssetFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final dir = normalized.contains('/')
      ? normalized.substring(0, normalized.lastIndexOf('/'))
      : '.';
  YamlNode? doc;
  try {
    doc = loadYamlNode(File(path).readAsStringSync());
  } catch (_) {
    return const [];
  }
  if (doc is! YamlMap) return const [];
  final flutter = doc['flutter'];
  if (flutter is! YamlMap) return const [];
  final assets = flutter['assets'];
  if (assets is! YamlList) return const [];
  final violations = <AssetViolation>[];
  for (final entry in assets.nodes) {
    if (entry is! YamlScalar || entry.value is! String) continue;
    final declared = entry.value as String;
    if (_isAbsolute(declared)) continue;
    final missing = declared.endsWith('/')
        ? !Directory('$dir/$declared').existsSync()
        : !File('$dir/$declared').existsSync();
    if (missing) {
      violations.add(
        AssetViolation(
          line: entry.span.start.line + 1,
          message:
              "declared asset '$declared' is missing; "
              'add the file or drop the entry',
        ),
      );
    }
  }
  return violations..sort((a, b) => a.line.compareTo(b.line));
}

/// True for entries Flutter cannot mean package-relatively (POSIX
/// absolute or a Windows drive): skipped, never resolved outside
/// the package.
bool _isAbsolute(String entry) =>
    entry.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(entry);
