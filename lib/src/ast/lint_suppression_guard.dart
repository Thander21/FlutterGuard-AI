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
  const LintSuppressionViolation({
    required this.line,
    required this.message,
    this.isCommentOnly = false,
  });

  /// 1-based line number of the suppression comment or catch clause.
  @override
  final int line;

  @override
  final String message;

  /// True for a catch holding only a comment (warns, not errors).
  final bool isCommentOnly;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-LINT-009 violation found.
List<LintSuppressionViolation> analyzeLintSuppressionFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = LintSuppressionGuard(result.lineInfo, source);
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
/// Scope (R2-3): any `//` line comment containing a bare `ignore:` or
/// `ignore_for_file:` (case-sensitive, anywhere in the file), and any
/// catch clause whose body holds no real statement. Justified
/// suppressions (trailing or preceding-line `//` rationale), doc
/// (`///`), and block (`/* */`) comments are never suppressions and
/// stay clean. Comment-only catches warn; fully-empty catches error.
class LintSuppressionGuard extends RecursiveAstVisitor<void> {
  LintSuppressionGuard(this._lineInfo, this._source);

  final LineInfo _lineInfo;
  final String _source;
  final List<LintSuppressionViolation> violations = [];

  late final List<String> _lines = _source.split('\n');

  /// Flags [lexeme] when it is a bare `//` suppression comment.
  ///
  /// A suppression carrying trailing rationale (a second `//`
  /// after the directive with non-blank text) is a reviewed
  /// decision and stays clean (SYS-CAL-002 P1-5), as is one with
  /// rationale on the immediately preceding own-line `//`
  /// comment (SYS-CAL-003 R2-3).
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
    if (_isJustified(lexeme, directive)) return;
    if (_hasPrecedingRationale(offset)) return;
    violations.add(
      LintSuppressionViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message:
            "'//$directive' suppressions are forbidden; "
            'fix the root cause instead (or justify with // rationale '
            'on the same or preceding line)',
      ),
    );
  }

  /// True when the line above [offset] carries `//` rationale: an
  /// own-line `//` comment (non-doc, non-ignore) with non-blank
  /// text and no blank gap.
  bool _hasPrecedingRationale(int offset) {
    final line = _lineInfo.getLocation(offset).lineNumber;
    if (line < 2) return false;
    final previous = _lines[line - 2].trim();
    if (!_isLineComment(previous)) return false;
    if (previous.contains('ignore_for_file:') || previous.contains('ignore:')) {
      return false;
    }
    return previous.substring(2).trim().isNotEmpty;
  }

  @override
  void visitCatchClause(CatchClause node) {
    if (node.body.statements.every((s) => s is EmptyStatement)) {
      final body = _source.substring(node.body.offset, node.body.end);
      final commentOnly = body.contains('//') || body.contains('/*');
      violations.add(
        LintSuppressionViolation(
          line: _lineInfo.getLocation(node.offset).lineNumber,
          message: commentOnly
              ? 'comment-only catch block swallows errors; '
                    'handle the error or rethrow'
              : 'empty catch block swallows errors; '
                    'handle the error or rethrow',
          isCommentOnly: commentOnly,
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

/// True when [lexeme] carries rationale after [directive]: a `//`
/// separator past the directive with non-blank text following it.
bool _isJustified(String lexeme, String directive) {
  final start = lexeme.indexOf(directive) + directive.length;
  final separator = lexeme.indexOf('//', start);
  if (separator == -1) return false;
  return lexeme.substring(separator + 2).trim().isNotEmpty;
}
