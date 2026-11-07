// FG-ASYNC-002: forbid BuildContext use after await without a mounted guard.
//
// A widget that awaits and then touches its BuildContext (or setState)
// throws when the route was popped mid-request. Every async body is
// scanned statement by statement: an `await` arms the gate, a mounted
// guard disarms it, and any later `context` read or `setState` is
// flagged. Parsing only (no type resolution), so vectors need no
// dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// A single FG-ASYNC-002 violation.
class AsyncContextViolation implements RuleViolation {
  const AsyncContextViolation({required this.line, required this.message});

  /// 1-based line number of the offending context use.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ASYNC-002 violation found.
List<AsyncContextViolation> analyzeAsyncFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = AsyncContextGuard(result.lineInfo);
  result.unit.accept(guard);
  final seen = <String>{};
  final unique = guard.violations
      .where((v) => seen.add('${v.line}|${v.message}'))
      .toList();
  return unique..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags post-await `context` reads and `setState` calls.
///
/// Scope (R2-1): every `async` block body (methods, functions,
/// closures) is scanned independently with its own armed state.
/// `await` arms the gate from the next statement on; early returns
/// taken when unmounted (`!mounted`, `x || !context.mounted`) disarm
/// it; `if (mounted)` / `if (x && context.mounted)` blocks are scanned
/// fresh. Compound statements flag only their header expressions:
/// `if`/`for`/`while`/`try`/`switch` bodies are scanned statement by
/// statement, so inner guards hold. Nested closure bodies inherit the
/// state the statement was entered with (the awaited call's own
/// builders run before the gap), so an inner mounted guard disarms
/// only the closure; awaits never cross bodies.
/// Only unshadowed `context` reads count: a nearer local,
/// loop/catch-variable, or non-`BuildContext` parameter binding
/// passes, as do foreign `x.context` properties (`this`/`super`
/// receivers still count).
class AsyncContextGuard extends RecursiveAstVisitor<void> {
  AsyncContextGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<AsyncContextViolation> violations = [];

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    if (node.keyword?.lexeme == 'async') {
      _scanStatements(node.block.statements, false);
    }
    super.visitBlockFunctionBody(node);
  }

  /// Scans [statements] threading the armed state; returns its final value.
  bool _scanStatements(List<Statement> statements, bool armed) {
    for (final raw in statements) {
      final statement = _unlabeled(raw);
      if (_isEarlyReturnGuard(statement)) {
        armed = false;
        final guard = statement as IfStatement;
        _scanLeading(guard.thenStatement);
        final elseBranch = guard.elseStatement;
        if (elseBranch != null) {
          _scanStatements(_branchStatements(elseBranch), false);
        }
        continue;
      }
      if (statement is IfStatement && _requiresMounted(statement.expression)) {
        final thenArmed = _scanBranch(statement.thenStatement, false);
        final elseBranch = statement.elseStatement;
        final elseArmed = elseBranch == null
            ? armed
            : _scanBranch(elseBranch, true);
        armed = thenArmed || elseArmed;
        continue;
      }
      armed = _scanStatement(statement, armed);
    }
    return armed;
  }

  /// Scans one statement entered with [armed]; returns the armed state
  /// after it. Only header expressions are flagged flat; compound
  /// bodies are scanned statement by statement, so inner guards hold.
  /// Closures in a header inherit the entry state: the awaited call's
  /// own arguments and builders run before the gap (K4).
  bool _scanStatement(Statement statement, bool armed) {
    final headers = _headerNodes(statement);
    for (final header in headers) {
      _scanFlat(header, armed, armed);
    }
    final entered = armed || headers.any(_containsAwait);
    return _scanBodies(statement, entered);
  }

  /// Scans an `if` branch; a branch that always exits (trailing
  /// `return`/`throw`/`rethrow`) never arms the code after the `if`.
  bool _scanBranch(Statement branch, bool entered) {
    final statements = _branchStatements(branch);
    final armed = _scanStatements(statements, entered);
    return armed && !_alwaysExits(statements);
  }

  /// Flags [node]'s sinks when [armed], then scans its closures
  /// with [closureArmed].
  void _scanFlat(AstNode node, bool armed, bool closureArmed) {
    if (armed) {
      _flagSinks(node);
    }
    for (final body in _closureBodies(node)) {
      _scanClosureBody(body, closureArmed);
    }
  }

  /// Scans the non-return statements of a guard block: they run unmounted.
  void _scanLeading(Statement branch) {
    if (branch is Block && branch.statements.length > 1) {
      _scanStatements(
        branch.statements.sublist(0, branch.statements.length - 1),
        true,
      );
    }
  }

  /// Flags every context sink inside [node].
  void _flagSinks(AstNode node) {
    for (final sink in _contextSinks(node)) {
      violations.add(
        AsyncContextViolation(
          line: _lineInfo.getLocation(sink.offset).lineNumber,
          message: sink.message,
        ),
      );
    }
  }

  /// Scans one closure body with the enclosing armed state: an inner
  /// mounted guard disarms the closure, unguarded deferred uses flag.
  void _scanClosureBody(FunctionBody body, bool armed) {
    if (body is BlockFunctionBody) {
      _scanStatements(body.block.statements, armed);
      return;
    }
    if (body is ExpressionFunctionBody) {
      final expression = body.expression;
      _scanFlat(expression, armed, armed || _containsAwait(expression));
    }
  }

  /// Threads [entered] through a compound statement's bodies.
  bool _scanBodies(Statement statement, bool entered) {
    if (statement is IfStatement) {
      final thenArmed = _scanBranch(statement.thenStatement, entered);
      final elseBranch = statement.elseStatement;
      final elseArmed = elseBranch == null
          ? entered
          : _scanBranch(elseBranch, entered);
      return thenArmed || elseArmed;
    }
    if (statement is ForStatement) {
      return _scanLoop(statement.body, entered);
    }
    if (statement is WhileStatement) {
      return _scanLoop(statement.body, entered);
    }
    if (statement is DoStatement) {
      final armed = _scanLoop(statement.body, entered);
      if (armed) {
        _flagSinks(statement.condition);
      }
      return armed;
    }
    if (statement is TryStatement) {
      return _scanTry(statement, entered);
    }
    if (statement is SwitchStatement) {
      var armed = entered;
      for (final member in statement.members) {
        armed = _scanStatements(member.statements, entered) || armed;
      }
      return armed;
    }
    if (statement is Block) {
      return _scanStatements(statement.statements, entered);
    }
    return entered;
  }

  /// A loop body that suspends re-enters armed on the next iteration.
  bool _scanLoop(Statement body, bool entered) {
    final bodyArmed = entered || _containsAwait(body);
    return _scanStatements(_branchStatements(body), bodyArmed) || bodyArmed;
  }

  /// Catch clauses may start after any gap of the try body; the
  /// finally block after any gap of the body or the catches.
  bool _scanTry(TryStatement statement, bool entered) {
    var armed = _scanStatements(statement.body.statements, entered);
    final catchEntry = entered || _containsAwait(statement.body);
    for (final clause in statement.catchClauses) {
      armed = _scanStatements(clause.body.statements, catchEntry) || armed;
    }
    final finallyBlock = statement.finallyBlock;
    if (finallyBlock == null) return armed;
    final finallyEntry =
        catchEntry ||
        statement.catchClauses.any((clause) => _containsAwait(clause.body));
    return _scanStatements(finallyBlock.statements, finallyEntry);
  }
}

/// [statement] without its labels (`label: for (...)`).
Statement _unlabeled(Statement statement) {
  var current = statement;
  while (current is LabeledStatement) {
    current = current.statement;
  }
  return current;
}

/// The expressions of [statement] evaluated before its bodies: a
/// simple statement is its own header; `do`, `try` and blocks have
/// none (the `do` condition is scanned after its body).
List<AstNode> _headerNodes(Statement statement) {
  if (statement is IfStatement) return [statement.expression];
  if (statement is ForStatement) {
    return [
      statement.forLoopParts,
      if (statement.awaitKeyword != null) statement,
    ];
  }
  if (statement is WhileStatement) return [statement.condition];
  if (statement is SwitchStatement) return [statement.expression];
  if (statement is DoStatement ||
      statement is TryStatement ||
      statement is Block) {
    return const [];
  }
  return [statement];
}

/// Statements of a branch: a block's list, or the lone statement itself.
List<Statement> _branchStatements(Statement branch) =>
    branch is Block ? branch.statements : [branch];

/// True when the last of [statements] leaves the function or loop
/// body unconditionally (`return`, `throw`, `rethrow`).
bool _alwaysExits(List<Statement> statements) {
  if (statements.isEmpty) return false;
  final last = _unlabeled(statements.last);
  if (last is ReturnStatement) return true;
  if (last is! ExpressionStatement) return false;
  final expression = last.expression;
  return expression is ThrowExpression || expression is RethrowExpression;
}

/// True when [statement] is an early return taken whenever the widget
/// is unmounted (`if (!mounted) return;`, `if (x || !context.mounted)
/// return;`), bare or wrapped in a block whose last statement returns.
bool _isEarlyReturnGuard(Statement statement) {
  if (statement is! IfStatement) return false;
  if (!_exitsWhenUnmounted(statement.expression)) return false;
  final branch = statement.thenStatement;
  if (branch is ReturnStatement) return true;
  return branch is Block &&
      branch.statements.isNotEmpty &&
      branch.statements.last is ReturnStatement;
}

/// True when [condition] holds whenever the widget is unmounted: a
/// negated mounted requirement, or an `||` chain with one.
bool _exitsWhenUnmounted(Expression condition) {
  final expression = condition.unParenthesized;
  if (expression is PrefixExpression && expression.operator.lexeme == '!') {
    return _requiresMounted(expression.operand);
  }
  if (expression is BinaryExpression && expression.operator.lexeme == '||') {
    return _exitsWhenUnmounted(expression.leftOperand) ||
        _exitsWhenUnmounted(expression.rightOperand);
  }
  return false;
}

/// True when [condition] can only hold while mounted: a mounted check,
/// or an `&&` chain with one (`x != null && context.mounted`).
bool _requiresMounted(Expression condition) {
  final expression = condition.unParenthesized;
  if (expression is BinaryExpression && expression.operator.lexeme == '&&') {
    return _requiresMounted(expression.leftOperand) ||
        _requiresMounted(expression.rightOperand);
  }
  return _isMountedCheck(expression);
}

/// True for `mounted`, `context.mounted`, `this.mounted`, or any
/// `*.mounted` property read.
bool _isMountedCheck(Expression expression) {
  if (expression is SimpleIdentifier) return expression.name == 'mounted';
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name == 'mounted';
  }
  if (expression is PropertyAccess) {
    return expression.propertyName.name == 'mounted';
  }
  return false;
}

/// True when [node] contains an `await` outside any nested function.
bool _containsAwait(AstNode node) {
  final finder = _TopAwaitFinder();
  node.accept(finder);
  return finder.found;
}

class _TopAwaitFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A nested closure never suspends the enclosing body.
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // A nested declaration never suspends the enclosing body.
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    found = true;
  }
}

/// One post-await context use: source [offset] plus its message.
class _Sink {
  const _Sink(this.offset, this.message);

  final int offset;
  final String message;
}

/// Every `context` read and `setState` call inside [node].
List<_Sink> _contextSinks(AstNode node) {
  final collector = _SinkCollector();
  node.accept(collector);
  return collector.sinks;
}

class _SinkCollector extends RecursiveAstVisitor<void> {
  final List<_Sink> sinks = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'context' &&
        !_isDeclaration(node) &&
        !_isMethodName(node) &&
        !_isMountedReceiver(node) &&
        !_isForeignProperty(node) &&
        !_isShadowed(node)) {
      sinks.add(
        _Sink(
          node.offset,
          'BuildContext used after async gap without mounted check',
        ),
      );
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Deferred bodies inherit the armed state via _scanStatement,
    // never collected flat (SYS-CAL-003 R2-1).
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState' &&
        (node.target == null || node.target is ThisExpression)) {
      sinks.add(
        _Sink(
          node.offset,
          'setState() called after async gap without mounted check',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}

/// True when [node] declares something rather than reading `context`.
bool _isDeclaration(SimpleIdentifier node) {
  final parent = node.parent;
  return parent is FormalParameter ||
      parent is VariableDeclaration ||
      parent is FunctionDeclaration ||
      parent is MethodDeclaration ||
      parent is ConstructorDeclaration ||
      parent is DeclaredIdentifier ||
      parent is CatchClause ||
      parent is Combinator;
}

/// True when [node] is the invoked `context` in `x.context()`.
bool _isMethodName(SimpleIdentifier node) {
  final parent = node.parent;
  return parent is MethodInvocation && parent.methodName == node;
}

/// True when [node] is the receiver of a `.mounted` read.
bool _isMountedReceiver(SimpleIdentifier node) {
  final parent = node.parent;
  if (parent is PrefixedIdentifier) {
    return parent.prefix == node && parent.identifier.name == 'mounted';
  }
  if (parent is PropertyAccess) {
    return parent.target == node && parent.propertyName.name == 'mounted';
  }
  return false;
}

/// True when [node] is the property (not the receiver) of a foreign
/// `x.context` read: any receiver except `this`/`super`.
bool _isForeignProperty(SimpleIdentifier node) {
  final parent = node.parent;
  if (parent is PrefixedIdentifier) {
    return parent.identifier == node;
  }
  if (parent is PropertyAccess) {
    return parent.propertyName == node &&
        parent.target is! ThisExpression &&
        parent.target is! SuperExpression;
  }
  return false;
}

/// True when a nearer binding shadows the widget's `context` for
/// [node]: any enclosing declaration of `context` other than a
/// `BuildContext`-typed formal parameter. Each enclosing scope is
/// queried (siblings declare; ancestors only delimit), so locals,
/// loop/catch variables, and parameters all shadow.
/// Name-based, parse-only.
bool _isShadowed(SimpleIdentifier node) {
  AstNode? scope = node.parent;
  while (scope != null) {
    if (scope is CatchClause &&
        (scope.exceptionParameter?.name.lexeme == 'context' ||
            scope.stackTraceParameter?.name.lexeme == 'context')) {
      return true;
    }
    if (scope is ForStatement && _loopDeclares(scope.forLoopParts)) {
      return true;
    }
    if (scope is ForElement && _loopDeclares(scope.forLoopParts)) {
      return true;
    }
    if (scope is Block && _statementsDeclare(scope.statements)) {
      return true;
    }
    final parameters = _declaredParameters(scope);
    if (parameters != null) {
      for (final parameter in parameters) {
        if (parameter.name?.lexeme == 'context') {
          return !_isBuildContextType(parameter.type);
        }
      }
    }
    scope = scope.parent;
  }
  return false;
}

/// True when any direct statement of [statements] declares `context`.
bool _statementsDeclare(List<Statement> statements) {
  for (final statement in statements) {
    if (statement is VariableDeclarationStatement) {
      for (final variable in statement.variables.variables) {
        if (variable.name.lexeme == 'context') return true;
      }
    }
  }
  return false;
}

/// True when the loop parts of [parts] declare `context`.
bool _loopDeclares(ForLoopParts parts) {
  if (parts is ForEachPartsWithDeclaration) {
    return parts.loopVariable.name.lexeme == 'context';
  }
  if (parts is ForPartsWithDeclarations) {
    return parts.variables.variables.any(
      (variable) => variable.name.lexeme == 'context',
    );
  }
  return false;
}

/// The parameter list of a function-like [node], or null.
List<FormalParameter>? _declaredParameters(AstNode node) {
  if (node is MethodDeclaration) return node.parameters?.parameters;
  if (node is ConstructorDeclaration) return node.parameters.parameters;
  if (node is FunctionDeclaration) {
    return node.functionExpression.parameters?.parameters;
  }
  if (node is FunctionExpression) return node.parameters?.parameters;
  return null;
}

/// True when [type] names `BuildContext` (parse-only, name-based).
bool _isBuildContextType(TypeAnnotation? type) {
  return type is NamedType && type.name.lexeme == 'BuildContext';
}

/// Top-level closure bodies inside [node] (nested closures inherit
/// from their own body scan instead).
List<FunctionBody> _closureBodies(AstNode node) {
  final collector = _TopClosureCollector();
  node.accept(collector);
  return collector.bodies;
}

class _TopClosureCollector extends RecursiveAstVisitor<void> {
  final List<FunctionBody> bodies = [];

  @override
  void visitFunctionExpression(FunctionExpression node) {
    bodies.add(node.body);
    // Do not descend: nested closures are scanned from their own body.
  }
}
