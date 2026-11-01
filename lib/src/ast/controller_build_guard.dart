// FG-ST-001: forbid controller instantiation inside build().
//
// A controller built in build() is reconstructed on every frame and never
// disposed. Controllers belong to state: create once in initState, release
// in dispose. Parsing only (no type resolution), so vectors need no
// dependencies.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Controller-like types that must live in state, never in build().
///
/// Closed v0 list: the classic Flutter controllers plus [FocusNode], which
/// shares the create-once/dispose-once lifecycle.
const buildControllerDenyList = <String>{
  'AnimationController',
  'FocusNode',
  'PageController',
  'ScrollController',
  'TabController',
  'TextEditingController',
};

/// A single FG-ST-001 violation.
class ControllerBuildViolation implements RuleViolation {
  const ControllerBuildViolation({required this.line, required this.message});

  /// 1-based line number of the offending instance creation.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-ST-001 violation found.
List<ControllerBuildViolation> analyzeControllerBuildFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ControllerBuildGuard(result.lineInfo);
  result.unit.accept(guard);
  return guard.violations;
}

/// Flags controller instance creations lexically inside build().
///
/// Scope (v0): any method literally named `build` (no Widget check, no type
/// resolution). A creation is either an explicit [InstanceCreationExpression]
/// (`new`/`const`) or, as in all modern code, a bare [MethodInvocation] of a
/// denylisted name (implicit `new`, which the parser leaves unresolved);
/// mere uses of a controller are not flagged.
class ControllerBuildGuard extends RecursiveAstVisitor<void> {
  ControllerBuildGuard(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ControllerBuildViolation> violations = [];
  bool _inBuild = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasInBuild = _inBuild;
    if (node.name.lexeme == 'build') {
      _inBuild = true;
    }
    super.visitMethodDeclaration(node);
    _inBuild = wasInBuild;
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_inBuild) {
      final type = _typeName(node);
      if (buildControllerDenyList.contains(type)) {
        _flag(node, type);
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Implicit `new`: without type resolution the parser leaves `Foo()` as
    // a target-less method invocation, so match denylisted names directly.
    if (_inBuild &&
        node.target == null &&
        buildControllerDenyList.contains(node.methodName.name)) {
      _flag(node, node.methodName.name);
    }
    super.visitMethodInvocation(node);
  }

  void _flag(AstNode node, String type) {
    final line = _lineInfo.getLocation(node.offset).lineNumber;
    violations.add(ControllerBuildViolation(
      line: line,
      message: '$type() created inside build(); '
          'create it in initState and dispose it',
    ));
  }
}

/// Simple type name of an instance creation (`TextEditingController` for
/// `TextEditingController(...)`, prefixes and type arguments stripped).
String _typeName(InstanceCreationExpression node) {
  // toSource-based extraction avoids version-sensitive NamedType APIs.
  final source = node.constructorName.type.toSource().split('<').first.trim();
  final dot = source.lastIndexOf('.');
  return dot == -1 ? source : source.substring(dot + 1);
}
