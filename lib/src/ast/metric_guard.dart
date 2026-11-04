// FG-MET-007: advisory widget complexity budgets (depth, params).
//
// Over-deep widget trees and over-wide constructors are god-widget
// symptoms. Both thresholds are uncalibrated guesses, so findings are
// ADVISORY (severity warning, never fail the gate) until SYS-CAL-001
// calibrates them. Parsing only (no type resolution), so vectors need
// no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Advisory budget: maximum widget-creation nesting depth.
const maxWidgetDepth = 5;

/// Advisory budget: maximum declared constructor parameters.
const maxConstructorParams = 7;

/// A single FG-MET-007 violation.
class MetricViolation implements RuleViolation {
  const MetricViolation({required this.line, required this.message});

  /// 1-based line number of the over-deep creation or wide constructor.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-MET-007 violation found.
List<MetricViolation> analyzeMetricFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = MetricGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags over-deep widget trees and over-wide constructors.
///
/// Scope (v0): depth is measured only inside `build()` methods and
/// `Widget`-returning functions, counting creation ancestors (explicit
/// or constructor-shaped calls; method calls, properties, and closures
/// are transparent). Every creation deeper than 5 is flagged with its
/// depth. Every constructor declaring more than 7 parameters is
/// flagged at its name.
class MetricGuard extends RecursiveAstVisitor<void> {
  MetricGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<MetricViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkDepth(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isCreationLike(node)) {
      _checkDepth(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final count = node.parameters.parameters.length;
    if (count > maxConstructorParams) {
      final name = node.name;
      violations.add(MetricViolation(
        line: _lineInfo
            .getLocation(
                (name ?? node.firstTokenAfterCommentAndMetadata).offset)
            .lineNumber,
        message: 'constructor has $count parameters, exceeding the '
            'advisory budget of $maxConstructorParams; '
            'group them into a config object',
      ));
    }
    super.visitConstructorDeclaration(node);
  }

  /// Flags [creation] when it nests deeper than the depth budget inside
  /// a measured function.
  void _checkDepth(AstNode creation) {
    var depth = 1;
    AstNode? current = creation.parent;
    AstNode? scope;
    while (current != null) {
      if (current is InstanceCreationExpression ||
          (current is MethodInvocation && _isCreationLike(current))) {
        depth++;
      }
      if (current is MethodDeclaration ||
          current is FunctionDeclaration ||
          current is ConstructorDeclaration) {
        scope = current;
        break;
      }
      current = current.parent;
    }
    if (scope is ConstructorDeclaration) return;
    if (!_isMeasured(scope)) return;
    if (depth > maxWidgetDepth) {
      violations.add(MetricViolation(
        line: _lineInfo.getLocation(creation.offset).lineNumber,
        message: 'widget nesting depth $depth exceeds the advisory '
            'budget of $maxWidgetDepth; extract a sub-widget',
      ));
    }
  }
}

/// True for `build()` methods and `Widget`-returning functions.
bool _isMeasured(AstNode? scope) {
  if (scope is MethodDeclaration) {
    if (scope.name.lexeme == 'build') return true;
    return _isWidgetType(scope.returnType);
  }
  if (scope is FunctionDeclaration) {
    return _isWidgetType(scope.returnType);
  }
  return false;
}

/// True for a `Widget` return type (exact simple name).
bool _isWidgetType(TypeAnnotation? type) =>
    type is NamedType && type.name2.lexeme == 'Widget';

/// True for constructor-shaped calls (bare `Tile(…)` or `Tile.named(…)`).
bool _isCreationLike(MethodInvocation node) {
  if (node.target == null) return _isCapitalized(node.methodName.name);
  final target = node.target!;
  return target is SimpleIdentifier && _isCapitalized(target.name);
}

/// True when [name] starts uppercase (private `_Tile` counts as well).
bool _isCapitalized(String name) =>
    name.isNotEmpty && name[0].toUpperCase() == name[0];
