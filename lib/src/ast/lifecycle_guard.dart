// FG-LIFE-001: resource symmetry — releasable fields released in dispose().
//
// Per-class field map, parse-only (no type resolution): an explicit field
// type wins, initializer/assignment shapes infer the rest. A releasable
// field with no matching release call in a release method is flagged at
// its declaration; addListener without a paired removeListener is flagged
// at the call. Release methods include same-class helpers called from a
// release entry point (`dispose`, `destroy`, an `onDispose` closure)
// directly or one level further (K2). Vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
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
///
/// [releasers] injects the `releasers:` section (tests); when absent
/// it loads from the nearest config (absent section = defaults).
List<LifecycleViolation> analyzeLifecycleFile(
  String path, {
  RuleListConfig<String>? releasers,
}) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final extra =
      (releasers ?? RuleListConfig.load(path, 'releasers', _parseReleaser))
          .items
          .toSet();
  final guard = LifecycleGuard(source, result.lineInfo, extra);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Parses one `releasers:` entry: a non-empty method name, else null
/// (malformed entries are skipped, never file verdicts).
String? _parseReleaser(dynamic item) =>
    item is String && item.isNotEmpty ? item : null;

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

/// Shared per-class scan state: the field map plus the release and
/// listener collections the member scanners fill. Grouped so the
/// scanner constructor stays inside the MET params budget.
class _ClassScan {
  _ClassScan({
    required this.fields,
    required this.releases,
    required this.adds,
  });

  final Map<String, _Field> fields;
  final Set<String> releases;
  final List<_AddListener> adds;
}

/// Builds the per-class field map and emits symmetry violations.
class LifecycleGuard extends RecursiveAstVisitor<void> {
  LifecycleGuard(this._source, this._lineInfo, [this._extra = const {}]);

  final String _source;
  final LineInfo _lineInfo;

  /// Configured releaser names (`releasers:` section): extra release
  /// verbs and extended-class entry names.
  final Set<String> _extra;
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
    final releaseMethods = _releaseMethods(node, extended, _extra);
    final scan = _ClassScan(
      fields: fields,
      releases: <String>{},
      adds: <_AddListener>[],
    );
    for (final member in node.body.members) {
      if (member is MethodDeclaration) {
        member.body.accept(
          _MemberScanner(
            scan: scan,
            ctorParams: ctorParams,
            isReleaseMethod:
                !member.isStatic && releaseMethods.contains(member.name.lexeme),
            source: _source,
            lineInfo: _lineInfo,
            extraReleasers: _extra,
          ),
        );
      } else if (member is ConstructorDeclaration) {
        _scanConstructor(member, fields, ctorParams);
        member.body.accept(
          _MemberScanner(
            scan: scan,
            ctorParams: ctorParams,
            isReleaseMethod: false,
            source: _source,
            lineInfo: _lineInfo,
            extraReleasers: _extra,
          ),
        );
      }
    }
    final releases = scan.releases;
    final adds = scan.adds;
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
    required this.scan,
    required this.ctorParams,
    required this.isReleaseMethod,
    required this.source,
    required this.lineInfo,
    required this.extraReleasers,
  });

  final _ClassScan scan;
  final Set<String> ctorParams;
  final bool isReleaseMethod;
  final String source;
  final LineInfo lineInfo;
  final Set<String> extraReleasers;

  /// Locals aliasing a field (`final sub = _sub;`), so releases on
  /// the alias count for the field.
  final Map<String, String> _aliases = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    final aliased = initializer == null ? null : _receiverName(initializer);
    if (aliased != null && scan.fields.containsKey(aliased)) {
      _aliases[node.name.lexeme] = aliased;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final target = _assignedField(node.leftHandSide);
    if (target != null) {
      final field = scan.fields[target];
      if (field != null) {
        final rhs = node.rightHandSide;
        final inferred = _inferType(rhs);
        field.type ??= inferred;
        if (inferred != null) field.constructed = true;
        if (rhs is SimpleIdentifier &&
            (ctorParams.contains(rhs.name) ||
                _isEnclosingParameter(node, rhs.name))) {
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
        scan: scan,
        source: source,
        lineInfo: lineInfo,
        extraReleasers: extraReleasers,
      );
    }
    final named = _receiverName(node.target);
    final receiver = named == null ? null : _aliases[named] ?? named;
    if (receiver != null) {
      final name = node.methodName.name;
      if (isReleaseMethod && _isReleaseName(name, extraReleasers)) {
        scan.releases.add(receiver);
      } else if (name == 'addListener' &&
          !_inStaticMethod(node) &&
          node.argumentList.arguments.isNotEmpty) {
        final arg = node.argumentList.arguments.first;
        if (arg is SimpleIdentifier || arg is PrefixedIdentifier) {
          scan.adds.add(
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
        scan.releases.add(
          '$receiver#${_argSource(node.argumentList.arguments.first)}',
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  String _argSource(AstNode arg) => source.substring(arg.offset, arg.end);
}

/// Unwraps a release/listener receiver: `field`, `this.field`, or
/// either with a null assertion (`field!`).
String? _receiverName(Expression? target) {
  if (target is PostfixExpression && target.operator.lexeme == '!') {
    return _receiverName(target.operand);
  }
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
  required _ClassScan scan,
  required String source,
  required LineInfo lineInfo,
  required Set<String> extraReleasers,
}) {
  if (arg is FunctionExpression) {
    arg.body.accept(
      _MemberScanner(
        scan: scan,
        ctorParams: const {},
        isReleaseMethod: true,
        source: source,
        lineInfo: lineInfo,
        extraReleasers: extraReleasers,
      ),
    );
    return;
  }
  if (arg is PrefixedIdentifier &&
      _isReleaseName(arg.identifier.name, extraReleasers)) {
    scan.releases.add(arg.prefix.name);
    return;
  }
  if (arg is PropertyAccess &&
      _isReleaseName(arg.propertyName.name, extraReleasers)) {
    final receiver = _receiverName(arg.target);
    if (receiver != null) scan.releases.add(receiver);
  }
}

/// True for a release method name (`dispose`/`cancel`/`close` plus
/// configured `releasers:` verbs).
bool _isReleaseName(String name, [Set<String> extra = const {}]) =>
    name == 'dispose' ||
    name == 'cancel' ||
    name == 'close' ||
    extra.contains(name);

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

/// True for a release entry point: `dispose` always, plus
/// `close`/`stop`/`cancel`/`destroy` and configured `releasers:`
/// names outside State/Notifier.
bool _isReleaseMethod(
  String name,
  bool extended, [
  Set<String> extra = const {},
]) {
  if (name == 'dispose') return true;
  const extendedNames = {'close', 'stop', 'cancel', 'destroy'};
  return extended && (extendedNames.contains(name) || extra.contains(name));
}

/// Instance methods of [node] in which releases count: the release
/// entry points ([_isReleaseMethod]), the same-class methods they
/// call (and those an `onDispose` closure or tear-off reaches), plus
/// one more level of self-calls (K2). Deeper chains stay unseen
/// (fail-closed).
Set<String> _releaseMethods(
  ClassDeclaration node,
  bool extended,
  Set<String> extra,
) {
  final methods = <String, MethodDeclaration>{
    for (final member in node.body.members)
      if (member is MethodDeclaration && !member.isStatic)
        member.name.lexeme: member,
  };
  final names = methods.keys.toSet();
  final entries = names
      .where((n) => _isReleaseMethod(n, extended, extra))
      .toSet();
  final direct = <String>{};
  for (final method in methods.values) {
    method.body.accept(_SelfCallCollector(names, direct, onDisposeOnly: true));
  }
  for (final entry in entries) {
    methods[entry]!.body.accept(_SelfCallCollector(names, direct));
  }
  final indirect = <String>{};
  for (final name in direct) {
    methods[name]!.body.accept(_SelfCallCollector(names, indirect));
  }
  return {...entries, ...direct, ...indirect};
}

/// Collects same-class method calls (`m()`, `this.m()`) into [found].
/// With [onDisposeOnly], collects only the calls inside `ref.onDispose`
/// closures plus bare method tear-offs passed to `ref.onDispose`.
class _SelfCallCollector extends RecursiveAstVisitor<void> {
  _SelfCallCollector(this.names, this.found, {this.onDisposeOnly = false});

  final Set<String> names;
  final Set<String> found;
  final bool onDisposeOnly;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!onDisposeOnly) {
      final target = node.target;
      final name = node.methodName.name;
      if ((target == null || target is ThisExpression) &&
          names.contains(name)) {
        found.add(name);
      }
    } else if (_isRefOnDispose(node) &&
        node.argumentList.arguments.isNotEmpty) {
      final arg = node.argumentList.arguments.first;
      if (arg is FunctionExpression) {
        arg.body.accept(_SelfCallCollector(names, found));
      } else if (arg is SimpleIdentifier && names.contains(arg.name)) {
        found.add(arg.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// True when [node] sits in a static method: a static forwarder owns
/// no instance lifecycle to pair a listener with.
bool _inStaticMethod(AstNode node) {
  final method = node.thisOrAncestorOfType<MethodDeclaration>();
  return method != null && method.isStatic;
}

/// True when [name] is a parameter of a function or method enclosing
/// [node]: the value is received, not self-instantiated (K1).
bool _isEnclosingParameter(AstNode node, String name) {
  for (AstNode? current = node; current != null; current = current.parent) {
    if (current is ClassDeclaration) return false;
    final FormalParameterList? parameters;
    if (current is FunctionExpression) {
      parameters = current.parameters;
    } else if (current is MethodDeclaration) {
      parameters = current.parameters;
    } else {
      continue;
    }
    final declared = parameters?.parameters ?? const <FormalParameter>[];
    if (declared.any((p) => p.name?.lexeme == name)) return true;
  }
  return false;
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
