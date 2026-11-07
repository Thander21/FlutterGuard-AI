// Golden passing vector for FG-LINT-009.
// Errors are handled or rethrown; suppressions carry rationale.
// The AST gate MUST NOT flag this file.
// ignore_for_file: avoid_print // tasting builds print on purpose
import 'package:flutter/widgets.dart';

// ignore: unused_import // platform shim re-exported on web only
import 'package:unused/pkg.dart';

void load() {
  try {
    fetch();
  } catch (error) {
    debugPrint('$error');
    rethrow;
  }
}

/// Never write bare ignore: suppressions; justify or fix at the root cause.
void audit() {
  print('audit');
}

// Fetch retries are intentional: the server coalesces bursts (R2-3).
// ignore: cancel_subscriptions
void retry() {
  fetch();
}

// Same-line rationale shapes (flutterguardai4, RF5).
// ignore: unnecessary_lambdas, justificativa: the closure must stay stable.
void share() {}

// ignore: prefer_const_constructors - the widget needs fresh state.
void rebuild() {}

// ignore: avoid_print // Justificativa: CLI output is the operator channel.
void report() {}
