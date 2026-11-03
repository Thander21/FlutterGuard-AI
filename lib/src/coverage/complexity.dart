// SYS-COV-001: McCabe cyclomatic complexity per declaration.
//
// Pure, synchronous, AST-sited. Only named declarations WITH bodies
// are scored (functions, methods, constructors); closures and local
// functions fold their branches into the enclosing entry, and
// bodiless declarations (abstract/external) are skipped.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Cyclomatic complexity of one scored declaration.
class MethodComplexity {
  const MethodComplexity({
    required this.name,
    required this.line,
    required this.endLine,
    required this.complexity,
  });

  /// `Class.method` or a bare function name.
  final String name;

  /// 1-based first line.
  final int line;

  /// 1-based last line (inclusive).
  final int endLine;

  final int complexity;

  @override
  String toString() => '$name (lines $line-$endLine): CC $complexity';
}

/// Scores every named declaration with a body in [source], in source
/// order (SYS-COV-001 §2 counting table).
List<MethodComplexity> analyzeComplexity(String source, {String? path}) {
  final result = parseString(
    content: source,
    path: path ?? 'complexity.dart',
    throwIfDiagnostics: false,
  );
  final collector = _ComplexityCollector(result.lineInfo);
  result.unit.accept(collector);
  return collector.methods;
}

class _ComplexityCollector extends RecursiveAstVisitor<void> {
  _ComplexityCollector(this._lineInfo);

  final LineInfo _lineInfo;
  final List<MethodComplexity> methods = [];
  final List<String?> _classStack = [];
  final List<int> _branchStack = [];

  String? get _className =>
      _classStack.reversed.firstWhere((n) => n != null, orElse: () => null);

  void _count() {
    if (_branchStack.isNotEmpty) {
      _branchStack[_branchStack.length - 1]++;
    }
  }

  void _pushClass(String? name, AstNode node, void Function() visit) {
    _classStack.add(name);
    visit();
    _classStack.removeLast();
  }

  /// Opens a scored entry for [node] when it has a Dart body and no
  /// entry is already open (nested declarations fold into the outer).
  void _entry(String name, AstNode node, FunctionBody body) {
    if (body is EmptyFunctionBody || body is NativeFunctionBody) {
      superVisit(node);
      return;
    }
    if (_branchStack.isNotEmpty) {
      superVisit(node);
      return;
    }
    _branchStack.add(0);
    superVisit(node);
    final branches = _branchStack.removeLast();
    methods.add(MethodComplexity(
      name: name,
      line: _lineInfo.getLocation(node.offset).lineNumber,
      endLine: _lineInfo.getLocation(node.end).lineNumber,
      complexity: 1 + branches,
    ));
  }

  /// Recurses without re-entering the entry logic. Each override calls
  /// the matching `super.visitX`, so this dispatches on node type.
  void superVisit(AstNode node) {
    if (node is FunctionDeclaration) {
      super.visitFunctionDeclaration(node);
    } else if (node is MethodDeclaration) {
      super.visitMethodDeclaration(node);
    } else if (node is ConstructorDeclaration) {
      super.visitConstructorDeclaration(node);
    } else {
      node.visitChildren(this);
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _pushClass(node.name.lexeme, node, () => super.visitClassDeclaration(node));

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _pushClass(node.name.lexeme, node, () => super.visitMixinDeclaration(node));

  @override
  void visitEnumDeclaration(EnumDeclaration node) =>
      _pushClass(node.name.lexeme, node, () => super.visitEnumDeclaration(node));

  // No extension-type override: the AST node is experimental in the
  // pinned analyzer, and `// ignore:` comments violate FG-LINT-009.
  // Methods inside extension types are scored with bare names.
  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) =>
      _pushClass(
          node.name?.lexeme, node, () => super.visitExtensionDeclaration(node));

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _entry(node.name.lexeme, node, node.functionExpression.body);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final name = node.name.lexeme;
    final cls = _className;
    _entry(cls == null ? name : '$cls.$name', node, node.body);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final cls = _className ?? '';
    final name = node.name?.lexeme;
    _entry(name == null ? cls : '$cls.$name', node, node.body);
  }

  @override
  void visitIfStatement(IfStatement node) {
    _count();
    super.visitIfStatement(node);
  }

  @override
  void visitIfElement(IfElement node) {
    _count();
    super.visitIfElement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    _count();
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    _count();
    super.visitForElement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _count();
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    _count();
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    _count();
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    _count();
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    _count();
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _count();
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    switch (node.operator.type) {
      case TokenType.AMPERSAND_AMPERSAND:
      case TokenType.BAR_BAR:
      case TokenType.QUESTION_QUESTION:
        _count();
      default:
        break;
    }
    super.visitBinaryExpression(node);
  }
}
