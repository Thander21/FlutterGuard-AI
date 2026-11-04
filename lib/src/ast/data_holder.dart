// Shared data-holder doctrine (TS-13 §1 v2, SYS-DRY-001 §2).
//
// One definition serves both detectors: MET-007 exempts data-holder
// constructors from the params budget, and the DRY collector skips
// data-holder classes as comparable units. Parsing only (AST shape,
// no element model).

import 'package:analyzer/dart/ast/ast.dart';

/// True for a pure data-holder class: every field `final`/`const`,
/// with only `toString`/`==`/`hashCode` beyond fields and
/// constructors. A config object there adds indirection without
/// benefit, and its shape similarity is structural coincidence.
bool isDataHolderClass(ClassDeclaration node) {
  for (final member in node.members) {
    if (member is ConstructorDeclaration) continue;
    if (member is FieldDeclaration) {
      if (!member.fields.isFinal && !member.fields.isConst) return false;
    } else if (member is MethodDeclaration) {
      if (!_isValueIdentity(member)) return false;
    } else {
      return false;
    }
  }
  return true;
}

/// True for value-identity members: `toString`, `==`, `hashCode`.
bool _isValueIdentity(MethodDeclaration member) {
  final name = member.name.lexeme;
  if (member.isOperator) return name == '==';
  if (member.isGetter || member.isSetter) {
    return member.isGetter && name == 'hashCode';
  }
  return name == 'toString';
}
