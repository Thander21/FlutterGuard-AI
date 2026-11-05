// FG-RIV-001: forbid `ref.watch` inside event callbacks.
//
// `ref.watch` subscriptions belong to the synchronous build; inside an
// event callback the correct read is `ref.read(...)`.
// Parsing only (no type resolution), so vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// A single FG-RIV-001 violation.
class RiverpodWatchViolation implements RuleViolation {
  const RiverpodWatchViolation({required this.line, required this.message});

  /// 1-based line number of the offending `ref.watch` call.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-RIV-001 violation found.
List<RiverpodWatchViolation> analyzeRiverpodFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = RiverpodWatchGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations;
}

/// Provider-factory callee names whose function argument is a build,
/// not an event callback (TS-02 §3; SYS-CAL-002 P1-1).
const _providerFactories = <String>{
  'Provider',
  'FutureProvider',
  'StreamProvider',
  'StateProvider',
  'NotifierProvider',
  'AsyncNotifierProvider',
  'StateNotifierProvider',
  'ChangeNotifierProvider',
};

/// Flags `ref.watch` calls enclosed in an argument callback.
///
/// Scope (v0): a callback is any function expression passed directly as a
/// positional or named argument (`onTap: () {...}`), except provider
/// builders. Torn-off named functions and callbacks stored in
/// variables are not tracked.
class RiverpodWatchGuard extends RecursiveAstVisitor<void> {
  RiverpodWatchGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<RiverpodWatchViolation> violations = [];
  int _callbackDepth = 0;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final parent = node.parent;
    final isArgCallback = parent is ArgumentList || parent is NamedArgument;
    final isBuilder = parent is ArgumentList && _isFactoryCall(parent.parent);
    final isCallback = isArgCallback && !isBuilder;
    if (isCallback) _callbackDepth++;
    super.visitFunctionExpression(node);
    if (isCallback) _callbackDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_callbackDepth > 0 && _isRefWatch(node)) {
      final line = _lineInfo.getLocation(node.offset).lineNumber;
      violations.add(
        RiverpodWatchViolation(
          line: line,
          message: 'ref.watch() inside event callback; use ref.read() instead',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}

/// True for `ref.watch(...)` with a bare `ref` target.
bool _isRefWatch(MethodInvocation node) {
  if (node.methodName.name != 'watch') return false;
  final target = node.target;
  return target is SimpleIdentifier && target.name == 'ref';
}

/// True for a provider-factory invocation whose function argument is a
/// build: `Provider(...)` (any target — prefixed factories included),
/// `X.family(...)` on a factory, and `x.overrideWith(...)` (always a
/// provider builder). Covers bare-call and explicit `new`/`const`
/// spellings (unresolved constructor calls parse as
/// [MethodInvocation]; explicit ones as creations).
bool _isFactoryCall(AstNode? node) {
  if (node is MethodInvocation) {
    if (node.methodName.name == 'overrideWith') return true;
    if (node.methodName.name == 'family') {
      return _providerFactories.contains(_targetName(node.target));
    }
    return _providerFactories.contains(node.methodName.name);
  }
  if (node is InstanceCreationExpression) {
    return _providerFactories.contains(node.constructorName.type.name.lexeme);
  }
  return false;
}

/// Simple name of an invocation target (prefixes stripped), or null
/// when the target has no static name.
String? _targetName(Expression? target) {
  if (target is SimpleIdentifier) return target.name;
  if (target is PrefixedIdentifier) return target.identifier.name;
  return null;
}
