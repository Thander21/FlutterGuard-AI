// FG-SYNC-034: forbid blocking sync I/O in frame-critical scopes.
//
// A frame budget is ~16ms; a *Sync call or sleep() on the UI isolate
// freezes every pixel until the disk answers. Two scopes run
// frame-critically: build() (up to 120 executions per second) and
// widget event-handler closures (dispatched synchronously on the
// tap). Parsing only (no type resolution), so vectors need no
// dependencies.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'build_scope.dart';
import 'rule_violation.dart';

/// A single FG-SYNC-034 violation.
class SyncJankViolation implements RuleViolation {
  const SyncJankViolation({required this.line, required this.message});

  /// 1-based line number of the offending invocation.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-SYNC-034 violation found.
List<SyncJankViolation> analyzeSyncJankFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = SyncJankGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags blocking sync calls in frame-critical scopes.
///
/// Direct build flow follows the TS-14 doctrine: a trigger fires at
/// function depth 1 inside a measured build scope. Handler flow is
/// additive: any trigger lexically inside an `on[A-Z]*` closure
/// argument of a constructor-shaped invocation fires at any depth —
/// nested closures there still run synchronously on the tap.
class SyncJankGuard extends RecursiveAstVisitor<void> {
  SyncJankGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<SyncJankViolation> violations = [];
  final List<(AstNode, ClassDeclaration?)> _scopes = [];
  final List<ClassDeclaration> _classes = [];
  var _handlerDepth = 0;

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
      return;
    }
    final isHandler = _isHandlerArgument(node);
    if (isHandler) _handlerDepth++;
    _push(node, () => super.visitFunctionExpression(node));
    if (isHandler) _handlerDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_inDirectBuildScope || _handlerDepth > 0) {
      final trigger = _trigger(node);
      if (trigger != null) _flag(node, trigger);
    }
    super.visitMethodInvocation(node);
  }

  /// Trigger label for an invocation, or null when benign.
  ///
  /// Any lowercase-led `*Sync` method name on any target (dart:io
  /// owns the suffix in practice; capitalized names are
  /// constructor-shaped unresolved spellings, never sync methods),
  /// plus bare `sleep(` (target-free, prefix-free).
  String? _trigger(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'sleep' && node.target == null) return 'sleep()';
    if (name.endsWith('Sync') && !_isUppercase(name.codeUnitAt(0))) {
      return '$name()';
    }
    return null;
  }

  void _flag(AstNode node, String trigger) {
    violations.add(
      SyncJankViolation(
        line: _lineInfo.getLocation(node.offset).lineNumber,
        message:
            '$trigger blocks the frame; use the async variant, '
            'hoist to initState, or precompute',
      ),
    );
  }
}

/// True when [node] is passed directly as an `on[A-Z]*` named
/// argument of a constructor-shaped invocation: an
/// [InstanceCreationExpression], or a capitalized [MethodInvocation]
/// (the unresolved-constructor spelling). Lowercase calls
/// (`stream.listen(onDone: ...)`) and lowercase-led names (`only:`)
/// stay out.
bool _isHandlerArgument(FunctionExpression node) {
  final parent = node.parent;
  if (parent is! NamedArgument) return false;
  if (!_isHandlerName(parent.name.lexeme)) return false;
  final grandparent = parent.parent;
  if (grandparent is! ArgumentList) return false;
  final call = grandparent.parent;
  if (call is InstanceCreationExpression) return true;
  if (call is MethodInvocation) {
    final name = call.methodName.name;
    return name.isNotEmpty && _isUppercase(name.codeUnitAt(0));
  }
  return false;
}

/// True for `on` + uppercase-led names (`onPressed`, `onTap`).
bool _isHandlerName(String name) =>
    name.length > 2 &&
    name.startsWith('on') &&
    _isUppercase(name.codeUnitAt(2));

/// True for ASCII uppercase A-Z.
bool _isUppercase(int unit) => unit >= 0x41 && unit <= 0x5A;
