// FG-ST-005: forbid in-place state mutation in Riverpod/Bloc.
//
// Riverpod and Bloc rebuild listeners by comparing state references, so
// mutating in place (`state.items.add(item)`) silently skips the rebuild.
// State must be replaced (`state = state.copyWith(…)`). Parsing only (no
// type resolution), so vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Collection methods that mutate the receiver in place.
///
/// Closed v0 list: List/Set/Map mutators. Reads (`length`, `map`,
/// `where`, `toList`) and custom state methods are never flagged.
const _mutatingMethods = <String>{
  'add',
  'addAll',
  'addEntries',
  'insert',
  'insertAll',
  'remove',
  'removeAt',
  'removeLast',
  'removeWhere',
  'removeRange',
  'removeAll',
  'retainWhere',
  'retainAll',
  'clear',
  'sort',
  'shuffle',
  'setAll',
  'fillRange',
  'replaceRange',
  'setRange',
  'putIfAbsent',
  'update',
  'updateAll',
};

/// A single FG-ST-005 violation.
class StateMutationViolation implements RuleViolation {
  const StateMutationViolation({required this.line, required this.message});

  /// 1-based line number of the offending mutation.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ST-005 violation found.
List<StateMutationViolation> analyzeStateMutationFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = StateMutationGuard(result.lineInfo);
  result.unit.accept(guard);
  final seen = <String>{};
  final unique = guard.violations
      .where((v) => seen.add('${v.line}|${v.message}'))
      .toList();
  return unique..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags in-place mutations of `state` in Riverpod/Bloc holders.
///
/// Scope (v0): inside classes extending `Cubit`/`Bloc` or any
/// `*Notifier`, a mutating collection call on a state-rooted receiver
/// (a chain of pure property accesses from `state`; any method call in
/// the chain breaks tracking), an assignment to a state-rooted property
/// or subscript, or `++`/`--` on one is flagged. Assigning `state`
/// itself, reads, and non-state receivers are always clean.
class StateMutationGuard extends RecursiveAstVisitor<void> {
  StateMutationGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<StateMutationViolation> violations = [];
  bool _inHolder = false;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final wasInHolder = _inHolder;
    if (_isStateHolder(node.extendsClause?.superclass)) {
      _inHolder = true;
    }
    super.visitClassDeclaration(node);
    _inHolder = wasInHolder;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_inHolder &&
        _mutatingMethods.contains(node.methodName.name) &&
        _rootsAtState(node.target)) {
      _flag(node, "'${node.methodName.name}'");
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_inHolder && _isStateRootedWrite(node.leftHandSide)) {
      _flag(node, 'assignment');
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (_inHolder &&
        _isPlusPlus(node.operator.lexeme) &&
        _isStateRootedWrite(node.operand)) {
      _flag(node, "'${node.operator.lexeme}'");
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (_inHolder &&
        _isPlusPlus(node.operator.lexeme) &&
        _isStateRootedWrite(node.operand)) {
      _flag(node, "'${node.operator.lexeme}'");
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    if (_inHolder && _rootsAtState(node.target)) {
      for (final section in node.cascadeSections) {
        if (section is MethodInvocation &&
            _mutatingMethods.contains(section.methodName.name)) {
          _flag(section, "'${section.methodName.name}'");
        } else if (section is AssignmentExpression) {
          _flag(section, 'assignment');
        } else if (section is PrefixExpression &&
            _isPlusPlus(section.operator.lexeme)) {
          _flag(section, "'${section.operator.lexeme}'");
        } else if (section is PostfixExpression &&
            _isPlusPlus(section.operator.lexeme)) {
          _flag(section, "'${section.operator.lexeme}'");
        }
      }
    }
    super.visitCascadeExpression(node);
  }

  void _flag(AstNode node, String verb) {
    violations.add(
      StateMutationViolation(
        line: _lineInfo.getLocation(node.offset).lineNumber,
        message:
            '$verb mutates state in place; '
            'assign a new state instead (state = state.copyWith(...))',
      ),
    );
  }
}

/// True for `Cubit`, `Bloc`, or any superclass ending in `Notifier`.
bool _isStateHolder(NamedType? superclass) {
  if (superclass == null) return false;
  // toSource-based extraction avoids version-sensitive NamedType APIs.
  final raw = superclass.toSource().split('<').first.trim();
  final name = raw.contains('.') ? raw.split('.').last : raw;
  return name == 'Cubit' || name == 'Bloc' || name.endsWith('Notifier');
}

/// True when [expression] is a chain of pure property accesses rooted at
/// `state`. Any method call, literal, or foreign root breaks tracking.
bool _rootsAtState(Expression? expression) {
  var current = expression;
  while (current != null) {
    if (current is SimpleIdentifier) return current.name == 'state';
    if (current is PrefixedIdentifier) {
      current = current.prefix;
      continue;
    }
    if (current is PropertyAccess) {
      if (current.target is ThisExpression) {
        return current.propertyName.name == 'state';
      }
      current = current.target;
      continue;
    }
    if (current is IndexExpression) {
      current = current.target;
      continue;
    }
    return false;
  }
  return false;
}

/// True when [target] writes through state (`state.count = …`,
/// `state.items[0] = …`) rather than replacing it (`state = …`,
/// `this.state = …`).
bool _isStateRootedWrite(Expression target) {
  if (target is SimpleIdentifier) return false;
  if (target is PropertyAccess &&
      target.target is ThisExpression &&
      target.propertyName.name == 'state') {
    return false;
  }
  if (target is PrefixedIdentifier &&
      target.prefix.name == 'this' &&
      target.identifier.name == 'state') {
    return false;
  }
  return _rootsAtState(target);
}

/// True for the mutating `++`/`--` operators (not negation or complement).
bool _isPlusPlus(String lexeme) => lexeme == '++' || lexeme == '--';
