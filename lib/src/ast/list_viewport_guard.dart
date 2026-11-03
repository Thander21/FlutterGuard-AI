// FG-LAY-004: forbid unbounded ListView directly inside Column.
//
// A Column passes unbounded height to its children, so a bare ListView
// in `children` throws `Vertical viewport was given unbounded height`.
// The list must be wrapped in Expanded/Flexible, given a bounded height,
// or declare `shrinkWrap: true`. Parsing only (no type resolution), so
// vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// A single FG-LAY-004 violation.
class ListViewportViolation implements RuleViolation {
  const ListViewportViolation({required this.line, required this.message});

  /// 1-based line number of the offending ListView creation.
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

/// Flags unbounded ListViews in `Column(children: …)`.
///
/// Scope (v0): every `Column` creation (explicit or bare call) is judged
/// independently. Its `children` argument is walked through collection
/// literals, `if`/`for` elements, spreads, and conditionals; a ListView
/// creation (default or named constructor) found there is flagged unless
/// it sets `shrinkWrap: true`. Other widget creations are never
/// descended into, so wrapped lists stay clean.
class ListViewportGuard extends RecursiveAstVisitor<void> {
  ListViewportGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ListViewportViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_simpleName(node.constructorName.type.toSource()) == 'Column') {
      _checkChildren(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == 'Column') {
      _checkChildren(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  void _checkChildren(ArgumentList arguments) {
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression && argument.name.label.name == 'children') {
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
    if (_isListView(widget) && !_hasShrinkWrapTrue(widget)) {
      final line = _lineInfo.getLocation(widget.offset).lineNumber;
      violations.add(ListViewportViolation(
        line: line,
        message: 'ListView() directly inside Column() has unbounded height; '
            'wrap it in Expanded',
      ));
    }
  }
}

/// True when [widget] creates a ListView (default or named constructor).
bool _isListView(Expression widget) {
  if (widget is InstanceCreationExpression) {
    return _simpleName(widget.constructorName.type.toSource()) == 'ListView';
  }
  if (widget is MethodInvocation) {
    if (widget.target == null) return widget.methodName.name == 'ListView';
    return _simpleName(widget.target!.toSource()) == 'ListView' &&
        const {'builder', 'separated', 'custom'}
            .contains(widget.methodName.name);
  }
  return false;
}

/// True when the ListView [widget] sets `shrinkWrap: true`.
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
