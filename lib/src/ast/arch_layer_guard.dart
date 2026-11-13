// FG-ARCH-003: forbid persistence/network imports in widget files.
//
// A view widget must delegate data access to a repository or provider;
// importing a database or HTTP client directly couples the UI layer to
// infrastructure. Parsing only (no type resolution), so vectors need no
// dependencies. Layer detection is content-based: a file that declares a
// widget class is the UI layer (paths are ignored, so golden vectors in
// benchmark/vectors/ grade like any project file).

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Persistence/network packages a widget file must never touch.
///
/// Closed v0 list: the database and HTTP clients named in the rule spec.
const archLayerDenyList = <String>{
  'drift',
  'sqlite3',
  'sqflite',
  'floor',
  'supabase',
  'supabase_flutter',
  'dio',
  'http',
};

/// Framework widget superclasses that mark a file as UI layer.
///
/// Custom widget bases match by the `Widget` suffix instead (see
/// [isWidgetTypeName], shared with FG-CTX-006).
const widgetSuperclassNames = <String>{
  'StatelessWidget',
  'StatefulWidget',
  'ConsumerWidget',
  'ConsumerStatefulWidget',
  'HookWidget',
  'HookConsumerWidget',
};

/// True when [name] is a known widget type or ends in `Widget`.
bool isWidgetTypeName(String name) =>
    widgetSuperclassNames.contains(name) || name.endsWith('Widget');

/// A single FG-ARCH-003 violation.
class ArchLayerViolation implements RuleViolation {
  const ArchLayerViolation({required this.line, required this.message});

  /// 1-based line number of the offending import/export directive.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ARCH-003 violation found.
List<ArchLayerViolation> analyzeArchFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ArchLayerGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations.toList()..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags denylisted package imports/exports in widget files.
///
/// Scope (v0): the file is UI when any class extends a known widget
/// superclass (or any superclass ending in `Widget`); every denylisted
/// `package:` import or export in such a file is flagged, except an
/// import whose `show`-listed or prefixed names are referenced only
/// in catch `on` type positions (R3 carve-out). Relative imports are
/// never tracked, and files without a widget class are always clean.
class ArchLayerGuard extends RecursiveAstVisitor<void> {
  ArchLayerGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ArchLayerViolation> _pending = [];
  final List<ImportDirective> _pendingImports = [];
  var _hasWidget = false;

  /// Violations to report: pending directives plus uncarved imports,
  /// only when UI was detected.
  List<ArchLayerViolation> get violations {
    if (!_hasWidget) return const [];
    final out = _pending.toList();
    for (final node in _pendingImports) {
      final package = _packageName(node.uri.stringValue);
      if (package != null && !_carved(node)) {
        out.add(
          ArchLayerViolation(
            line: _lineInfo.getLocation(node.offset).lineNumber,
            message:
                "UI file imports '$package'; "
                'move data access to the data layer (repository/provider)',
          ),
        );
      }
    }
    return out;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_isWidgetSuperclass(node.extendsClause?.superclass)) {
      _hasWidget = true;
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    final package = _packageName(node.uri.stringValue);
    if (package != null && archLayerDenyList.contains(package)) {
      _pendingImports.add(node);
    }
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkDirective(node.uri.stringValue, node.offset);
    super.visitExportDirective(node);
  }

  void _checkDirective(String? uri, int offset) {
    final package = _packageName(uri);
    if (package != null && archLayerDenyList.contains(package)) {
      _pending.add(
        ArchLayerViolation(
          line: _lineInfo.getLocation(offset).lineNumber,
          message:
              "UI file imports '$package'; "
              'move data access to the data layer (repository/provider)',
        ),
      );
    }
  }
}

/// True when a denylisted [node] is referenced only in catch `on`
/// type positions (R3 carve-out, CAL-004 Q6).
///
/// Only attributable shapes carve: `show`-listed names (minus `hide`)
/// and `as` prefixes, each with at least one use and every use in an
/// `on` head position. Bare imports stay flagged — their names are
/// unattributable parse-only (known gap: the two field FPs). Unused
/// names still flag (dead import, fail-closed). Exports never reach
/// here (always flagged).
bool _carved(ImportDirective node) {
  final shown = <String>{};
  final hidden = <String>{};
  for (final combinator in node.combinators) {
    if (combinator is ShowCombinator) {
      shown.addAll(combinator.shownNames.map((n) => n.name));
    } else if (combinator is HideCombinator) {
      hidden.addAll(combinator.hiddenNames.map((n) => n.name));
    }
  }
  shown.removeAll(hidden);
  final prefix = node.prefix?.name;
  if (shown.isEmpty && prefix == null) return false;
  final root = node.root;
  if (root is! CompilationUnit) return false;
  final uses = _NameUseCollector();
  root.accept(uses);
  if (shown.isNotEmpty) {
    for (final name in shown) {
      final occ = uses.bare[name] ?? const <bool>[];
      if (occ.isEmpty || occ.any((onHead) => !onHead)) return false;
    }
  }
  if (prefix != null) {
    final occ = <bool>[
      ...uses.bare[prefix] ?? const <bool>[],
      ...uses.prefixed[prefix] ?? const <bool>[],
    ];
    if (occ.isEmpty || occ.any((onHead) => !onHead)) return false;
  }
  return true;
}

/// Occurrence index of bare and prefixed names outside directives.
///
/// One walk per denylisted import (rare): every [SimpleIdentifier]
/// records whether it sits in a catch `on` head position, and every
/// [NamedType] records its head name the same way. Both are needed:
/// analyzer 14 models declaration/type names as [Token]s (never
/// visited as identifiers), so the `on` type itself only surfaces
/// through [NamedType]. Dotted types additionally record their
/// source prefix (the import-prefix reference is not visited
/// uniformly, so the prefix is read off the type source instead —
/// consistent with the identifier walk either way).
class _NameUseCollector extends RecursiveAstVisitor<void> {
  /// Bare-name occurrences: name to per-occurrence on-head flags.
  final bare = <String, List<bool>>{};

  /// Dotted-type prefixes: prefix to per-occurrence on-head flags.
  final prefixed = <String, List<bool>>{};

  @override
  void visitImportDirective(ImportDirective node) {
    // Combinators and prefixes declare, never use.
  }

  @override
  void visitExportDirective(ExportDirective node) {
    // Re-exports are not file-local references.
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    bare.putIfAbsent(node.name, () => []).add(_isOnHead(node));
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final parent = node.parent;
    final onHead = parent is CatchClause && parent.exceptionType == node;
    final lexeme = node.name.lexeme;
    bare.putIfAbsent(lexeme, () => []).add(onHead);
    final dotName = lexeme.lastIndexOf('.');
    if (dotName >= 0) {
      // Qualified head (`p.E`): the unqualified name counts too, so
      // `show E` + `as p` carves `on p.E` either way the token reads.
      bare.putIfAbsent(lexeme.substring(dotName + 1), () => []).add(onHead);
    }
    final head = node.toSource().split('<').first.trim();
    final dot = head.indexOf('.');
    if (dot > 0) {
      prefixed.putIfAbsent(head.substring(0, dot), () => []).add(onHead);
    }
    super.visitNamedType(node);
  }
}

/// True when [id] is the head name of a catch `on` type.
///
/// Walks up through qualified/type wrappers only; reaching the
/// [CatchClause] through its [exceptionType] is the only TRUE.
/// Import prefixes count via [ImportPrefixReference] (present in
/// `on p.E` regardless of visitation — the walk reads parents,
/// not visits).
bool _isOnHead(SimpleIdentifier id) {
  AstNode child = id;
  AstNode? current = id.parent;
  while (current != null && _isTypeWrapper(current)) {
    child = current;
    current = current.parent;
  }
  return current is CatchClause && current.exceptionType == child;
}

/// True for the nodes that can wrap a catch `on` head name:
/// qualified names, type annotations, and import prefixes.
bool _isTypeWrapper(AstNode node) =>
    node is PrefixedIdentifier ||
    node is NamedType ||
    node is ImportPrefixReference;

/// True when [superclass] names a widget base class.
bool _isWidgetSuperclass(NamedType? superclass) {
  if (superclass == null) return false;
  // toSource-based extraction avoids version-sensitive NamedType APIs.
  final source = superclass.toSource().split('<').first.trim();
  final name = source.contains('.') ? source.split('.').last : source;
  return isWidgetTypeName(name);
}

/// Package name of a `package:` URI, or null for any other scheme.
String? _packageName(String? uri) {
  if (uri == null || !uri.startsWith('package:')) return null;
  final rest = uri.substring('package:'.length);
  final slash = rest.indexOf('/');
  if (slash <= 0) return null;
  return rest.substring(0, slash);
}
