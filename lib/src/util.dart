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
  return collectScannableFiles(
    target,
    extensions: const {'.dart'},
    includeGenerated: includeGenerated,
  );
}

/// Collects files under [target] whose extension is in [extensions],
/// whose basename starts with a [namePrefixes] entry, or whose
/// basename is in [names] (one file or a directory scanned
/// recursively, sorted, forward-slash normalized).
///
/// Same semantics as [collectDartFiles] generalized: a missing
/// target throws [ArgumentError]; a non-matching file target (or a
/// directory with no matching file) yields an empty list; generated
/// files are skipped unless [includeGenerated] is true. `check`
/// passes the registered rules' extension/prefix/name unions, so
/// non-Dart rules (`.arb`, `.env*`, `pubspec.yaml`) join the walk
/// without touching this loop.
List<String> collectScannableFiles(
  String target, {
  required Set<String> extensions,
  Set<String> namePrefixes = const {},
  Set<String> names = const {},
  bool includeGenerated = false,
}) {
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.notFound) {
    throw ArgumentError('No such file or directory: $target');
  }
  if (type == FileSystemEntityType.directory) {
    return _walkDir(
      target,
      extensions: extensions,
      namePrefixes: namePrefixes,
      names: names,
      includeGenerated: includeGenerated,
    );
  }
  if (_matchesScope(target, extensions, namePrefixes, names)) {
    final file = _normalize(target);
    if (!includeGenerated && isGeneratedDartFile(file)) return const [];
    return [file];
  }
  return const [];
}

/// Sorted files under directory [target] matching the scope.
List<String> _walkDir(
  String target, {
  required Set<String> extensions,
  required Set<String> namePrefixes,
  required Set<String> names,
  required bool includeGenerated,
}) {
  final files =
      Directory(target)
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => _matchesScope(file.path, extensions, namePrefixes, names),
          )
          .map((file) => _normalize(file.path))
          .where((file) => includeGenerated || !isGeneratedDartFile(file))
          .toList()
        ..sort();
  return files;
}

/// True when [path] matches [extensions] (suffix), [namePrefixes]
/// (basename prefix — dotfiles carry no matchable extension), or
/// [names] (exact basename — singletons like `pubspec.yaml`).
bool _matchesScope(
  String path,
  Set<String> extensions,
  Set<String> namePrefixes,
  Set<String> names,
) {
  if (extensions.any(path.endsWith)) return true;
  if (namePrefixes.isEmpty && names.isEmpty) return false;
  final base = path.replaceAll(r'\', '/').split('/').last;
  if (names.contains(base)) return true;
  return namePrefixes.any(base.startsWith);
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
/// [workingDirectory] (null = inherit) scopes the child to a staged
/// copy, e.g. the mutation shadow package.
Future<BreakerResult> runWithBreaker(
  String executable,
  List<String> args,
  Duration timeout, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: workingDirectory,
  );
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

/// First [name] hit on PATH (full path) or null. [pathEnv] injects
/// a fake PATH for tests; the ambient machine is never asserted on.
/// [extensions] lists the probed suffixes (callers keep their
/// historical sets: the SDK probe includes `.sh`, the generic probe
/// `.cmd`).
String? findOnPath(
  String name, {
  String? pathEnv,
  List<String> extensions = const [],
}) {
  final path = pathEnv ?? Platform.environment['PATH'] ?? '';
  if (path.isEmpty) return null;
  final separator = Platform.isWindows ? ';' : ':';
  final suffixes = extensions.isEmpty
      ? (Platform.isWindows ? ['', '.exe', '.bat', '.cmd'] : [''])
      : extensions;
  for (final entry in path.split(separator)) {
    final dir = entry.trim();
    if (dir.isEmpty) continue;
    for (final extension in suffixes) {
      final candidate = '$dir/$name$extension';
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return null;
}

/// True when [name] resolves on PATH (see [findOnPath]).
bool resolvesOnPath(
  String name, {
  String? pathEnv,
  List<String> extensions = const [],
}) => findOnPath(name, pathEnv: pathEnv, extensions: extensions) != null;

/// Joins [root] with a repo-relative [path], leaving CLI behavior and
/// output byte-identical when [root] is the default '.'.
String joinRoot(String root, String path) => root == '.' ? path : '$root/$path';

/// Mirror test for the lib file [path]: the last `/lib/` segment
/// becomes `/test/` and the trailing `.dart` becomes `_test.dart`
/// (`lib/foo/bar.dart` → `test/foo/bar_test.dart`, monorepo-safe).
/// Returns null when [path] is not a `.dart` file under a `lib/`
/// directory, or when it already is a test (`*_test.dart` maps
/// nowhere — callers include tests directly). Forward slashes in
/// and out. Shared bottom for the TestPresence rule and
/// changed-tests selection, so both agree on the layout.
String? mirrorTestFor(String path) {
  final normalized = path.replaceAll(r'\', '/');
  if (!normalized.endsWith('.dart')) return null;
  final base = normalized.split('/').last;
  if (base.endsWith('_test.dart')) return null;
  final idx = normalized.lastIndexOf('/lib/');
  if (idx >= 0) {
    final stem = normalized.substring(0, idx);
    final rest = normalized.substring(idx + '/lib/'.length);
    return '$stem/test/${_testStem(rest)}';
  }
  if (normalized.startsWith('lib/')) {
    return 'test/${_testStem(normalized.substring('lib/'.length))}';
  }
  return null;
}

/// `foo/bar.dart` → `foo/bar_test.dart` (input ends with `.dart`).
String _testStem(String rest) =>
    '${rest.substring(0, rest.length - '.dart'.length)}_test.dart';

/// Config file name discovered by walking up from the target.
const configFileName = 'flutterguard.yaml';

/// Nearest config walking up from [target] (a file or directory),
/// or null when none exists up to the filesystem root. Shared
/// bottom: rule toggles (`cli/config.dart`) and self-loading rules
/// (FG-BAN-018) discover through here, so every consumer agrees on
/// which config governs a target.
String? findConfig(String target) {
  var dir = _startDir(target);
  while (true) {
    final candidate = '$dir/$configFileName';
    if (File(candidate).existsSync()) return candidate;
    if (dir == '/' || RegExp(r'^[A-Za-z]:/?$').hasMatch(dir)) return null;
    final idx = dir.lastIndexOf('/');
    if (idx < 0) return null;
    dir = idx == 0 ? '/' : dir.substring(0, idx);
  }
}

/// Absolute, forward-slash directory to start discovery from: [target]
/// itself for directories, its parent for files.
String _startDir(String target) {
  final abs = File(target).absolute.path.replaceAll(r'\', '/');
  if (FileSystemEntity.isDirectorySync(target)) return abs;
  final idx = abs.lastIndexOf('/');
  return idx < 0 ? abs : abs.substring(0, idx);
}

/// True when forward-slash [path] matches glob [pattern] (v1):
/// `*` spans within one segment, `?` matches one character, and a
/// full `**` segment crosses segments. Serves `except` lists; both
/// sides use forward slashes.
bool globMatches(String pattern, String path) {
  return _matchSegments(pattern.split('/'), 0, path.split('/'), 0);
}

/// Segment-wise glob match with `**` backtracking.
bool _matchSegments(List<String> p, int pi, List<String> f, int fi) {
  while (true) {
    if (pi == p.length) return fi == f.length;
    if (p[pi] == '**') {
      for (var skip = fi; skip <= f.length; skip++) {
        if (_matchSegments(p, pi + 1, f, skip)) return true;
      }
      return false;
    }
    if (fi == f.length) return false;
    if (!_matchSegment(p[pi], f[fi])) return false;
    pi++;
    fi++;
  }
}

/// One-segment `*`/`?` match (linear backtracking; an embedded
/// `**` degrades to single stars).
bool _matchSegment(String pattern, String name) {
  var px = 0;
  var nx = 0;
  var star = -1;
  var mark = 0;
  while (nx < name.length) {
    if (px < pattern.length &&
        (pattern[px] == '?' || pattern[px] == name[nx])) {
      px++;
      nx++;
    } else if (px < pattern.length && pattern[px] == '*') {
      star = px++;
      mark = nx;
    } else if (star != -1) {
      px = star + 1;
      nx = ++mark;
    } else {
      return false;
    }
  }
  while (px < pattern.length && pattern[px] == '*') {
    px++;
  }
  return px == pattern.length;
}
