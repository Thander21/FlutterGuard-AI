// Schema-v2 config loader (SYS-CLI-001a §2): walk-up discovery of
// `flutterguard.yaml` plus per-rule toggles. Shared by `check` and
// the lite loop; `grade` always runs the full registry (it validates
// the rules themselves).
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'rules.dart';

/// Config file name discovered by walking up from the target.
const configFileName = 'flutterguard.yaml';

/// Nearest config walking up from [target] (a file or directory),
/// or null when none exists up to the filesystem root.
String? findConfig(String target) {
  var dir = _startDir(target);
  while (true) {
    final candidate = '$dir/$configFileName';
    if (File(candidate).existsSync()) return candidate;
    if (dir == '/' || RegExp(r'^[A-Za-z]:/?$').hasMatch(dir)) return null;
    final idx = dir.lastIndexOf('/');
    if (idx < 0) return null;
    dir = idx == 0 ? '/' : dir.substring(0, idx);
  }
}

/// [analyzers] minus the rules disabled for [target] by the nearest
/// config. No config, unparseable YAML, non-map `rules`,
/// non-boolean values, and unknown ids all default to enabled: the
/// gate never silently shrinks (typos surface as unexpected
/// findings). The `all` key resets the default (`all: false` +
/// explicit `true`s allow-lists).
List<RuleAnalyzer> enabledAnalyzers(
  String target,
  List<RuleAnalyzer> analyzers,
) {
  final config = _loadRules(target);
  if (config == null) return analyzers;
  return analyzers.where((rule) {
    return config.explicit[rule.id] ?? config.defaultEnabled;
  }).toList();
}

/// Parsed `rules` map: the default plus explicit per-rule values.
class _RulesConfig {
  const _RulesConfig({required this.defaultEnabled, required this.explicit});

  final bool defaultEnabled;
  final Map<String, bool> explicit;
}

/// Reads the `rules` map of the nearest config, or null when no
/// config applies. Never throws on config problems.
_RulesConfig? _loadRules(String target) {
  final config = findConfig(target);
  if (config == null) return null;
  dynamic doc;
  try {
    doc = loadYaml(File(config).readAsStringSync());
  } catch (_) {
    return null;
  }
  if (doc is! Map) return null;
  final rules = doc['rules'];
  if (rules is! Map) return null;
  var defaultEnabled = true;
  final all = rules['all'];
  if (all is bool) defaultEnabled = all;
  final explicit = <String, bool>{};
  rules.forEach((key, value) {
    if (key == 'all' || key is! String || value is! bool) return;
    explicit[key] = value;
  });
  return _RulesConfig(defaultEnabled: defaultEnabled, explicit: explicit);
}

/// Absolute, forward-slash directory to start discovery from: [target]
/// itself for directories, its parent for files.
String _startDir(String target) {
  final abs = File(target).absolute.path.replaceAll(r'\', '/');
  if (FileSystemEntity.isDirectorySync(target)) return abs;
  final idx = abs.lastIndexOf('/');
  return idx < 0 ? abs : abs.substring(0, idx);
}
