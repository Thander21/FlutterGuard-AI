// Shared I/O-boundary helpers (SYS-CAL-001 heal pointers).
//
// Three advisory DRY pairs converged here: target walking
// (`checkPath` ~= `runTier1Lite`), breaker subprocesses
// (`MutationRunner._runTest` ~= `CoverageRunner._runCapture`), and
// PATH search (`resolvesOnPath` ~= `isFlutterSdkAvailable`). Each
// helper preserves the exact semantics (and error strings) of the
// code it replaced, so call-site tests pin the behavior. Imports
// `dart:` only — never package code (no import cycles, ever).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Suffixes marking machine-generated Dart files (SYS-CAL-002 P0-3).
const generatedFileSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.mocks.dart',
];

/// Directory segments whose subtrees are machine-generated output.
const generatedDirSegments = {'generated', 'gen', 'flutter_gen'};

/// True when [normalizedPath] (forward slashes) is machine-generated
/// output: a generated suffix, a Flutter l10n catalog
/// (`app_localizations*.dart`), or a file under a generated-output
/// directory. Findings on generated code are unactionable (the next
/// build overwrites any fix), so collection skips them by default.
bool isGeneratedDartFile(String normalizedPath) {
  final segments = normalizedPath.split('/');
  final file = segments.last;
  if (file.startsWith('app_localizations') && file.endsWith('.dart')) {
    return true;
  }
  for (final suffix in generatedFileSuffixes) {
    if (file.endsWith(suffix)) return true;
  }
  for (final segment in segments.take(segments.length - 1)) {
    if (generatedDirSegments.contains(segment)) return true;
  }
  return false;
}

/// Collects `.dart` files under [target] (one file or a directory
/// scanned recursively, sorted, forward-slash normalized).
///
/// Shared `check`/`lite` semantics: a missing target throws
/// [ArgumentError]; a non-`.dart` file target (or `.dart`-less
/// directory) yields an empty list. Generated files (see
/// [isGeneratedDartFile]) are skipped unless [includeGenerated] is
/// true — including an explicitly targeted single generated file.
List<String> collectDartFiles(String target, {bool includeGenerated = false}) {
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.notFound) {
    throw ArgumentError('No such file or directory: $target');
  }
  if (type == FileSystemEntityType.directory) {
    return _walkDir(target, includeGenerated: includeGenerated);
  }
  if (target.endsWith('.dart')) {
    final file = _normalize(target);
    if (!includeGenerated && isGeneratedDartFile(file)) return const [];
    return [file];
  }
  return const [];
}

/// Sorted `.dart` files under directory [target].
List<String> _walkDir(String target, {required bool includeGenerated}) {
  final files =
      Directory(target)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => _normalize(file.path))
          .where((file) => includeGenerated || !isGeneratedDartFile(file))
          .toList()
        ..sort();
  return files;
}

/// Forward slashes on every platform, so findings sort and compare
/// the same on Windows, macOS, and Linux.
String _normalize(String path) => path.replaceAll(r'\', '/');

/// Exit code reported when the circuit breaker kills a run.
/// Shared convention: callers treat non-zero as failure, this as
/// timeout.
const breakerTimeoutExit = -1;

/// Outcome of [runWithBreaker].
class BreakerResult {
  const BreakerResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });

  /// Process exit code, or [breakerTimeoutExit] on a trip.
  final int exitCode;
  final String stdout;
  final String stderr;

  /// True when the breaker killed the process.
  final bool timedOut;
}

/// Runs [executable] with [args], SIGKILLing the process after
/// [timeout]. Exact historical shape (Timer + trip flag + SIGKILL +
/// joined drains) shared by the mutation and coverage runners.
Future<BreakerResult> runWithBreaker(
  String executable,
  List<String> args,
  Duration timeout,
) async {
  final process = await Process.start(executable, args);
  final stdoutDone = process.stdout.transform(utf8.decoder).join();
  final stderrDone = process.stderr.transform(utf8.decoder).join();
  var timedOut = false;
  final breaker = Timer(timeout, () {
    timedOut = true;
    process.kill(ProcessSignal.sigkill);
  });
  final exit = await process.exitCode;
  breaker.cancel();
  final stdout = await stdoutDone;
  final stderr = await stderrDone;
  return BreakerResult(
    exitCode: timedOut ? breakerTimeoutExit : exit,
    stdout: stdout,
    stderr: stderr,
    timedOut: timedOut,
  );
}

/// True when [name] resolves on PATH. [pathEnv] injects a fake PATH
/// for tests; the ambient machine is never asserted on. [extensions]
/// lists the probed suffixes (callers keep their historical sets:
/// the SDK probe includes `.sh`, the generic probe `.cmd`).
bool resolvesOnPath(
  String name, {
  String? pathEnv,
  List<String> extensions = const [],
}) {
  final path = pathEnv ?? Platform.environment['PATH'] ?? '';
  if (path.isEmpty) return false;
  final separator = Platform.isWindows ? ';' : ':';
  final suffixes = extensions.isEmpty
      ? (Platform.isWindows ? ['', '.exe', '.bat', '.cmd'] : [''])
      : extensions;
  for (final entry in path.split(separator)) {
    final dir = entry.trim();
    if (dir.isEmpty) continue;
    for (final extension in suffixes) {
      if (File('$dir/$name$extension').existsSync()) return true;
    }
  }
  return false;
}

/// Joins [root] with a repo-relative [path], leaving CLI behavior and
/// output byte-identical when [root] is the default '.'.
String joinRoot(String root, String path) => root == '.' ? path : '$root/$path';
