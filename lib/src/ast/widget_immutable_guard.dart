// FG-WID-008: forbid mutable fields in StatelessWidget.
//
// Flutter recreates stateless widgets on every rebuild, so a mutable
// instance field silently resets while the framework assumes an immutable
// configuration. Stateless configuration must be final. Parsing only (no
// type resolution), so vectors need no dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Stateless bases whose instance fields must all be final.
///
/// Closed v0 set: `ConsumerWidget` carries the same immutability contract
/// as `StatelessWidget`.
const _statelessSuperclasses = <String>{
  'StatelessWidget',
  'ConsumerWidget',
};

/// A single FG-WID-008 violation.
class WidgetImmutableViolation implements RuleViolation {
  const WidgetImmutableViolation({required this.line, required this.message});

  /// 1-based line number of the offending field name.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-WID-008 violation found.
List<WidgetImmutableViolation> analyzeWidgetImmutableFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = WidgetImmutableGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags non-final instance fields in stateless widgets.
///
/// Scope (v0): classes directly extending `StatelessWidget` or
/// `ConsumerWidget` (unqualified or prefixed). Each non-final instance
/// variable is flagged at its own name; `final`/`late final` fields,
/// static fields, and every other class are clean.
class WidgetImmutableGuard extends RecursiveAstVisitor<void> {
  WidgetImmutableGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<WidgetImmutableViolation> violations = [];
  String? _scope;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final wasScope = _scope;
    final superclass = node.extendsClause?.superclass.name2.lexeme;
    if (superclass != null &&
        _statelessSuperclasses.contains(superclass)) {
      _scope = superclass;
    }
    super.visitClassDeclaration(node);
    _scope = wasScope;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final scope = _scope;
    if (scope != null && !node.isStatic) {
      for (final variable in node.fields.variables) {
        if (!variable.isFinal) {
          violations.add(WidgetImmutableViolation(
            line: _lineInfo.getLocation(variable.name.offset).lineNumber,
            message: "non-final field '${variable.name.lexeme}' "
                'in $scope; widgets must be immutable',
          ));
        }
      }
    }
    super.visitFieldDeclaration(node);
  }
}
