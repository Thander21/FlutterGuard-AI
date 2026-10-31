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

/// Flags `ref.watch` calls enclosed in an argument callback.
///
/// Scope (v0): a callback is any function expression passed directly as a
/// positional or named argument (`onTap: () {...}`). Torn-off named
/// functions and callbacks stored in variables are not tracked.
class RiverpodWatchGuard extends RecursiveAstVisitor<void> {
  RiverpodWatchGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<RiverpodWatchViolation> violations = [];
  int _callbackDepth = 0;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final parent = node.parent;
    final isCallback = parent is ArgumentList || parent is NamedExpression;
    if (isCallback) _callbackDepth++;
    super.visitFunctionExpression(node);
    if (isCallback) _callbackDepth--;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_callbackDepth > 0 && _isRefWatch(node)) {
      final line = _lineInfo.getLocation(node.offset).lineNumber;
      violations.add(RiverpodWatchViolation(
        line: line,
        message: 'ref.watch() inside event callback; use ref.read() instead',
      ));
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
