// FG-KEY-001r: require keys for load-bearing list items.
//
// Keys matter only where a list reorders or an item holds state.
// ReorderableListView children are strict (the runtime asserts
// keys); other item roots flag only when state-bearing: same-file
// StatefulWidget subclasses or controller-carrying creations.
// Cross-file unknowns pass (fail-open: parse-only analysis cannot
// resolve cross-file statefulness). Files without a Flutter import
// and foreign-prefixed creations are out of scope. Parsing only
// (no type resolution), so vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Named arguments that make an item root state-bearing (closed v0
/// set, TS-12 §1): a tile carrying a controller or focus node holds
/// state that transposes across rows without a key.
const _stateBearingArgs = <String>{'controller', 'focusNode'};

/// A single FG-KEY-001r violation.
class ListKeyViolation implements RuleViolation {
  const ListKeyViolation({required this.line, required this.message});

  /// 1-based line number of the keyless item creation.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-KEY-001r violation found.
List<ListKeyViolation> analyzeListKeyFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final scope = ListKeyFileScope.collect(result.unit);
  final guard = ListKeyGuard(
    result.lineInfo,
    hasFlutterImport: scope.hasFlutterImport,
    prefixToUri: scope.prefixToUri,
    statefulWidgets: scope.statefulWidgets,
  );
  result.unit.accept(guard);
  final seen = <String>{};
  final unique = guard.violations
      .where((v) => seen.add('${v.line}|${v.message}'))
      .toList();
  return unique..sort((a, b) => a.line.compareTo(b.line));
}

/// Per-file scope facts the key rule needs (TS-12 §1, Q6).
///
/// Collected in one syntactic pass: the Flutter file gate, the
/// import-prefix map for foreign detection, and the same-file
/// `StatefulWidget` subclasses that make roots state-bearing.
class ListKeyFileScope {
  const ListKeyFileScope({
    required this.hasFlutterImport,
    required this.prefixToUri,
    required this.statefulWidgets,
  });

  /// True when the file imports `package:flutter/` (the rule is
  /// silent otherwise — pdf builders and pure Dart stay clean).
  final bool hasFlutterImport;

  /// Import prefix to imported URI (`pw` → `package:pdf/…`).
  final Map<String, String> prefixToUri;

  /// Same-file classes extending `StatefulWidget` (simple names).
  final Set<String> statefulWidgets;

  /// Collects the scope facts from [unit].
  static ListKeyFileScope collect(CompilationUnit unit) {
    var hasFlutterImport = false;
    final prefixToUri = <String, String>{};
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final uri = directive.uri.stringValue;
      if (uri == null) continue;
      if (uri.startsWith('package:flutter/')) hasFlutterImport = true;
      final prefix = directive.prefix?.name;
      if (prefix != null) prefixToUri[prefix] = uri;
    }
    final statefulWidgets = <String>{};
    for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
      final superclass = declaration.extendsClause?.superclass;
      if (superclass == null) continue;
      if (_simpleName(superclass.toSource()) == 'StatefulWidget') {
        statefulWidgets.add(declaration.namePart.typeName.lexeme);
      }
    }
    return ListKeyFileScope(
      hasFlutterImport: hasFlutterImport,
      prefixToUri: prefixToUri,
      statefulWidgets: statefulWidgets,
    );
  }

  /// True when [prefix] resolves to a local import: Flutter or
  /// relative (same-project). Other-`package:`, `dart:`, and
  /// unmapped prefixes are foreign (fail-open). Own-package
  /// `package:` imports with a prefix read as foreign — prefixed
  /// same-project imports are rare; the miss is documented.
  bool isLocalPrefix(String prefix) {
    final uri = prefixToUri[prefix];
    if (uri == null) return false;
    if (uri.startsWith('package:flutter/')) return true;
    if (uri.startsWith('package:')) return false;
    if (uri.startsWith('dart:')) return false;
    return true;
  }
}

/// Flags keyless load-bearing item roots in `.map()`,
/// `itemBuilder`, and ReorderableListView children.
///
/// Scope (v3): `.map()` callbacks are judged only when the call flows
/// into `children:` (data maps stay clean) and never for 2-parameter
/// (`Map.map`) callbacks; tear-offs are untraced. Only top-level
/// creations in a callback are judged (nested creations sit in
/// single-child slots that cannot transpose). `key: null` counts as
/// missing. Outside reorderables, only state-bearing roots flag
/// (same-file `StatefulWidget` or `controller`/`focusNode`
/// arguments); unknown cross-file tiles pass fail-open.
class ListKeyGuard extends RecursiveAstVisitor<void> {
  ListKeyGuard(
    this._lineInfo, {
    bool hasFlutterImport = true,
    Map<String, String> prefixToUri = const {},
    Set<String> statefulWidgets = const {},
  }) : _scope = ListKeyFileScope(
         hasFlutterImport: hasFlutterImport,
         prefixToUri: prefixToUri,
         statefulWidgets: statefulWidgets,
       );

  final LineInfo _lineInfo;
  final ListKeyFileScope _scope;
  final List<ListKeyViolation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_scope.hasFlutterImport) return;
    if (node.methodName.name == 'map') {
      _checkMap(node);
    }
    final strict = _isReorderableCall(node);
    _checkItemBuilder(node.argumentList, strict: strict);
    if (strict) {
      _checkReorderableChildren(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!_scope.hasFlutterImport) return;
    final strict =
        _simpleName(node.constructorName.type.toSource()) ==
        'ReorderableListView';
    _checkItemBuilder(node.argumentList, strict: strict);
    if (strict) {
      _checkReorderableChildren(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  /// Scans a `.map()` callback when it builds `children:` widgets.
  void _checkMap(MethodInvocation node) {
    FunctionExpression? callback;
    for (final argument in node.argumentList.arguments) {
      if (argument is FunctionExpression) {
        callback = argument;
        break;
      }
    }
    if (callback == null) return;
    if ((callback.parameters?.parameters.length ?? 0) == 2) return;
    if (!_flowsIntoChildren(node)) return;
    _scanCallback(callback, 'via .map()', strict: false);
  }

  /// Scans an `itemBuilder:` callback (strict under ReorderableListView).
  void _checkItemBuilder(ArgumentList arguments, {required bool strict}) {
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument &&
          argument.name.lexeme == 'itemBuilder' &&
          argument.argumentExpression is FunctionExpression) {
        _scanCallback(
          argument.argumentExpression as FunctionExpression,
          'via itemBuilder',
          strict: strict,
        );
      }
    }
  }

  /// Walks `children:` strictly (every Reorderable child needs a key).
  void _checkReorderableChildren(ArgumentList arguments) {
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'children') {
        _scanCollectionValue(argument.argumentExpression);
      }
    }
  }

  void _scanCollectionValue(Expression value) {
    if (value is ListLiteral) {
      for (final element in value.elements) {
        _scanElement(element);
      }
    } else if (value is ConditionalExpression) {
      _scanCollectionValue(value.thenExpression);
      _scanCollectionValue(value.elseExpression);
    } else {
      _checkChild(value);
    }
  }

  void _scanElement(CollectionElement element) {
    if (element is Expression) {
      _checkChild(element);
    } else if (element is IfElement) {
      _scanElement(element.thenElement);
      final elseBranch = element.elseElement;
      if (elseBranch != null) _scanElement(elseBranch);
    } else if (element is ForElement) {
      _scanElement(element.body);
    } else if (element is SpreadElement) {
      _scanCollectionValue(element.expression);
    }
  }

  void _checkChild(Expression child) {
    final info = _creationInfo(child);
    if (info == null) return;
    if (_isForeign(info)) return;
    if (_hasKey(info.arguments)) return;
    _flag(
      child.offset,
      "'${info.type}' built in ReorderableListView "
      'has no key; add a key (ValueKey(item.id))',
    );
  }

  void _scanCallback(
    FunctionExpression callback,
    String via, {
    required bool strict,
  }) {
    final collector = _RootCollector();
    callback.body.accept(collector);
    for (final root in collector.roots) {
      final info = _creationInfo(root);
      if (info == null) continue;
      if (_isForeign(info)) continue;
      if (!strict && !_isStateBearing(info)) continue;
      if (_hasKey(info.arguments)) continue;
      _flag(
        root.offset,
        "'${info.type}' built $via has no key; add a key (ValueKey(item.id))",
      );
    }
  }

  /// True when [info] carries a foreign prefix (out of scope).
  bool _isForeign(_Creation info) {
    final prefix = info.prefix;
    if (prefix == null) return false;
    return !_scope.isLocalPrefix(prefix);
  }

  /// True when [info] provably holds state: a same-file
  /// `StatefulWidget` subclass or a controller-carrying creation.
  /// Unknown cross-file types are not state-bearing (fail-open).
  bool _isStateBearing(_Creation info) {
    if (_scope.statefulWidgets.contains(info.type)) return true;
    for (final argument in info.arguments.arguments) {
      if (argument is NamedArgument &&
          _stateBearingArgs.contains(argument.name.lexeme)) {
        return true;
      }
    }
    return false;
  }

  void _flag(int offset, String message) {
    violations.add(
      ListKeyViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message: message,
      ),
    );
  }
}

/// Collects top-level creations in a callback body.
///
/// Creation arguments are never descended into (nested creations sit in
/// single-child slots); lowercase factory calls are transparent.
class _RootCollector extends RecursiveAstVisitor<void> {
  final List<Expression> roots = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    roots.add(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isCreationLike(node)) {
      roots.add(node);
      return;
    }
    super.visitMethodInvocation(node);
  }
}

/// Creation type plus arguments, or null for non-creations.
///
/// Prefixed calls (`p.X(...)`) are creation candidates carrying
/// their prefix — the guard's foreign rule decides whether they
/// are in scope. Foreign targets would otherwise be invisible:
/// the parser leaves every lowercase-prefixed call a
/// `MethodInvocation`, so prefix handling lives here, not in a
/// stripped simple name.
_Creation? _creationInfo(Expression node) {
  if (node is InstanceCreationExpression) {
    final parts = _splitName(node.constructorName.type.toSource());
    return _Creation(parts.type, node.argumentList, prefix: parts.prefix);
  }
  if (node is MethodInvocation) {
    if (node.target == null) {
      if (!_isCapitalized(node.methodName.name)) return null;
      return _Creation(node.methodName.name, node.argumentList);
    }
    final target = node.target!;
    if (target is SimpleIdentifier) {
      if (_isCapitalized(target.name)) {
        return _Creation(target.name, node.argumentList);
      }
      if (_isCapitalized(node.methodName.name)) {
        return _Creation(
          node.methodName.name,
          node.argumentList,
          prefix: target.name,
        );
      }
    }
  }
  return null;
}

class _Creation {
  const _Creation(this.type, this.arguments, {this.prefix});

  /// Simple (prefix-stripped) type name.
  final String type;

  final ArgumentList arguments;

  /// Import prefix for `p.X(...)` shapes, null for bare creations.
  final String? prefix;
}

/// True for constructor-shaped calls (bare `Tile(…)`,
/// `Tile.named(…)`, or prefixed `p.Tile(…)` candidates).
bool _isCreationLike(MethodInvocation node) => _creationInfo(node) != null;

/// True when [name] starts uppercase (leading underscores ignored:
/// `_Tile` counts, `_getName` does not).
bool _isCapitalized(String name) {
  final stripped = name.replaceAll(RegExp('^_+'), '');
  if (stripped.isEmpty) return false;
  final first = stripped[0];
  return first.toUpperCase() == first;
}

/// True for `ReorderableListView(…)` in any call shape.
bool _isReorderableCall(MethodInvocation node) {
  if (node.target == null) {
    return node.methodName.name == 'ReorderableListView';
  }
  final target = node.target!;
  return target is SimpleIdentifier && target.name == 'ReorderableListView';
}

/// True for an explicit non-null `key:` argument.
bool _hasKey(ArgumentList arguments) {
  for (final argument in arguments.arguments) {
    if (argument is NamedArgument &&
        argument.name.lexeme == 'key' &&
        argument.argumentExpression is! NullLiteral) {
      return true;
    }
  }
  return false;
}

/// True when the `.map()` call result flows into `children:`.
///
/// Climbs call chains (`.toList()`), spreads, collection elements, and
/// conditionals up to a `children:` named argument; anything else
/// (variables, properties, foreign arguments) stops the climb.
bool _flowsIntoChildren(MethodInvocation node) {
  AstNode current = node;
  while (true) {
    final parent = current.parent;
    if (parent is MethodInvocation && parent.target == current) {
      current = parent;
      continue;
    }
    if (parent is SpreadElement && parent.expression == current) {
      current = parent;
      continue;
    }
    if (parent is ListLiteral && parent.elements.contains(current)) {
      current = parent;
      continue;
    }
    if (parent is IfElement &&
        (parent.thenElement == current || parent.elseElement == current)) {
      current = parent;
      continue;
    }
    if (parent is ForElement && parent.body == current) {
      current = parent;
      continue;
    }
    if (parent is ConditionalExpression &&
        (parent.thenExpression == current ||
            parent.elseExpression == current)) {
      current = parent;
      continue;
    }
    return parent is NamedArgument &&
        parent.name.lexeme == 'children' &&
        parent.argumentExpression == current;
  }
}

/// Simple type name (prefixes and type arguments stripped).
String _simpleName(String source) => _splitName(source).type;

/// Splits `p.X<T>` into its import prefix and simple type name.
({String? prefix, String type}) _splitName(String source) {
  final base = source.split('<').first.trim();
  final dot = base.lastIndexOf('.');
  if (dot == -1) return (prefix: null, type: base);
  return (prefix: base.substring(0, dot), type: base.substring(dot + 1));
}
