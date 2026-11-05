// FG-BLOC-001: mandatory `isClosed` guard on async Cubit/Bloc emissions.
//
// An `emit` call reached after an `await` inside a `Cubit`/`Bloc` subclass
// must be preceded by the canonical guard `if (isClosed) return;`.
// Parsing only (no type resolution), so vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// A single FG-BLOC-001 violation.
class BlocEmitViolation implements RuleViolation {
  const BlocEmitViolation({required this.line, required this.message});

  /// 1-based line number of the offending `emit` call.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-BLOC-001 violation found.
List<BlocEmitViolation> analyzeBlocFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = BlocEmitGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations;
}

/// Flags `emit` calls reached after an `await` without an `isClosed` guard.
///
/// Scope (v0): only methods whose enclosing class extends `Cubit` or `Bloc`
/// (matched by superclass name, no type resolution), only top-level
/// statements of the method body, and only the canonical guard form
/// `if (isClosed) return;` (bare or brace-wrapped).
class BlocEmitGuard extends RecursiveAstVisitor<void> {
  BlocEmitGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<BlocEmitViolation> violations = [];
  bool _inBlocClass = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // toSource-based extraction avoids version-sensitive NamedType APIs.
    final superclass =
        node.extendsClause?.superclass.toSource().split('<').first.trim();
    final wasInBloc = _inBlocClass;
    if (superclass == 'Cubit' || superclass == 'Bloc') {
      _inBlocClass = true;
    }
    super.visitClassDeclaration(node);
    _inBlocClass = wasInBloc;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!_inBlocClass) return;
    final body = node.body;
    if (body is! BlockFunctionBody) return;
    var armed = false; // an `await` is pending without a guard
    for (final statement in body.block.statements) {
      if (_containsAwait(statement)) {
        armed = true;
        continue;
      }
      if (_isClosedGuard(statement)) {
        armed = false;
        continue;
      }
      for (final emit in _emitCalls(statement)) {
        if (armed) {
          final line = _lineInfo.getLocation(emit.offset).lineNumber;
          violations.add(BlocEmitViolation(
            line: line,
            message: 'emit() called after async gap without isClosed check',
          ));
        }
      }
    }
  }
}

/// True when [node] contains an `await` expression.
bool _containsAwait(AstNode node) {
  final finder = _AwaitFinder();
  node.accept(finder);
  return finder.found;
}

class _AwaitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
    super.visitAwaitExpression(node);
  }
}

/// True when [statement] is the canonical guard `if (isClosed) return;`.
bool _isClosedGuard(Statement statement) {
  if (statement is! IfStatement) return false;
  if (!_isIsClosedCheck(statement.expression)) return false;
  final branch = statement.thenStatement;
  if (branch is ReturnStatement) return true;
  return branch is Block &&
      branch.statements.length == 1 &&
      branch.statements.single is ReturnStatement;
}

/// True for `isClosed`, `this.isClosed`, or equivalent property reads.
bool _isIsClosedCheck(Expression expression) {
  if (expression is SimpleIdentifier) return expression.name == 'isClosed';
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name == 'isClosed';
  }
  if (expression is PropertyAccess) {
    return expression.propertyName.name == 'isClosed';
  }
  return false;
}

/// Every bare `emit(...)` call inside [node].
List<MethodInvocation> _emitCalls(AstNode node) {
  final collector = _EmitCollector();
  node.accept(collector);
  return collector.emits;
}

class _EmitCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> emits = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (node.methodName.name == 'emit' &&
        (target == null || target is ThisExpression)) {
      emits.add(node);
    }
    super.visitMethodInvocation(node);
  }
}
