// Shared data-holder doctrine (TS-13 §1 v3, SYS-DRY-001 §2).
//
// One definition serves both detectors: MET-007 exempts data-holder
// constructors from the params budget, and the DRY collector skips
// data-holder classes as comparable units. Parsing only (AST shape,
// no element model).

import 'package:analyzer/dart/ast/ast.dart';

/// Serialization and copy companions a data holder may carry (TS-13
/// v3, SYS-CAL-003 R2-4): real-world models serialize and copy
/// themselves, and a config object there adds indirection without
/// benefit. Closed set — anything else stays behavioral.
const _companionMethods = <String>{
  'toJson',
  'fromJson',
  'toMap',
  'fromMap',
  'copyWith',
};

/// Equatable getters a data holder may carry (same rationale).
const _equatableGetters = <String>{'props', 'stringify'};

/// True for a data-holder class: every field `final`/`const`, with
/// only value-identity, serialization, `copyWith`, and Equatable
/// companions beyond fields and constructors. Factory constructors
/// (including `fromJson` factories) are constructors, so they never
/// break holder status. Anything else — behavior methods, derived
/// getters beyond `props`/`stringify`, setters, non-final fields —
/// breaks it, fail-closed.
bool isDataHolderClass(ClassDeclaration node) {
  for (final member in node.body.members) {
    if (member is ConstructorDeclaration) continue;
    if (member is FieldDeclaration) {
      if (!member.fields.isFinal && !member.fields.isConst) return false;
    } else if (member is MethodDeclaration) {
      if (!_isCompanion(member)) return false;
    } else {
      return false;
    }
  }
  return true;
}

/// True for the getters a data holder may carry: value-identity
/// `hashCode` and the Equatable `props`/`stringify` pair. Shared
/// with the MET-007 v4 const-named exemption (TS-13 §1), which
/// keeps flagging every other getter.
bool isHolderGetter(String name) =>
    name == 'hashCode' || _equatableGetters.contains(name);

/// True for holder companions: value-identity (`toString`, `==`,
/// `hashCode`), serialization (`toJson`/`fromJson`/`toMap`/
/// `fromMap`), `copyWith`, and the Equatable `props`/`stringify`
/// getters.
bool _isCompanion(MethodDeclaration member) {
  final name = member.name.lexeme;
  if (member.isOperator) return name == '==';
  if (member.isGetter || member.isSetter) {
    if (!member.isGetter) return false;
    return isHolderGetter(name);
  }
  return name == 'toString' || _companionMethods.contains(name);
}
