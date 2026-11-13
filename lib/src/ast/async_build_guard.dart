// FG-BUILD-014: forbid fire-and-forget async work directly in build().
//
// build() runs per frame; a Future, Timer, socket, or .then chain
// placed directly in its body fires on every rebuild. Event handlers
// (closures) are legitimately async and stay clean. Parsing only (no
// type resolution), so vectors need no dependencies.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'build_scope.dart';
import 'rule_violation.dart';

/// Socket/client types whose creation in build() is flagged.
const asyncBuildSocketTypes = <String>{'HttpClient', 'Socket', 'WebSocket'};

/// Future chaining methods flagged on any target in build scope.
const asyncBuildChainMethods = <String>{'then', 'catchError', 'whenComplete'};

/// A single FG-BUILD-014 violation.
class AsyncBuildViolation implements RuleViolation {
  const AsyncBuildViolation({required this.line, required this.message});

  /// 1-based line number of the offending invocation.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-BUILD-014 violation found.
List<AsyncBuildViolation> analyzeAsyncBuildFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = AsyncBuildGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags async triggers directly in build scope.
///
/// Scope: `Widget`-typed or untyped `build()` methods and
/// `Widget`-returning functions. A trigger fires only at function
/// depth 1 (the build scope itself): anything nested in a closure,
/// local function, or nested method is an event handler or helper,
/// not direct build flow, and stays clean.
class AsyncBuildGuard extends RecursiveAstVisitor<void> {
  AsyncBuildGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<AsyncBuildViolation> violations = [];
  final List<(AstNode, ClassDeclaration?)> _scopes = [];
  final List<ClassDeclaration> _classes = [];

  void _push(AstNode scope, void Function() visit) {
    _scopes.add((scope, _classes.isEmpty ? null : _classes.last));
    visit();
    _scopes.removeLast();
  }

  /// True inside a directly-executing build scope (depth 1 + measured).
  /// Each scope carries its lexically enclosing class (null for
  /// top-level functions), captured at entry so local classes
  /// declared inside a scope cannot shift the attribution.
  bool get _inDirectBuildScope {
    if (_scopes.length != 1) return false;
    final (scope, owner) = _scopes.single;
    return isMeasuredBuildScope(scope, owner);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _classes.add(node);
    super.visitClassDeclaration(node);
    _classes.removeLast();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      _push(node, () => super.visitMethodDeclaration(node));

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      _push(node, () => super.visitFunctionDeclaration(node));

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) =>
      _push(node, () => super.visitConstructorDeclaration(node));

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // The body-wrapper of a FunctionDeclaration is the same flow
    // level, not a nested closure — only real closures push.
    if (node.parent is FunctionDeclaration) {
      super.visitFunctionExpression(node);
    } else {
      _push(node, () => super.visitFunctionExpression(node));
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_inDirectBuildScope) {
      final typeName = node.constructorName.type.name.lexeme;
      final ctorName = node.constructorName.name?.name;
      final trigger = _creationTrigger(typeName, ctorName);
      if (trigger != null) _flag(node, trigger);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_inDirectBuildScope) {
      final trigger = _invocationTrigger(node);
      if (trigger != null) _flag(node, trigger);
    }
    super.visitMethodInvocation(node);
  }

  /// Trigger label for a creation, or null when benign.
  ///
  /// Covers explicit `new`/`const` spellings (bare constructor calls
  /// arrive as [MethodInvocation] when unresolved — see above).
  String? _creationTrigger(String typeName, String? ctorName) {
    if (typeName == 'Future') {
      if (ctorName == 'value') return null; // Pure constructor.
      return ctorName == null ? 'Future()' : 'Future.$ctorName';
    }
    if (typeName == 'Timer') {
      return ctorName == null ? 'Timer()' : 'Timer.$ctorName';
    }
    if (asyncBuildSocketTypes.contains(typeName)) {
      return ctorName == null ? '$typeName()' : '$typeName.$ctorName';
    }
    return null;
  }

  /// Trigger label for an invocation, or null when benign.
  ///
  /// Unresolved constructor calls (`Future.delayed`, `Timer.periodic`)
  /// parse as [MethodInvocation], not creations — both spellings are
  /// matched (same doctrine as the MET creation-like check).
  String? _invocationTrigger(MethodInvocation node) {
    final name = node.methodName.name;
    if (asyncBuildChainMethods.contains(name)) return '.$name';
    if (name == 'unawaited') return 'unawaited';
    final target = node.target;
    if (target is SimpleIdentifier) {
      if (target.name == 'Future' && name != 'value') {
        return 'Future.$name';
      }
      if (target.name == 'Timer') return 'Timer.$name';
      if (asyncBuildSocketTypes.contains(target.name)) {
        return '${target.name}.$name';
      }
      return null;
    }
    if (target == null && name == 'Timer') return 'Timer()';
    if (target == null && name == 'Future') return 'Future()';
    if (target == null && asyncBuildSocketTypes.contains(name)) {
      return '$name()';
    }
    return null;
  }

  void _flag(AstNode node, String trigger) {
    violations.add(
      AsyncBuildViolation(
        line: _lineInfo.getLocation(node.offset).lineNumber,
        message:
            '$trigger in build() schedules work per frame; '
            'hoist to initState, a handler, or a FutureBuilder',
      ),
    );
  }
}
