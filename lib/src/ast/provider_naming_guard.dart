// FG-RIV-026: Riverpod providers must end in Provider.
//
// A provider without the suffix reads like a local value,
// hiding an ambient subscription. Top-level variables and
// static fields initialized by a provider factory call — a
// factory-set head applied to a positional closure — must
// carry a name ending in `Provider`. The positional closure
// is the parse-only discriminator: provider-package widgets
// (`Provider(create: ...)`) take named-only arguments and
// stay clean without any import resolution.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Riverpod provider factories (TS-02 factory set).
const _factories = <String>{
  'Provider',
  'FutureProvider',
  'StreamProvider',
  'StateProvider',
  'NotifierProvider',
  'AsyncNotifierProvider',
  'StateNotifierProvider',
  'ChangeNotifierProvider',
};

/// Factory modifier segments (`FutureProvider.autoDispose`,
/// `X.family`).
const _modifiers = <String>{'autoDispose', 'family'};

/// A single FG-RIV-026 violation.
class ProviderNamingViolation implements RuleViolation {
  const ProviderNamingViolation({required this.line, required this.message});

  /// 1-based line number of the declaration.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-RIV-026 violation found.
List<ProviderNamingViolation> analyzeProviderNamingFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ProviderNamingGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags suffixless ambient declarations holding provider factories.
///
/// Parse-only shapes (no resolution): bare `Provider(...)` and
/// dotted `FutureProvider.autoDispose(...)` arrive as
/// `MethodInvocation`s; only `new`/`const` force
/// `InstanceCreationExpression` — and there the parser folds
/// dotted names into the type source. Both overrides therefore
/// decode a segment chain from syntax: one leading lowercase
/// segment reads as an import prefix, the head must name a
/// factory, and the tail must be modifiers only. Any
/// `overrideWith` invocation counts as a factory.
class ProviderNamingGuard extends RecursiveAstVisitor<void> {
  ProviderNamingGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ProviderNamingViolation> violations = [];

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _checkVariables(node.variables.variables);
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) {
      _checkVariables(node.fields.variables);
    }
    super.visitFieldDeclaration(node);
  }

  /// Flags each suffixless declarator holding a provider factory.
  void _checkVariables(List<VariableDeclaration> variables) {
    for (final variable in variables) {
      final name = variable.name.lexeme;
      if (name.endsWith('Provider')) continue;
      if (!_isProviderFactory(variable.initializer)) continue;
      violations.add(
        ProviderNamingViolation(
          line: _lineInfo.getLocation(variable.name.offset).lineNumber,
          message:
              "'$name' is a Riverpod provider; rename it to end with "
              "'Provider'",
        ),
      );
    }
  }
}

/// True when [init] is a provider factory call: a factory-set
/// head (after one optional lowercase prefix segment) with a
/// modifiers-only tail, or any `overrideWith` invocation —
/// always applied to a positional closure.
bool _isProviderFactory(Expression? init) {
  if (init is InstanceCreationExpression) {
    return _isFactoryCall(
      _typeSegments(init.constructorName.type),
      init.argumentList,
      isOverride: false,
    );
  }
  if (init is MethodInvocation) {
    return _isFactoryCall(
      _invocationSegments(init),
      init.argumentList,
      isOverride: init.methodName.name == 'overrideWith',
    );
  }
  return false;
}

/// True when the segment chain plus argument list form a
/// factory call. A null chain means an undecodable target —
/// only the `overrideWith` name rescues it.
bool _isFactoryCall(
  List<String>? segments,
  ArgumentList arguments, {
  required bool isOverride,
}) {
  if (arguments.arguments.isEmpty ||
      arguments.arguments.first is! FunctionExpression) {
    return false;
  }
  if (isOverride) return true;
  var chain = segments;
  if (chain == null || chain.isEmpty) return false;
  if (!_isCapitalized(chain.first)) {
    if (chain.length < 2 || !_isCapitalized(chain[1])) return false;
    chain = chain.sublist(1);
  }
  return _factories.contains(chain.first) &&
      chain.skip(1).every(_modifiers.contains);
}

/// Dotted segments of a forced-creation type source (`r.C`
/// keeps both; the prefix strips in [_isFactoryCall]).
/// Type arguments cut at the first `<`.
List<String> _typeSegments(NamedType type) {
  return type.toSource().split('<').first.trim().split('.');
}

/// Dotted segments of an invocation target plus method name
/// (null when the target is too complex to decode).
List<String>? _invocationSegments(MethodInvocation node) {
  final target = node.target;
  if (target == null) return [node.methodName.name];
  final leading = _dotted(target);
  if (leading == null) return null;
  return [...leading, node.methodName.name];
}

/// Dotted segments of a target expression (null when the
/// shape is not a plain dotted path).
List<String>? _dotted(Expression target) {
  if (target is SimpleIdentifier) return [target.name];
  if (target is PrefixedIdentifier) {
    return [target.prefix.name, target.identifier.name];
  }
  if (target is PropertyAccess) {
    final leading = target.target == null ? null : _dotted(target.target!);
    if (leading == null) return null;
    return [...leading, target.propertyName.name];
  }
  return null;
}

/// True when [name] starts uppercase (leading underscores ignored).
bool _isCapitalized(String name) {
  final stripped = name.replaceAll(RegExp('^_+'), '');
  if (stripped.isEmpty) return false;
  final first = stripped[0];
  return first.toUpperCase() == first;
}
