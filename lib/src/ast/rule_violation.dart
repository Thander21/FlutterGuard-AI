// Shared violation contract for all FlutterGuard AST rules.

/// A single rule violation: 1-based [line] plus a human-readable [message].
abstract class RuleViolation {
  int get line;
  String get message;
}
