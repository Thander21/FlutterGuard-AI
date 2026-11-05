// FG-KEY-001r: require keys for widgets built in lists.
//
// Items built without keys inherit a neighbor's State after deletions
// or reorders. Every item root built via a `.map()` callback feeding
// `children:`, via `itemBuilder`, or as a ReorderableListView child
// must carry an explicit key. Parsing only (no type resolution), so
// vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Stateless framework leaves exempt from the key requirement.
///
/// Closed v0 set: every entry is a StatelessWidget. Custom and composite
/// widgets fail closed (a key never hurts; a missing one corrupts
/// state). Never exempt inside ReorderableListView (runtime asserts).
const _keylessAllowlist = <String>{
  'Text',
  'RichText',
  'Icon',
  'Image',
  'Divider',
  'VerticalDivider',
  'Placeholder',
  'Spacer',
  'SizedBox',
  'Padding',
  'Center',
  'Align',
  'Container',
  'DecoratedBox',
  'ColoredBox',
  'ListTile',
  'CheckboxListTile',
  'SwitchListTile',
  'RadioListTile',
  'Card',
  'Chip',
  'CircleAvatar',
  'Badge',
};

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
  final guard = ListKeyGuard(result.lineInfo);
  result.unit.accept(guard);
  final seen = <String>{};
  final unique = guard.violations
      .where((v) => seen.add('${v.line}|${v.message}'))
      .toList();
  return unique..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags keyless item roots in `.map()`, `itemBuilder`, and
/// ReorderableListView children.
///
/// Scope (v0): `.map()` callbacks are judged only when the call flows
/// into `children:` (data maps stay clean) and never for 2-parameter
/// (`Map.map`) callbacks; tear-offs are untraced. Only top-level
/// creations in a callback are judged (nested creations sit in
/// single-child slots that cannot transpose). `key: null` counts as
/// missing.
class ListKeyGuard extends RecursiveAstVisitor<void> {
  ListKeyGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ListKeyViolation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
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
    _scanCallback(callback, 'via .map()', allowlist: true);
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
          allowlist: !strict,
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
    required bool allowlist,
  }) {
    final collector = _RootCollector();
    callback.body.accept(collector);
    for (final root in collector.roots) {
      final info = _creationInfo(root);
      if (info == null) continue;
      if (allowlist && _keylessAllowlist.contains(info.type)) continue;
      if (_hasKey(info.arguments)) continue;
      _flag(
        root.offset,
        "'${info.type}' built $via has no key; add a key (ValueKey(item.id))",
      );
    }
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
_Creation? _creationInfo(Expression node) {
  if (node is InstanceCreationExpression) {
    return _Creation(
      _simpleName(node.constructorName.type.toSource()),
      node.argumentList,
    );
  }
  if (node is MethodInvocation) {
    if (node.target == null) {
      if (!_isCapitalized(node.methodName.name)) return null;
      return _Creation(node.methodName.name, node.argumentList);
    }
    final target = node.target!;
    if (target is SimpleIdentifier && _isCapitalized(target.name)) {
      return _Creation(target.name, node.argumentList);
    }
  }
  return null;
}

class _Creation {
  const _Creation(this.type, this.arguments);

  final String type;
  final ArgumentList arguments;
}

/// True for constructor-shaped calls (bare `Tile(…)` or `Tile.named(…)`).
bool _isCreationLike(MethodInvocation node) => _creationInfo(node) != null;

/// True when [name] starts uppercase (private `_Tile` counts as well).
bool _isCapitalized(String name) =>
    name.isNotEmpty && name[0].toUpperCase() == name[0];

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
String _simpleName(String source) {
  final base = source.split('<').first.trim();
  final dot = base.lastIndexOf('.');
  return dot == -1 ? base : base.substring(dot + 1);
}
