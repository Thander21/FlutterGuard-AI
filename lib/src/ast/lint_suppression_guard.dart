// FG-LINT-009: forbid suppressions and empty catch blocks.
//
// Suppressions silence the gate itself and an empty `catch` buries the
// failure: both trade a compile-time finding for a production incident
// (Root Cause Only). Parsing only (no type resolution), so vectors need
// no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// A single FG-LINT-009 violation.
class LintSuppressionViolation implements RuleViolation {
  const LintSuppressionViolation({required this.line, required this.message});

  /// 1-based line number of the suppression comment or catch clause.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-LINT-009 violation found.
List<LintSuppressionViolation> analyzeLintSuppressionFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = LintSuppressionGuard(result.lineInfo);
  result.unit.accept(guard);
  _scanComments(result.unit, guard.checkComment);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Walks every comment in [unit] outside the AST visitor walk.
///
/// `CommentToken` is not exported by package:analyzer, so the
/// `precedingComments` chain is walked with one contained dynamic
/// variable; only the stable `lexeme`/`offset`/`next` members are read.
void _scanComments(
  CompilationUnit unit,
  void Function(String lexeme, int offset) onComment,
) {
  Token? token = unit.beginToken;
  while (token != null && !token.isEof) {
    dynamic comment = token.precedingComments;
    while (comment != null) {
      onComment(comment.lexeme as String, comment.offset as int);
      comment = comment.next;
    }
    token = token.next;
  }
}

/// Flags suppression comments and empty catch blocks.
///
/// Scope (v0): any `//` line comment containing `ignore:` or
/// `ignore_for_file:` (case-sensitive, anywhere in the file), and any
/// catch clause whose body holds no real statement. Doc (`///`) and
/// block (`/* */`) comments are never suppressions and stay clean.
class LintSuppressionGuard extends RecursiveAstVisitor<void> {
  LintSuppressionGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<LintSuppressionViolation> violations = [];

  /// Flags [lexeme] when it is a `//` suppression comment.
  void checkComment(String lexeme, int offset) {
    if (!_isLineComment(lexeme)) return;
    final String? directive;
    if (lexeme.contains('ignore_for_file:')) {
      directive = 'ignore_for_file:';
    } else if (lexeme.contains('ignore:')) {
      directive = 'ignore:';
    } else {
      return;
    }
    violations.add(
      LintSuppressionViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message:
            "'//$directive' suppressions are forbidden; "
            'fix the root cause instead',
      ),
    );
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (node.body.statements.every((s) => s is EmptyStatement)) {
      violations.add(
        LintSuppressionViolation(
          line: _lineInfo.getLocation(node.offset).lineNumber,
          message:
              'empty catch block swallows errors; handle the error or rethrow',
        ),
      );
    }
    super.visitCatchClause(node);
  }
}

/// True for `//` comments, excluding `///` doc comments (`////…` counts
/// as an ordinary comment, matching the analyzer).
bool _isLineComment(String lexeme) {
  if (!lexeme.startsWith('//')) return false;
  if (!lexeme.startsWith('///')) return true;
  return lexeme.length > 3 && lexeme[3] == '/';
}
