// FG-CTX-006: forbid stored BuildContext.
//
// A service, repository, or bloc that stores BuildContext in a field or
// global couples business logic to the widget tree: untestable without
// a widget harness, leaking Element subtrees after navigation.
// Parameters, returns, locals, and casts only flow context through and
// stay clean. Parsing only (no type resolution), so vectors need no
// dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

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

/// Flags stored BuildContext.
///
/// Scope (R2-3): fields and top-level variables whose type mentions
/// `BuildContext` flag in every scope, UI included. Signatures,
/// locals, casts, and type arguments flow context through and stay
/// clean, as do function-typed fields (callbacks, not storage).
class ContextScopeGuard extends RecursiveAstVisitor<void> {
  ContextScopeGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ContextScopeViolation> violations = [];

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    _flagStored(node.fields.type);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _flagStored(node.variables.type);
    super.visitTopLevelVariableDeclaration(node);
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
  void visitGenericFunctionType(GenericFunctionType node) {
    // Callbacks flow context through; they never store it (R2-3).
  }

  @override
  void visitNamedType(NamedType node) {
    if (node.name.lexeme == 'BuildContext') {
      offsets.add(node.offset);
    }
    super.visitNamedType(node);
  }
}
