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

/// `*Builder:` argument names that run on input, not at build time:
/// they stay callbacks (Autocomplete `optionsBuilder`).
const _callbackBuilders = <String>{'optionsBuilder'};

/// AsyncValue pattern methods whose branch closures run synchronously
/// inside the caller's build (K3).
const _asyncValueMatchers = <String>{
  'when',
  'maybeWhen',
  'whenOrNull',
  'map',
  'maybeMap',
};

/// Branch argument names of [_asyncValueMatchers].
const _asyncValueBranches = <String>{'data', 'loading', 'error', 'orElse'};

/// Flags `ref.watch` calls enclosed in an argument callback.
///
/// Scope (R2-3, K3): a callback is any function expression passed
/// directly as a positional or named argument (`onTap: () {...}`),
/// except provider builders (any `Factory(.autoDispose|.family)*`
/// chain or `overrideWith`), builder-like named arguments (`builder`,
/// `itemBuilder`, any `*Builder` but `optionsBuilder`), and AsyncValue
/// `when`/`map` branches. A closure that declares its own `ref`
/// parameter shadows the outer one: enclosing callbacks stop counting
/// inside it. Torn-off named functions and callbacks stored in
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
    final isCallback = isArgCallback && !_isBuilderScope(node);
    final saved = _callbackDepth;
    if (_rebindsRef(node)) _callbackDepth = 0;
    if (isCallback) _callbackDepth++;
    super.visitFunctionExpression(node);
    _callbackDepth = saved;
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

/// True when [node] declares its own `ref` parameter
/// (`(context, ref, child) {...}`), shadowing any outer `ref`.
bool _rebindsRef(FunctionExpression node) {
  final parameters = node.parameters?.parameters ?? const <FormalParameter>[];
  return parameters.any((p) => p.name?.lexeme == 'ref');
}

/// True when [node] is a build, not an event callback: a provider
/// factory argument (any `Factory(.autoDispose|.family)*` chain or
/// `overrideWith`), a builder-like named argument, or an AsyncValue
/// `when`/`map` branch.
bool _isBuilderScope(FunctionExpression node) {
  final parent = node.parent;
  if (parent is ArgumentList) return _isFactoryCall(parent.parent);
  if (parent is NamedArgument) return _isBuilderArgument(parent);
  return false;
}

/// True for a build-time named argument: `builder`, `itemBuilder`, or
/// any `*Builder` outside [_callbackBuilders] (any callee), or a
/// branch of an AsyncValue `when`/`map` call.
bool _isBuilderArgument(NamedArgument node) {
  final name = node.name.lexeme;
  if (name == 'builder' ||
      (name.endsWith('Builder') && !_callbackBuilders.contains(name))) {
    return true;
  }
  if (!_asyncValueBranches.contains(name)) return false;
  final call = node.parent?.parent;
  return call is MethodInvocation &&
      call.target != null &&
      _asyncValueMatchers.contains(call.methodName.name);
}

/// True for a provider-factory invocation whose function argument is a
/// build: any `Factory(.autoDispose|.family)*` chain (bare, prefixed,
/// or explicit `new`/`const` spellings — unresolved constructor calls
/// parse as [MethodInvocation]) and any `x.overrideWith(...)`.
bool _isFactoryCall(AstNode? node) {
  if (node is InstanceCreationExpression) {
    return _providerFactories.contains(node.constructorName.type.name.lexeme);
  }
  if (node is! MethodInvocation) return false;
  if (node.methodName.name == 'overrideWith') return true;
  var base = node.methodName.name;
  Expression? target = node.target;
  while (base == 'family' || base == 'autoDispose') {
    if (target is MethodInvocation) {
      base = target.methodName.name;
      target = target.target;
    } else if (target is PropertyAccess) {
      base = target.propertyName.name;
      target = target.target;
    } else if (target is PrefixedIdentifier) {
      base = target.identifier.name;
      target = target.prefix;
    } else if (target is SimpleIdentifier) {
      base = target.name;
      target = null;
    } else {
      return false;
    }
  }
  return _providerFactories.contains(base);
}
