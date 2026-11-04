// FG-LAY-004: forbid unbounded scrollables directly inside Column/Row.
//
// A Column passes unbounded height (a Row, unbounded width) to its
// children, so a bare ListView/GridView/CustomScrollView in `children`
// throws the unbounded-viewport error at runtime. The scrollable must
// be wrapped in Expanded/Flexible, given a bounded height/width, or —
// in Column only — declare `shrinkWrap: true` (the Row axis ignores
// shrinkWrap: probed on Flutter 3.47.9). Parsing only (no type
// resolution), so vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Flex containers whose `children` are judged.
const _flexNames = <String>{'Column', 'Row'};

/// Scrollable widgets flagged as direct flex children.
const _scrollableNames = <String>{'ListView', 'GridView', 'CustomScrollView'};

/// Named constructors parsed as invocations on the widget target.
const _listViewCtors = <String>{'builder', 'separated', 'custom'};
const _gridViewCtors = <String>{'builder', 'count', 'extent', 'custom'};

/// A single FG-LAY-004 violation.
class ListViewportViolation implements RuleViolation {
  const ListViewportViolation({required this.line, required this.message});

  /// 1-based line number of the offending scrollable creation.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-LAY-004 violation found.
List<ListViewportViolation> analyzeListViewportFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ListViewportGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags unbounded scrollables in flex `children: …`.
///
/// Scope (v2): every `Column`/`Row` creation (explicit, bare, or
/// prefixed call) is judged independently. Its `children` argument
/// is walked through collection literals, `if`/`for` elements,
/// spreads, and conditionals; a ListView/GridView/CustomScrollView
/// creation found there is flagged unless it sets `shrinkWrap:
/// true` in a Column (the Row axis ignores `shrinkWrap`). Other
/// widget creations are never descended into, so wrapped
/// scrollables stay clean.
class ListViewportGuard extends RecursiveAstVisitor<void> {
  ListViewportGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ListViewportViolation> violations = [];

  /// True while scanning a `Row` children list. Safe as a field:
  /// collection scans never recurse into nested flexes (other
  /// widget creations are opaque), so no scan overlaps another.
  bool _inRow = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = _simpleName(node.constructorName.type.toSource());
    if (_flexNames.contains(name)) {
      _checkChildren(node.argumentList, isRow: name == 'Row');
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if ((target == null || target is SimpleIdentifier) &&
        _flexNames.contains(node.methodName.name)) {
      _checkChildren(node.argumentList, isRow: node.methodName.name == 'Row');
    }
    super.visitMethodInvocation(node);
  }

  void _checkChildren(ArgumentList arguments, {required bool isRow}) {
    _inRow = isRow;
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression &&
          argument.name.label.name == 'children') {
        _scanCollectionValue(argument.expression);
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
      _checkWidget(value);
    }
  }

  void _scanElement(CollectionElement element) {
    if (element is Expression) {
      _checkWidget(element);
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

  void _checkWidget(Expression widget) {
    final name = _scrollableName(widget);
    if (name == null) return;
    if (!_inRow && _hasShrinkWrapTrue(widget)) return;
    final axis =
        _inRow ? 'Row() has unbounded width' : 'Column() has unbounded height';
    violations.add(ListViewportViolation(
      line: _lineInfo.getLocation(widget.offset).lineNumber,
      message: '$name() directly inside $axis; wrap it in Expanded',
    ));
  }
}

/// Scrollable widget created by [widget], or null when it creates
/// none. Covers explicit creations, bare calls, named constructors
/// (invocation form when unresolved), and import-prefixed shapes;
/// call chains (`a().ListView()`) are excluded as method calls.
String? _scrollableName(Expression widget) {
  if (widget is InstanceCreationExpression) {
    final name = _simpleName(widget.constructorName.type.toSource());
    return _scrollableNames.contains(name) ? name : null;
  }
  if (widget is! MethodInvocation) return null;
  final target = widget.target;
  final method = widget.methodName.name;
  if (target == null) {
    return _scrollableNames.contains(method) ? method : null;
  }
  if (target is SimpleIdentifier) {
    final targetName = _simpleName(target.name);
    if (targetName == 'ListView' && _listViewCtors.contains(method)) {
      return 'ListView';
    }
    if (targetName == 'GridView' && _gridViewCtors.contains(method)) {
      return 'GridView';
    }
    // Prefixed default (`widgets.ListView()`): an UpperCamelCase
    // method on a SimpleIdentifier target is a prefix, not a call.
    if (_scrollableNames.contains(method)) return method;
    return null;
  }
  if (target is PrefixedIdentifier) {
    // Prefixed named ctor (`widgets.ListView.builder`).
    final property = target.identifier.name;
    if (property == 'ListView' && _listViewCtors.contains(method)) {
      return 'ListView';
    }
    if (property == 'GridView' && _gridViewCtors.contains(method)) {
      return 'GridView';
    }
    return null;
  }
  if (target is PropertyAccess) {
    // Deep-prefixed named ctor (`x.y.ListView.builder`).
    final property = target.propertyName.name;
    if (property == 'ListView' && _listViewCtors.contains(method)) {
      return 'ListView';
    }
    if (property == 'GridView' && _gridViewCtors.contains(method)) {
      return 'GridView';
    }
  }
  return null;
}

/// True when the scrollable [widget] sets `shrinkWrap: true`.
bool _hasShrinkWrapTrue(Expression widget) {
  final ArgumentList arguments;
  if (widget is InstanceCreationExpression) {
    arguments = widget.argumentList;
  } else if (widget is MethodInvocation) {
    arguments = widget.argumentList;
  } else {
    return false;
  }
  for (final argument in arguments.arguments) {
    if (argument is NamedExpression &&
        argument.name.label.name == 'shrinkWrap' &&
        argument.expression is BooleanLiteral &&
        (argument.expression as BooleanLiteral).value) {
      return true;
    }
  }
  return false;
}

/// Simple type name (`ListView` for `ListView.builder`, prefixes and type
/// arguments stripped).
String _simpleName(String source) {
  final base = source.split('<').first.trim();
  final dot = base.lastIndexOf('.');
  return dot == -1 ? base : base.substring(dot + 1);
}
