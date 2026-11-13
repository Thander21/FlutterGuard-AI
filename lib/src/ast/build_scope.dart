// Shared measured-build doctrine (TS-14 §3, TS-34 §3).
//
// One definition serves every frame-scope guard: FG-BUILD-014 and
// FG-SYNC-034 measure the same `build()`/Widget-function shapes.
// Extracted on the TS-34 landing (the verbatim twin rated TP under
// SYS-DRY-001). Parsing only (AST shape, no element model).

import 'package:analyzer/dart/ast/ast.dart';

/// Riverpod notifier superclasses whose `build` is provider
/// initialization, not widget build scope (TS-14 §3; SYS-CAL-002 P1-3).
const buildScopeNotifierSuperclasses = <String>{
  'Notifier',
  'AsyncNotifier',
  'FamilyNotifier',
  'FamilyAsyncNotifier',
  'AutoDisposeNotifier',
  'AutoDisposeAsyncNotifier',
  'AutoDisposeFamilyNotifier',
  'AutoDisposeFamilyAsyncNotifier',
};

/// True for `Widget`-typed or untyped `build()` methods and
/// `Widget`-returning functions, except a `build` owned by a
/// Riverpod notifier. A `build` with a declared non-`Widget`
/// return type is a builder of another kind (SYS-CAL-003 R2-3).
bool isMeasuredBuildScope(AstNode scope, ClassDeclaration? owner) {
  if (scope is MethodDeclaration) {
    if (_isNotifierBuild(scope, owner)) return false;
    if (scope.name.lexeme != 'build') {
      return isWidgetType(scope.returnType);
    }
    final returnType = scope.returnType;
    return returnType == null || isWidgetType(returnType);
  }
  if (scope is FunctionDeclaration) {
    return isWidgetType(scope.returnType);
  }
  return false;
}

/// True when [scope] is a `build` method owned by a class directly
/// extending a Riverpod notifier. Indirect subclasses (custom
/// intermediate bases) stay measured: unresolvable parse-only.
bool _isNotifierBuild(MethodDeclaration scope, ClassDeclaration? owner) {
  if (scope.name.lexeme != 'build' || owner == null) return false;
  final superclass = owner.extendsClause?.superclass;
  return superclass is NamedType &&
      buildScopeNotifierSuperclasses.contains(superclass.name.lexeme);
}

/// True for a `Widget` return type (exact simple name).
bool isWidgetType(TypeAnnotation? type) =>
    type is NamedType && type.name.lexeme == 'Widget';
