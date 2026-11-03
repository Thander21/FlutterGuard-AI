// Golden passing vector for FG-LINT-009.
// Errors are handled or rethrown; nothing is suppressed.
// The AST gate MUST NOT flag this file.
import 'package:flutter/widgets.dart';

void load() {
  try {
    fetch();
  } catch (error) {
    debugPrint('$error');
    rethrow;
  }
}

/// Never write ignore: suppressions; fix findings at the root cause.
void audit() {}
