// Changed-tests selection (SYS-CAL-003 R2-5 medium list).
//
// Maps the worktree diff onto the runnable tests a CI run must
// execute: changed `*_test.dart` files plus existing mirrors of
// changed lib files (shared `mirrorTestFor`, so selection agrees
// with the TestPresence rule on the layout). Non-runnable
// changes — helpers, docs, configs, deleted files — select
// nothing: an empty selection composes to a full `dart test`
// run under shell substitution, so silence fails closed in CI.
import 'dart:io';

import 'package:args/args.dart';

import '../util.dart';
import 'baseline.dart';

/// Test files selected by the diff of [target] against [base],
/// sorted, absolute-normalized. [target] locates the repo; the
/// selection is always repo-wide (fail-closed). Throws
/// [ArgumentError] naming the cause outside a git worktree, on an
/// unresolvable base, or on git failure (inherited from
/// [resolveChangedFiles]).
List<String> selectChangedTests(String target, {String base = 'origin/main'}) {
  final selected = <String>{};
  for (final file in resolveChangedFiles(target, base)) {
    if (!File(file).existsSync()) continue;
    final normalized = file.replaceAll(r'\', '/');
    if (normalized.split('/').last.endsWith('_test.dart')) {
      selected.add(file);
      continue;
    }
    final mirror = mirrorTestFor(file);
    if (mirror == null) continue;
    if (File(mirror).existsSync()) selected.add(mirror);
  }
  return selected.toList()..sort();
}

/// CLI usage for `select-tests` (SYS-CLI-001a).
const _selectUsage =
    'Usage: dart run bin/flutterguard.dart select-tests <path> [--diff-base=<ref>] [--help]';

/// Prints the selected test files (one per line). Returns 0 on
/// success (empty selection prints nothing), 2 on bad arguments
/// or git failure. [out] injects the sink (tests); without it
/// stdout is written.
int selectTests(List<String> args, {StringSink? out}) {
  final sink = out ?? stdout;
  final parser = ArgParser()
    ..addOption('diff-base', help: 'Diff base ref (default origin/main).')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  late final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_selectUsage);
    return 2;
  }
  if (parsed['help'] as bool) {
    sink.writeln(_selectUsage);
    sink.writeln(parser.usage);
    return 0;
  }
  final targets = parsed.rest;
  if (targets.length != 1) {
    stderr.writeln(_selectUsage);
    return 2;
  }
  try {
    for (final test in selectChangedTests(
      targets.single,
      base: (parsed['diff-base'] as String?) ?? 'origin/main',
    )) {
      sink.writeln(test);
    }
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    return 2;
  }
  return 0;
}
