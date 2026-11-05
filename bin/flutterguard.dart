// FlutterGuard CLI entry point: thin dispatch over `lib/src/cli/`
// (SYS-REL-001 R3).
//
// Usage (from the repository root, after `dart pub get`):
//   dart run bin/flutterguard.dart grade
//   dart run bin/flutterguard.dart check <path> [--json] [--help]
//   dart run bin/flutterguard.dart heal <file.dart> --rule <RULE-ID>
//   dart run bin/flutterguard.dart init [--scaffold] [--agents] [--help]
//   dart run bin/flutterguard.dart sandbox <load|reset|check>
//
// `grade` scans specs/*.md, runs the registered rule visitor over each
// golden vector pair, and appends the gate results to evidence.jsonl. It
// exits 0 only when every vector passes its eval.
//
// `check` runs every registered visitor over a target .dart file or
// directory (recursive) and reports violations as text or JSON. It exits
// 1 when any violation is found, 0 when clean.
//
// `init` installs the pre-commit hook (runs `check`), writes
// flutterguard.yaml, and prints the agent mandate. `sandbox` manages the
// volatile agent playground under fixtures/sandbox/.
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';

/// Explicit [exit] (instead of returning the code from `main`) so the
/// process exit code propagates through `dart` batch-file launchers that
/// swallow a returned code.
void main(List<String> args) {
  exit(_run(args));
}

int _run(List<String> args) {
  if (args.length == 1 && args.first == 'grade') {
    return grade();
  }
  if (args.isNotEmpty && args.first == 'check') {
    return check(args.sublist(1));
  }
  if (args.isNotEmpty && args.first == 'heal') {
    return heal(args.sublist(1));
  }
  if (args.isNotEmpty && args.first == 'init') {
    return init(args.sublist(1));
  }
  if (args.isNotEmpty && args.first == 'sandbox') {
    return sandbox(args.sublist(1));
  }
  stderr.writeln('Usage: dart run bin/flutterguard.dart '
      '<grade|check|heal|init|sandbox>');
  stderr.writeln(
      '  grade                 Run golden evals, append evidence.jsonl.');
  stderr.writeln(
      '  check <path> [--json] [--help] Audit a .dart file or directory.');
  stderr.writeln('  heal <file.dart> --rule <RULE-ID> [--attempts N] [--json] '
      'Heal one file with a fast-path recipe.');
  stderr.writeln('  init [--scaffold] [--agents] [--help] Init a project.');
  stderr.writeln('  sandbox <load|reset|check> Manage the agent playground.');
  return 2;
}
