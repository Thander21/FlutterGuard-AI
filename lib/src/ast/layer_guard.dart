// FG-LYR-024: layer direction rules.
//
// Layer erosion starts with one convenient import: a widget
// pulls the database package directly instead of going through
// the repository. File-scoped import/export denylists (`files`
// globs select the capped files, `deny_imports` globs match
// URI strings as written — no resolution) flag the leak. The
// rule self-loads its section from the nearest
// flutterguard.yaml; without the section it is silent. Parsing
// only (no type resolution).
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
import 'rule_violation.dart';

/// One layer rule: capped files, denied import URIs, and file
/// exceptions.
class LayerRule {
  const LayerRule({
    required this.files,
    required this.denyImports,
    this.except = const [],
    this.message,
  });

  /// Config-relative globs selecting the capped files.
  final List<String> files;

  /// URI globs denied in those files (matched as written).
  final List<String> denyImports;

  /// File globs exempting individual files.
  final List<String> except;

  /// Project guidance surfaced in the violation.
  final String? message;

  /// Parses one section entry (null when malformed — non-map,
  /// missing/empty glob lists, non-string entries, or a bad
  /// `except`, which skips the rule like FG-BAN-018 entries).
  static LayerRule? parse(dynamic item) {
    if (item is! Map) return null;
    final files = stringListField(item, 'files');
    final denyImports = stringListField(item, 'deny_imports');
    if (files == null || files.isEmpty) return null;
    if (denyImports == null || denyImports.isEmpty) return null;
    final rawExcept = item['except'];
    var except = const <String>[];
    if (rawExcept != null) {
      final parsed = stringListField(item, 'except');
      if (parsed == null) return null;
      except = parsed;
    }
    final message = item['message'];
    return LayerRule(
      files: files,
      denyImports: denyImports,
      except: except,
      message: message is String ? message : null,
    );
  }
}

/// A single FG-LYR-024 violation.
class LayerViolation implements RuleViolation {
  const LayerViolation({required this.line, required this.message});

  /// 1-based line number of the denied import/export.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-LYR-024 violation found.
///
/// [config] injects a section (tests); without it the nearest
/// `flutterguard.yaml` is discovered and loaded.
List<LayerViolation> analyzeLayerFile(
  String path, {
  RuleListConfig<LayerRule>? config,
}) {
  final loaded =
      config ?? RuleListConfig.load(path, 'layer_rules', LayerRule.parse);
  if (loaded.items.isEmpty) return const [];
  final fileKey = exceptKey(path, loaded.baseDir);
  final active = loaded.items
      .where(
        (rule) =>
            // Inclusion test through the same glob engine.
            isExcepted(rule.files, fileKey) &&
            !isExcepted(rule.except, fileKey),
      )
      .toList();
  if (active.isEmpty) return const [];
  return scanTarget(path, (unit, info) {
    final guard = LayerGuard(info, active);
    unit.accept(guard);
    return guard.violations;
  });
}

/// Flags denied import/export URIs (matched as written).
///
/// Combinators don't matter (URI-level match); `part`
/// directives are same-library and never match.
class LayerGuard extends RecursiveAstVisitor<void> {
  LayerGuard(this._lineInfo, this._rules);

  final LineInfo _lineInfo;
  final List<LayerRule> _rules;
  final List<LayerViolation> violations = [];

  @override
  void visitImportDirective(ImportDirective node) {
    _checkUri(node.uri.stringValue, node.offset);
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkUri(node.uri.stringValue, node.offset);
    super.visitExportDirective(node);
  }

  void _checkUri(String? uri, int offset) {
    if (uri == null) return;
    for (final rule in _rules) {
      if (!isExcepted(rule.denyImports, uri)) continue;
      final scope = rule.files.join(', ');
      final custom = rule.message;
      violations.add(
        LayerViolation(
          line: _lineInfo.getLocation(offset).lineNumber,
          message: custom == null || custom.isEmpty
              ? "import '$uri' violates layer rules ($scope)"
              : "import '$uri' violates layer rules ($scope): $custom",
        ),
      );
    }
  }
}
