// FG-LIFE-001: resource symmetry — releasable fields released in dispose().
//
// Per-class field map, parse-only (no type resolution): an explicit field
// type wins, initializer/assignment shapes infer the rest. A releasable
// field with no matching release call in a release method is flagged at
// its declaration; addListener without a paired removeListener is flagged
// at the call. Vectors need no dependencies.

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

  /// True when the field provably comes from the constructor.
  bool borrowed = false;

  /// True when the field is acquired by a construction shape.
  bool constructed = false;
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
          final field = _Field(
            name,
            _fieldType(variable, declared),
            _lineInfo.getLocation(variable.name.offset).lineNumber,
          );
          if (_inferType(variable.initializer) != null) {
            field.constructed = true;
          }
          fields[name] = field;
        }
      }
    }
    final ctorParams = _constructorParams(node);
    for (final name in _fieldFormals(node)) {
      fields[name]?.borrowed = true;
    }
    final extended =
        !_isStateLike(node.extendsClause?.superclass) &&
        !_isNotifierLike(node.extendsClause?.superclass);
    final releases = <String>{};
    final adds = <_AddListener>[];
    for (final member in node.body.members) {
      if (member is MethodDeclaration) {
        member.body.accept(
          _MemberScanner(
            fields: fields,
            ctorParams: ctorParams,
            isReleaseMethod: _isReleaseMethod(member.name.lexeme, extended),
            releases: releases,
            adds: adds,
            source: _source,
            lineInfo: _lineInfo,
          ),
        );
      } else if (member is ConstructorDeclaration) {
        _scanConstructor(member, fields, ctorParams);
        member.body.accept(
          _MemberScanner(
            fields: fields,
            ctorParams: ctorParams,
            isReleaseMethod: false,
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
      final borrowed = field.borrowed && !field.constructed;
      if (type != null && !borrowed && !releases.contains(field.name)) {
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

  /// Tracks initializer-list acquires: construction marks ownership,
  /// constructor-parameter values mark borrowed receipt.
  void _scanConstructor(
    ConstructorDeclaration node,
    Map<String, _Field> fields,
    Set<String> ctorParams,
  ) {
    for (final initializer in node.initializers) {
      if (initializer is ConstructorFieldInitializer) {
        final field = fields[initializer.fieldName.name];
        if (field == null) continue;
        final value = initializer.expression;
        final inferred = _inferType(value);
        field.type ??= inferred;
        if (inferred != null) field.constructed = true;
        if (value is SimpleIdentifier && ctorParams.contains(value.name)) {
          field.borrowed = true;
        }
      }
    }
  }
}

/// Scans one method body for assignments (type inference and
/// ownership), releases (in release methods), and listener
/// registrations.
class _MemberScanner extends RecursiveAstVisitor<void> {
  _MemberScanner({
    required this.fields,
    required this.ctorParams,
    required this.isReleaseMethod,
    required this.releases,
    required this.adds,
    required this.source,
    required this.lineInfo,
  });

  final Map<String, _Field> fields;
  final Set<String> ctorParams;
  final bool isReleaseMethod;
  final Set<String> releases;
  final List<_AddListener> adds;
  final String source;
  final LineInfo lineInfo;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final target = _assignedField(node.leftHandSide);
    if (target != null) {
      final field = fields[target];
      if (field != null) {
        final rhs = node.rightHandSide;
        final inferred = _inferType(rhs);
        field.type ??= inferred;
        if (inferred != null) field.constructed = true;
        if (rhs is SimpleIdentifier && ctorParams.contains(rhs.name)) {
          field.borrowed = true;
        }
      }
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isRefOnDispose(node) && node.argumentList.arguments.isNotEmpty) {
      _collectOnDisposeRelease(
        node.argumentList.arguments.first,
        fields: fields,
        releases: releases,
        adds: adds,
        source: source,
        lineInfo: lineInfo,
      );
    }
    final receiver = _receiverName(node.target);
    if (receiver != null) {
      final name = node.methodName.name;
      if (isReleaseMethod && _isReleaseName(name)) {
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
      } else if (isReleaseMethod &&
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

/// True for `ref.onDispose(...)` with a bare `ref` target, including
/// the cascaded `ref..onDispose(...)` form.
bool _isRefOnDispose(MethodInvocation node) {
  if (node.methodName.name != 'onDispose') return false;
  final target = node.target;
  if (target is SimpleIdentifier) return target.name == 'ref';
  final parent = node.parent;
  if (target == null && parent is CascadeExpression) {
    final cascade = parent.target;
    return cascade is SimpleIdentifier && cascade.name == 'ref';
  }
  return false;
}

/// Counts an `onDispose` registration as a release: closures run with
/// full dispose semantics (releases and listener pairing), and
/// `resource.dispose`/`.cancel` tear-offs release the receiver.
void _collectOnDisposeRelease(
  Argument arg, {
  required Map<String, _Field> fields,
  required Set<String> releases,
  required List<_AddListener> adds,
  required String source,
  required LineInfo lineInfo,
}) {
  if (arg is FunctionExpression) {
    arg.body.accept(
      _MemberScanner(
        fields: fields,
        ctorParams: const {},
        isReleaseMethod: true,
        releases: releases,
        adds: adds,
        source: source,
        lineInfo: lineInfo,
      ),
    );
    return;
  }
  if (arg is PrefixedIdentifier && _isReleaseName(arg.identifier.name)) {
    releases.add(arg.prefix.name);
    return;
  }
  if (arg is PropertyAccess && _isReleaseName(arg.propertyName.name)) {
    final receiver = _receiverName(arg.target);
    if (receiver != null) releases.add(receiver);
  }
}

/// True for a release method name (`dispose`/`cancel`/`close`).
bool _isReleaseName(String name) =>
    name == 'dispose' || name == 'cancel' || name == 'close';

/// True for `State`/`ConsumerState`/`StateNotifier` superclasses
/// (dispose-only release discipline).
bool _isStateLike(NamedType? superclass) {
  if (superclass == null) return false;
  const names = {'State', 'ConsumerState', 'StateNotifier'};
  return names.contains(superclass.name.lexeme);
}

/// True for Riverpod notifier superclasses (cleanup via
/// `ref.onDispose`, never release methods).
bool _isNotifierLike(NamedType? superclass) {
  if (superclass == null) return false;
  const names = {'Notifier', 'AsyncNotifier'};
  return names.contains(superclass.name.lexeme);
}

/// True for a method name in which releases count: `dispose`
/// always, plus `close`/`stop`/`cancel` outside State/Notifier.
bool _isReleaseMethod(String name, bool extended) {
  if (name == 'dispose') return true;
  return extended && (name == 'close' || name == 'stop' || name == 'cancel');
}

/// Names bound by [node]'s constructors as plain value parameters
/// (field and super formals excluded: they are not value sources).
Set<String> _constructorParams(ClassDeclaration node) {
  final names = <String>{};
  for (final member in node.body.members) {
    if (member is ConstructorDeclaration) {
      for (final parameter in member.parameters.parameters) {
        final name = parameter.name?.lexeme;
        if (name == null ||
            parameter is FieldFormalParameter ||
            parameter is SuperFormalParameter) {
          continue;
        }
        names.add(name);
      }
    }
  }
  return names;
}

/// Fields initialized straight from the constructor (`this.x`).
Set<String> _fieldFormals(ClassDeclaration node) {
  final names = <String>{};
  for (final member in node.body.members) {
    if (member is ConstructorDeclaration) {
      for (final parameter in member.parameters.parameters) {
        if (parameter is FieldFormalParameter) {
          names.add(parameter.name.lexeme);
        }
      }
    }
  }
  return names;
}

/// Field name assigned by [lhs] (`field` or `this.field`), or null.
String? _assignedField(Expression lhs) {
  if (lhs is SimpleIdentifier) return lhs.name;
  if (lhs is PropertyAccess && lhs.target is ThisExpression) {
    return lhs.propertyName.name;
  }
  return null;
}
