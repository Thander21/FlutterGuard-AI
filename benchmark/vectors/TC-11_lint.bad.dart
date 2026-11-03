// Golden failing vector for FG-LINT-009.
// Suppression comments and an empty catch block.
// The AST gate MUST flag this file.
import 'package:flutter/widgets.dart';

// ignore: unused_import
import 'package:unused/pkg.dart';

void load() {
  try {
    fetch();
  } catch (_) {}
}

// ignore_for_file: avoid_print
void log(String message) {
  print(message);
}
