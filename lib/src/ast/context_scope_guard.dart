// FG-CTX-006: forbid BuildContext outside Widget/State.
//
// A service, repository, or bloc that takes or stores BuildContext couples
// business logic to the widget tree: untestable without a widget harness,
// leaking Element subtrees after navigation. Services must receive data,
// never context. Parsing only (no type resolution), so vectors need no
// dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'arch_layer_guard.dart' show isWidgetTypeName;
import 'rule_violation.dart';

/// A single FG-CTX-006 violation.
class ContextScopeViolation implements RuleViolation {
  const ContextScopeViolation({required this.line, required this.message});

  /// 1-based line number of the offending BuildContext reference.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-CTX-006 violation found.
List<ContextScopeViolation> analyzeContextScopeFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ContextScopeGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags BuildContext bound outside the widget tree.
///
/// Scope (v0): any `BuildContext` type reference inside a class that is
/// not a Widget/State/UI-extension is flagged, as is every stored
/// position (fields in any class, top-level variables). Widget/State
/// bodies and top-level functions (explicit flow-through, the
/// FG-ASYNC-002 recipe shape) are always clean.
class ContextScopeGuard extends RecursiveAstVisitor<void> {
  ContextScopeGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ContextScopeViolation> violations = [];
  bool _inScope = false;
  bool _inUi = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final wasScope = _inScope;
    final wasUi = _inUi;
    _inScope = true;
    _inUi = _isUiClass(node.extendsClause?.superclass);
    super.visitClassDeclaration(node);
    _inScope = wasScope;
    _inUi = wasUi;
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final wasScope = _inScope;
    final wasUi = _inUi;
    _inScope = true;
    _inUi = false;
    super.visitMixinDeclaration(node);
    _inScope = wasScope;
    _inUi = wasUi;
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final wasScope = _inScope;
    final wasUi = _inUi;
    _inScope = true;
    _inUi = false;
    super.visitEnumDeclaration(node);
    _inScope = wasScope;
    _inUi = wasUi;
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final wasScope = _inScope;
    final wasUi = _inUi;
    _inScope = true;
    _inUi = _isUiExtension(node.onClause?.extendedType);
    super.visitExtensionDeclaration(node);
    _inScope = wasScope;
    _inUi = wasUi;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    // Stored context is flagged in every scope — except when the scope
    // rule already covers it, so service fields flag exactly once.
    if (!(_inScope && !_inUi)) {
      _flagStored(node.fields.type);
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _flagStored(node.variables.type);
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (node.name.lexeme == 'BuildContext' && _inScope && !_inUi) {
      _flag(
        node.offset,
        'BuildContext outside Widget/State; pass data instead of context',
      );
    }
    super.visitNamedType(node);
  }

  /// Flags BuildContext references in a stored type (field or global).
  void _flagStored(TypeAnnotation? type) {
    if (type == null) return;
    final collector = _StoredTypeCollector();
    type.accept(collector);
    for (final offset in collector.offsets) {
      _flag(
        offset,
        'BuildContext must not be stored; '
        'pass data instead of context',
      );
    }
  }

  void _flag(int offset, String message) {
    violations.add(
      ContextScopeViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message: message,
      ),
    );
  }
}

/// Collects BuildContext references inside one stored type annotation.
class _StoredTypeCollector extends RecursiveAstVisitor<void> {
  final List<int> offsets = [];

  @override
  void visitNamedType(NamedType node) {
    if (node.name.lexeme == 'BuildContext') {
      offsets.add(node.offset);
    }
    super.visitNamedType(node);
  }
}

/// True for Widget subclasses (set or `Widget` suffix) and exactly
/// `State`/`ConsumerState` (Bloc states stay out of scope by design).
bool _isUiClass(NamedType? superclass) {
  if (superclass == null) return false;
  final name = superclass.name.lexeme;
  return name == 'State' || name == 'ConsumerState' || isWidgetTypeName(name);
}

/// True for extensions on BuildContext, State, or a widget.
bool _isUiExtension(TypeAnnotation? extendedType) {
  if (extendedType is! NamedType) return false;
  final name = extendedType.name.lexeme;
  return name == 'BuildContext' ||
      name == 'State' ||
      name == 'ConsumerState' ||
      isWidgetTypeName(name);
}
