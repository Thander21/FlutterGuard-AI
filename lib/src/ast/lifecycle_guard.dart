// FG-LIFE-001: resource symmetry — releasable fields released in dispose().
//
// Per-class field map, parse-only (no type resolution): an explicit field
// type wins, initializer/assignment shapes infer the rest. A releasable
// field with no matching release call in dispose() is flagged at its
// declaration; addListener without a paired removeListener is flagged at
// the call. Vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Field types released with `cancel()`.
const _cancelTypes = <String>{'StreamSubscription', 'Timer'};

/// Field types released with `dispose()`.
const _disposeTypes = <String>{
  'AnimationController',
  'FocusNode',
  'PageController',
  'ScrollController',
  'TabController',
  'TextEditingController',
};

/// A single FG-LIFE-001 violation.
class LifecycleViolation implements RuleViolation {
  const LifecycleViolation({required this.line, required this.message});

  /// 1-based line number of the field (or `addListener` call).
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-LIFE-001 violation found.
List<LifecycleViolation> analyzeLifecycleFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = LifecycleGuard(source, result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// One tracked field: name, releasable type (or null when unknown), and
/// 1-based declaration line.
class _Field {
  _Field(this.name, this.type, this.line);

  final String name;
  String? type;
  final int line;
}

/// One named `addListener` registration awaiting its `removeListener`.
class _AddListener {
  const _AddListener(this.receiver, this.argSource, this.line);

  final String receiver;
  final String argSource;
  final int line;
}

/// Builds the per-class field map and emits symmetry violations.
class LifecycleGuard extends RecursiveAstVisitor<void> {
  LifecycleGuard(this._source, this._lineInfo);

  final String _source;
  final LineInfo _lineInfo;
  final List<LifecycleViolation> violations = [];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _checkClass(node);
    super.visitClassDeclaration(node);
  }

  void _checkClass(ClassDeclaration node) {
    final fields = <String, _Field>{};
    for (final member in node.body.members) {
      if (member is FieldDeclaration) {
        final declared = member.fields.type;
        for (final variable in member.fields.variables) {
          final name = variable.name.lexeme;
          fields[name] = _Field(
            name,
            _fieldType(variable, declared),
            _lineInfo.getLocation(variable.name.offset).lineNumber,
          );
        }
      }
    }
    final releases = <String>{};
    final adds = <_AddListener>[];
    for (final member in node.body.members) {
      if (member is MethodDeclaration) {
        member.body.accept(
          _MemberScanner(
            fields: fields,
            isDispose: member.name.lexeme == 'dispose',
            releases: releases,
            adds: adds,
            source: _source,
            lineInfo: _lineInfo,
          ),
        );
      }
    }
    for (final field in fields.values) {
      final type = field.type;
      if (type != null && !releases.contains(field.name)) {
        violations.add(
          LifecycleViolation(
            line: field.line,
            message: '$type field ${field.name} is never released in dispose()',
          ),
        );
      }
    }
    for (final add in adds) {
      if (!releases.contains('${add.receiver}#${add.argSource}')) {
        violations.add(
          LifecycleViolation(
            line: add.line,
            message:
                'addListener on ${add.receiver} '
                'has no paired removeListener in dispose()',
          ),
        );
      }
    }
  }

  /// Explicit known type wins, otherwise the initializer shape infers it.
  String? _fieldType(VariableDeclaration variable, TypeAnnotation? declared) {
    if (declared is NamedType &&
        (_cancelTypes.contains(declared.name.lexeme) ||
            _disposeTypes.contains(declared.name.lexeme))) {
      return declared.name.lexeme;
    }
    return _inferType(variable.initializer);
  }
}

/// Scans one method body for assignments (type inference), releases (in
/// `dispose`), and listener registrations.
class _MemberScanner extends RecursiveAstVisitor<void> {
  _MemberScanner({
    required this.fields,
    required this.isDispose,
    required this.releases,
    required this.adds,
    required this.source,
    required this.lineInfo,
  });

  final Map<String, _Field> fields;
  final bool isDispose;
  final Set<String> releases;
  final List<_AddListener> adds;
  final String source;
  final LineInfo lineInfo;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    if (lhs is SimpleIdentifier) {
      final field = fields[lhs.name];
      if (field != null && field.type == null) {
        field.type = _inferType(node.rightHandSide);
      }
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final receiver = _receiverName(node.target);
    if (receiver != null) {
      final name = node.methodName.name;
      if (isDispose && (name == 'cancel' || name == 'dispose')) {
        releases.add(receiver);
      } else if (name == 'addListener' &&
          node.argumentList.arguments.isNotEmpty) {
        final arg = node.argumentList.arguments.first;
        if (arg is SimpleIdentifier || arg is PrefixedIdentifier) {
          adds.add(
            _AddListener(
              receiver,
              _argSource(arg),
              lineInfo.getLocation(node.offset).lineNumber,
            ),
          );
        }
      } else if (isDispose &&
          name == 'removeListener' &&
          node.argumentList.arguments.isNotEmpty) {
        releases.add(
          '$receiver#${_argSource(node.argumentList.arguments.first)}',
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  String _argSource(AstNode arg) => source.substring(arg.offset, arg.end);
}

/// Unwraps a release/listener receiver: `field` or `this.field`.
String? _receiverName(Expression? target) {
  if (target is SimpleIdentifier) return target.name;
  if (target is PropertyAccess && target.target is ThisExpression) {
    return target.propertyName.name;
  }
  return null;
}

/// Infers a releasable type from an acquire shape, or null when unknown.
String? _inferType(Expression? expression) {
  if (expression is MethodInvocation) {
    final name = expression.methodName.name;
    if (name == 'listen') return 'StreamSubscription';
    if (name == 'Timer' && expression.target == null) return 'Timer';
    if (name == 'periodic' &&
        expression.target is SimpleIdentifier &&
        (expression.target as SimpleIdentifier).name == 'Timer') {
      return 'Timer';
    }
    if (expression.target == null && _disposeTypes.contains(name)) return name;
    return null;
  }
  if (expression is InstanceCreationExpression) {
    final typeName = expression.constructorName.type.name.lexeme;
    if (_cancelTypes.contains(typeName) || _disposeTypes.contains(typeName)) {
      return typeName;
    }
  }
  return null;
}
