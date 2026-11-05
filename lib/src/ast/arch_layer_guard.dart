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
/// `package:` import or export in such a file is flagged. Relative
/// imports are never tracked, and files without a widget class are
/// always clean.
class ArchLayerGuard extends RecursiveAstVisitor<void> {
  ArchLayerGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ArchLayerViolation> _pending = [];
  var _hasWidget = false;

  /// Violations to report: pending directives only when UI was detected.
  List<ArchLayerViolation> get violations => _hasWidget ? _pending : const [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_isWidgetSuperclass(node.extendsClause?.superclass)) {
      _hasWidget = true;
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    _checkDirective(node.uri.stringValue, node.offset);
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
