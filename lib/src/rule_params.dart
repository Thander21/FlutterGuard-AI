// Shared self-load for parameterized rules (SYS-CAL-003 R2-5).
//
// FG-BAN-018, FG-LOG-019, and later configurable gates discover
// the nearest flutterguard.yaml through here, so discovery,
// section lookup, and except-key semantics stay identical across
// rules. Lenient by contract (SYS-CLI-001a §5): anything missing
// or malformed degrades to empty — config problems are never
// file verdicts.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:yaml/yaml.dart';

import 'ast/rule_violation.dart';
import 'util.dart';

/// A loaded config section: the raw value plus its base directory.
class RuleSection {
  const RuleSection(this.value, {this.baseDir = ''});

  /// Raw section value (null when the config is missing,
  /// unreadable, unparseable, or lacks the section).
  final dynamic value;

  /// Forward-slash config directory anchoring except globs.
  final String baseDir;

  /// Loads [section] of the nearest config governing [target].
  /// Never throws on config problems.
  static RuleSection load(String target, String section) {
    final configPath = findConfig(target);
    if (configPath == null) return const RuleSection(null);
    dynamic doc;
    try {
      doc = loadYaml(File(configPath).readAsStringSync());
    } catch (_) {
      return const RuleSection(null);
    }
    if (doc is! Map) return const RuleSection(null);
    final dir = configPath.replaceAll(r'\', '/');
    final idx = dir.lastIndexOf('/');
    return RuleSection(
      doc[section],
      baseDir: idx < 0 ? '' : dir.substring(0, idx),
    );
  }
}

/// A flat `{names?, except?, message?}` section shared by the
/// name-list rules (FG-LOG-019, FG-TOK-020, FG-I18N-021): one
/// schema, one loader, one entry runner — the per-rule config
/// classes it replaces paired at 0.99+, so they were healed
/// away (SYS-CAL-001 gate-4 re-ratification).
class FlatRuleConfig {
  const FlatRuleConfig({
    this.names = const {},
    this.except = const [],
    this.message,
    this.baseDir = '',
    this.enabled = true,
  });

  const FlatRuleConfig.disabled()
    : names = const {},
      except = const [],
      message = null,
      baseDir = '',
      enabled = false;

  /// Raw configured names (rule-interpreted: symbols, widgets,
  /// or `Type`/`Type.ctor` extras).
  final Set<String> names;

  /// Glob list silencing the rule (`*`, `?`, full-segment `**`).
  final List<String> except;

  /// Project guidance surfaced in violations.
  final String? message;

  /// Forward-slash config directory anchoring except globs.
  final String baseDir;

  /// False when the section is missing or malformed and the rule
  /// defaults off (silent).
  final bool enabled;

  /// Loads [section] of the nearest config governing [target],
  /// reading raw names from [namesKey]. A present map — even
  /// empty — enables; anything else enables iff [defaultOn].
  /// Malformed fields degrade leniently (defaults still flag).
  static FlatRuleConfig load(
    String target,
    String section,
    String namesKey, {
    bool defaultOn = false,
  }) {
    final found = RuleSection.load(target, section);
    final raw = found.value;
    if (raw is! Map) {
      return defaultOn
          ? FlatRuleConfig(baseDir: found.baseDir)
          : const FlatRuleConfig.disabled();
    }
    final names = <String>{};
    final rawNames = raw[namesKey];
    if (rawNames is List) {
      for (final name in rawNames) {
        if (name is String && name.isNotEmpty) names.add(name);
      }
    }
    final except = <String>[];
    final rawExcept = raw['except'];
    if (rawExcept is List) {
      for (final glob in rawExcept) {
        if (glob is String) except.add(glob);
      }
    }
    final message = raw['message'];
    return FlatRuleConfig(
      names: names,
      except: except,
      message: message is String ? message : null,
      baseDir: found.baseDir,
    );
  }
}

/// Path key for except matching: config-relative when the file sits
/// under [baseDir], absolute otherwise.
String exceptKey(String path, String baseDir) {
  final abs = File(path).absolute.path.replaceAll(r'\', '/');
  if (baseDir.isNotEmpty && abs.startsWith('$baseDir/')) {
    return abs.substring(baseDir.length + 1);
  }
  return abs;
}

/// True when any glob in [globs] matches [fileKey].
bool isExcepted(List<String> globs, String fileKey) {
  for (final glob in globs) {
    if (globMatches(glob, fileKey)) return true;
  }
  return false;
}

/// A loaded list-shaped section plus its base directory. Shared
/// by the entry-list rules (FG-BAN-018, FG-LYR-024), whose
/// config shells paired at 0.97+ before the heal (SYS-CAL-001
/// gate-7 re-ratification).
class RuleListConfig<T> {
  const RuleListConfig(this.items, {this.baseDir = ''});

  final List<T> items;

  /// Forward-slash config directory anchoring file globs.
  final String baseDir;

  /// Loads [section] of the nearest config governing [target],
  /// parsing each item with [parseItem] and skipping malformed
  /// ones. Silent-empty on any problem — config problems are
  /// never file verdicts (SYS-CLI-001a §5).
  static RuleListConfig<T> load<T>(
    String target,
    String section,
    T? Function(dynamic item) parseItem,
  ) {
    final found = RuleSection.load(target, section);
    final raw = found.value;
    if (raw is! List) {
      return RuleListConfig<T>(<T>[], baseDir: found.baseDir);
    }
    final items = <T>[];
    for (final item in raw) {
      final parsed = parseItem(item);
      if (parsed != null) items.add(parsed);
    }
    return RuleListConfig<T>(items, baseDir: found.baseDir);
  }
}

/// String list at [key] of map [item] (null when [key] is
/// missing or not a string list).
List<String>? stringListField(Map item, String key) {
  final raw = item[key];
  if (raw is! List) return null;
  final out = <String>[];
  for (final value in raw) {
    if (value is! String) return null;
    out.add(value);
  }
  return out;
}

/// Parses [path], runs [scan] over the unit, and returns
/// line-sorted findings. Shared scan tail so per-rule entries
/// stay too small to twin.
List<V> scanTarget<V extends RuleViolation>(
  String path,
  List<V> Function(CompilationUnit unit, LineInfo info) scan,
) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  return scan(result.unit, result.lineInfo)
    ..sort((a, b) => a.line.compareTo(b.line));
}

/// Runs one flat name-list rule over [path]: discovers the section
/// (or uses injected [config]), applies the except gate, unions
/// [defaults] with configured names, and runs [scan]. Findings
/// sort by line. Shared entry point so the per-rule entries stay
/// too small to twin (SYS-CAL-001 gate-4 re-ratification).
List<V> runFlatRule<V extends RuleViolation>(
  String path, {
  required FlatRuleConfig? config,
  required String section,
  required String namesKey,
  required Set<String> defaults,
  required bool defaultOn,
  required List<V> Function(Set<String> names, String? message) scan,
}) {
  final loaded =
      config ??
      FlatRuleConfig.load(path, section, namesKey, defaultOn: defaultOn);
  if (!loaded.enabled) return const [];
  if (isExcepted(loaded.except, exceptKey(path, loaded.baseDir))) {
    return const [];
  }
  return scan({...defaults, ...loaded.names}, loaded.message)
    ..sort((a, b) => a.line.compareTo(b.line));
}
