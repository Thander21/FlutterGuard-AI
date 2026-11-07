// SYS-MUT-001: surgical mutation sites and source rewriter.
//
// Pure, synchronous, AST-sited: only real operator and literal nodes
// are mutated, so strings, comments, and generic type arguments are
// never touched.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// One surgical mutation site: a single operator or literal rewrite.
class Mutant {
  const Mutant({
    required this.offset,
    required this.line,
    required this.operator,
    required this.original,
    required this.replacement,
  });

  /// 0-based offset of the site in the source.
  final int offset;

  /// 1-based line number of the site.
  final int line;

  /// The mutated operator or literal lexeme (e.g. `>`, `==`, `true`).
  final String operator;

  final String original;
  final String replacement;

  @override
  String toString() => 'line $line: $original -> $replacement';
}

/// Finds every mutation site of the chaos operators in [source],
/// ordered by offset (Architecture §2.3).
///
/// Unparseable regions yield a partial AST; valid sites are still
/// reported (same tolerance as the rule visitors).
List<Mutant> findMutants(String source, {String? path}) {
  final result = parseString(
    content: source,
    path: path ?? 'mutation.dart',
    throwIfDiagnostics: false,
  );
  final collector = _MutantCollector(result.lineInfo);
  result.unit.accept(collector);
  collector.mutants.sort((a, b) => a.offset.compareTo(b.offset));
  return collector.mutants;
}

/// Returns [source] with [mutant] applied (single-site replacement).
///
/// Throws [StateError] when the site does not match — a mutant from
/// another source must never silently rewrite the wrong text.
String applyMutant(String source, Mutant mutant) {
  final end = mutant.offset + mutant.original.length;
  if (mutant.offset < 0 ||
      end > source.length ||
      source.substring(mutant.offset, end) != mutant.original) {
    throw StateError('mutant does not match the source at $mutant');
  }
  return source.replaceRange(mutant.offset, end, mutant.replacement);
}

class _MutantCollector extends RecursiveAstVisitor<void> {
  _MutantCollector(this._lineInfo);

  final LineInfo _lineInfo;
  final List<Mutant> mutants = [];

  void _add(Token token, String replacement) {
    mutants.add(
      Mutant(
        offset: token.offset,
        line: _lineInfo.getLocation(token.offset).lineNumber,
        operator: token.lexeme,
        original: token.lexeme,
        replacement: replacement,
      ),
    );
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final replacement = switch (node.operator.type) {
      TokenType.GT => '<',
      TokenType.GT_EQ => '<=',
      TokenType.LT_EQ => '>=',
      TokenType.EQ_EQ => '!=',
      _ => null,
    };
    if (replacement != null) _add(node.operator, replacement);
    super.visitBinaryExpression(node);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    _add(node.literal, node.value ? 'false' : 'true');
    super.visitBooleanLiteral(node);
  }
}
