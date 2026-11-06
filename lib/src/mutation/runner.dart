// SYS-MUT-001: mutation runner — sandbox copies, `dart test`
// invocation with a circuit breaker, and the green-on-mutant
// comparator. The only async unit in the package.
//
// Two staging strategies behind one entry point: bare fixture pairs
// (no enclosing pubspec) run as flat sibling copies; real packages
// run as shadow copies mutated in place, so every import style sees
// the mutant.
import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:yaml/yaml.dart';

import '../util.dart';
import 'mutant.dart';

/// Outcome of running the test suite against one mutant.
enum MutantStatus {
  /// Non-zero exit: the test caught the sabotage (honest).
  killed,

  /// Exit 0 on mutated code: the test asserts nothing (complacent).
  survived,

  /// The circuit breaker killed the run: unproven, never trusted.
  timeout,
}

/// One classified mutant run.
class MutantResult {
  const MutantResult({
    required this.mutant,
    required this.status,
    required this.exitCode,
  });

  final Mutant mutant;
  final MutantStatus status;

  /// Process exit code, or -1 when killed by the circuit breaker.
  final int exitCode;
}

/// Verdict over a source+test pair.
class MutationVerdict {
  const MutationVerdict({required this.passed, required this.results});

  /// True only when every mutant was killed (vacuous when none exist).
  final bool passed;
  final List<MutantResult> results;
}

/// Copies source+test pairs into a volatile sandbox, mutates, runs
/// the resolved test command per mutant, and classifies the outcome.
///
/// Staging is routed by package context: a source outside any package
/// (bare fixtures) stages as a flat sibling pair under
/// [sandboxRoot]/`<runId>`/ (kept after the run for inspection —
/// volatile, gitignored, never cleaned automatically); a source with
/// an enclosing `pubspec.yaml` stages as a shadow package copy under
/// the system temp dir (mutated in place, removed after verdicts —
/// kept only for inspection when staging itself fails).
class MutationRunner {
  MutationRunner({
    this.timeout = const Duration(seconds: 8),
    this.pubGetTimeout = const Duration(minutes: 2),
    this.sandboxRoot = 'fixtures/mutation',
    this.testCommand,
  });

  /// Circuit-breaker budget per test invocation (baseline included).
  final Duration timeout;

  /// Budget for the single `pub get` per shadow run (pair runs never
  /// fetch dependencies).
  final Duration pubGetTimeout;

  /// Volatile root for pair sandboxes (default inside the package so
  /// `package:` imports in the copies keep resolving). Shadow
  /// packages always stage under the system temp dir instead (see
  /// [shadowDirPrefix]), never inside the target package.
  final String sandboxRoot;

  /// Override for the test invocation, resolved per staged test.
  /// When null, [defaultTestCommand] is used. The returned list is
  /// the executable plus fixed args; the runner appends the staged
  /// test path and `--concurrency=1`.
  final List<String> Function({required bool usesFlutterTest})? testCommand;

  /// Default test invocation: `flutter test` when the staged test
  /// imports `package:flutter_test`, else `dart test` via the current
  /// executable (`.bat` launchers never spawned, breaker-safe).
  static List<String> defaultTestCommand({required bool usesFlutterTest}) {
    if (usesFlutterTest) return const ['flutter', 'test'];
    final executable = Platform.resolvedExecutable.isNotEmpty
        ? Platform.resolvedExecutable
        : 'dart';
    return [executable, 'test'];
  }

  /// Default dependency fetch inside a shadow package: `flutter pub
  /// get` for Flutter packages, else `dart pub get` via the current
  /// executable (same `.bat` rule as [defaultTestCommand]).
  static List<String> defaultPubGetCommand({required bool usesFlutter}) {
    if (usesFlutter) return const ['flutter', 'pub', 'get'];
    final executable = Platform.resolvedExecutable.isNotEmpty
        ? Platform.resolvedExecutable
        : 'dart';
    return [executable, 'pub', 'get'];
  }

  /// Canary snippet appended to the shadow source as mutant zero: a
  /// guaranteed compile error, so the test run MUST fail. A passing
  /// canary proves the mutant is not loaded and aborts the run.
  /// Tests key on the `MUTATION_CANARY` token.
  static const canarySnippet =
      '\n// MUTATION_CANARY\nthis is not valid dart !@#{{{\n';

  /// Basename prefix for shadow packages under the system temp dir
  /// (`<shadowDirPrefix><runId>`). Pinned: orphan discovery across
  /// runs depends on the spelling.
  static const shadowDirPrefix = 'fg_mut_shadow_';

  /// Judges [testPath] against mutants of [sourcePath].
  ///
  /// Throws [ArgumentError] on missing files, identical paths,
  /// non-positive timeouts, a test that does not import the source,
  /// a shadow pair split across packages, or a reused [runId].
  /// Throws [StateError] when the clean baseline is red, `pub get`
  /// fails in the shadow, the canary passes, or a restore mismatches.
  Future<MutationVerdict> run({
    required String sourcePath,
    required String testPath,
    String? runId,
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError('timeout must be positive: $timeout');
    }
    if (pubGetTimeout <= Duration.zero) {
      throw ArgumentError('pubGetTimeout must be positive: $pubGetTimeout');
    }
    final sourceFile = File(sourcePath);
    final testFile = File(testPath);
    if (!sourceFile.existsSync()) {
      throw ArgumentError('source not found: $sourcePath');
    }
    if (!testFile.existsSync()) {
      throw ArgumentError('test not found: $testPath');
    }
    final sourceAbs = _absoluteNormalized(sourceFile.path);
    final testAbs = _absoluteNormalized(testFile.path);
    if (sourceAbs == testAbs) {
      throw ArgumentError('source and test must be different files');
    }
    final source = sourceFile.readAsStringSync();
    final test = testFile.readAsStringSync();
    final id = runId ?? _slug();
    final packageRoot = _packageRootFor(sourceAbs);
    if (packageRoot == null) {
      return _runPair(
        sourcePath: sourcePath,
        testPath: testPath,
        source: source,
        test: test,
        sourceAbs: sourceAbs,
        testAbs: testAbs,
        runId: id,
      );
    }
    final packageUri = _packageUriForSource(sourceAbs, packageRoot);
    if (!_reachesSource(test, testAbs, sourceAbs, packageUri)) {
      throw ArgumentError(
        'test does not import the source: $testPath -> $sourcePath',
      );
    }
    if (!_isWithin(testAbs, packageRoot)) {
      throw ArgumentError(
        'test and source must live in the same package: '
        '$testPath -> $sourcePath',
      );
    }
    return _runShadow(
      packageRoot: packageRoot,
      source: source,
      test: test,
      sourceAbs: sourceAbs,
      testAbs: testAbs,
      sourcePath: sourcePath,
      runId: id,
    );
  }

  /// Bare-fixture strategy: flat sibling copies, the test copy's
  /// relative import rewritten to the source basename.
  Future<MutationVerdict> _runPair({
    required String sourcePath,
    required String testPath,
    required String source,
    required String test,
    required String sourceAbs,
    required String testAbs,
    required String runId,
  }) async {
    final siblingTest = _siblingImport(
      test,
      testAbs,
      sourceAbs,
      _basenameOf(sourceAbs),
      testPath,
      sourcePath,
    );
    final usesFlutter = usesFlutterTest(test);
    final runDir = Directory('$sandboxRoot/$runId');
    if (runDir.existsSync()) {
      throw ArgumentError('run id already exists: $runId');
    }
    final baselineTest = _stage(
      runDir,
      'baseline',
      _basenameOf(sourceAbs),
      source,
      _basenameOf(testAbs),
      siblingTest,
    );
    final baselineExit = await _runTest(
      baselineTest,
      usesFlutterTest: usesFlutter,
    );
    if (baselineExit != 0) {
      throw StateError(
        'test fails on unmutated code (exit $baselineExit) — refusing '
        'to judge mutants; see ${runDir.path}/baseline/',
      );
    }
    final results = <MutantResult>[];
    final mutants = findMutants(source, path: sourcePath);
    for (var i = 0; i < mutants.length; i++) {
      final mutant = mutants[i];
      final dir = 'mutant_${i.toString().padLeft(2, '0')}';
      final staged = _stage(
        runDir,
        dir,
        _basenameOf(sourceAbs),
        applyMutant(source, mutant),
        _basenameOf(testAbs),
        siblingTest,
      );
      final exit = await _runTest(staged, usesFlutterTest: usesFlutter);
      results.add(
        MutantResult(
          mutant: mutant,
          status: _statusForExit(exit),
          exitCode: exit,
        ),
      );
    }
    return MutationVerdict(
      passed: results.every((r) => r.status == MutantStatus.killed),
      results: results,
    );
  }

  /// Real-package strategy: copy the working tree to a shadow, fetch
  /// dependencies once, then mutate the source in place — every
  /// import style resolves to the mutant, and the originals are never
  /// touched. The shadow is removed after verdicts; staging failures
  /// keep it for inspection (bounded by [sweepStaleShadows]).
  Future<MutationVerdict> _runShadow({
    required String packageRoot,
    required String source,
    required String test,
    required String sourceAbs,
    required String testAbs,
    required String sourcePath,
    required String runId,
  }) async {
    sweepStaleShadows();
    final shadow = Directory(
      '${Directory.systemTemp.path}/$shadowDirPrefix$runId',
    );
    if (shadow.existsSync()) {
      throw ArgumentError('run id already exists: $runId');
    }
    _copyPackage(Directory(packageRoot), shadow);
    final marker = File('${shadow.path}/$_shadowMarkerName')
      ..writeAsStringSync('$runId\n');
    var keep = false;
    try {
      final usesFlutter = usesFlutterTest(test) || _usesFlutterSdk(packageRoot);
      final pubGet = defaultPubGetCommand(usesFlutter: usesFlutter);
      final fetched = await runWithBreaker(
        pubGet.first,
        pubGet.sublist(1),
        pubGetTimeout,
        workingDirectory: shadow.path,
      );
      if (fetched.timedOut || fetched.exitCode != 0) {
        throw StateError(
          'pub get failed in shadow ${shadow.path} '
          '(exit ${fetched.exitCode}); see ${shadow.path}/',
        );
      }
      final relSource = _relativeTo(packageRoot, sourceAbs);
      final relTest = _relativeTo(packageRoot, testAbs);
      final shadowSource = File('${shadow.path}/$relSource');
      final baselineExit = await _runTest(
        relTest,
        usesFlutterTest: usesFlutter,
        workingDirectory: shadow.path,
      );
      if (baselineExit != 0) {
        throw StateError(
          'test fails on unmutated code (exit $baselineExit) — refusing '
          'to judge mutants; see ${shadow.path}/',
        );
      }
      _touch(marker);
      shadowSource.writeAsStringSync('$source$canarySnippet');
      final canaryExit = await _runTest(
        relTest,
        usesFlutterTest: usesFlutter,
        workingDirectory: shadow.path,
      );
      if (canaryExit == 0) {
        throw StateError(
          'canary passed: the staged test does not load the source — '
          'refusing to judge mutants; see ${shadow.path}/',
        );
      }
      _restoreChecked(shadowSource, source);
      final results = <MutantResult>[];
      final mutants = findMutants(source, path: sourcePath);
      for (var i = 0; i < mutants.length; i++) {
        final mutant = mutants[i];
        _touch(marker);
        shadowSource.writeAsStringSync(applyMutant(source, mutant));
        final exit = await _runTest(
          relTest,
          usesFlutterTest: usesFlutter,
          workingDirectory: shadow.path,
        );
        _restoreChecked(shadowSource, source);
        results.add(
          MutantResult(
            mutant: mutant,
            status: _statusForExit(exit),
            exitCode: exit,
          ),
        );
      }
      return MutationVerdict(
        passed: results.every((r) => r.status == MutantStatus.killed),
        results: results,
      );
    } on StateError {
      keep = true;
      rethrow;
    } finally {
      if (!keep) _deleteBestEffort(shadow);
    }
  }

  /// Copies one unmutated-or-mutated pair into [runDir]/[dir]; returns
  /// the staged test path.
  String _stage(
    Directory runDir,
    String dir,
    String sourceName,
    String sourceContent,
    String testName,
    String testContent,
  ) {
    final target = Directory('${runDir.path}/$dir')
      ..createSync(recursive: true);
    File('${target.path}/$sourceName').writeAsStringSync(sourceContent);
    final staged = File('${target.path}/$testName')
      ..writeAsStringSync(testContent);
    return staged.path;
  }

  /// Runs the resolved test command on [testPath]; [_timedOut]
  /// when the breaker fires. [workingDirectory] scopes the child to
  /// a staged copy (shadow runs pass the shadow root plus a
  /// package-relative test path).
  Future<int> _runTest(
    String testPath, {
    required bool usesFlutterTest,
    String? workingDirectory,
  }) async {
    final resolve = testCommand ?? defaultTestCommand;
    final command = resolve(usesFlutterTest: usesFlutterTest);
    if (command.isEmpty) {
      throw StateError('test command resolved empty');
    }
    final result = await runWithBreaker(
      command.first,
      [...command.sublist(1), testPath, '--concurrency=1'],
      timeout,
      workingDirectory: workingDirectory,
    );
    return result.exitCode;
  }
}

/// True when [testSource] imports `package:flutter_test` (AST-sited,
/// so strings and comments never match). Decides the test command
/// per staged suite (SYS-CAL-002 P2-2).
bool usesFlutterTest(String testSource) {
  final unit = parseString(content: testSource, throwIfDiagnostics: false).unit;
  final collector = _ImportCollector();
  unit.accept(collector);
  return collector.imports.any(
    (uri) => uri.stringValue?.startsWith('package:flutter_test/') ?? false,
  );
}

/// Deletes abandoned shadow packages under the system temp dir:
/// `<shadowDirPrefix><runId>` entries whose marker is at least
/// [olderThan] old (crashed or kept-on-error runs — live runs
/// heartbeat the marker per mutant), plus marker-less entries at
/// least [olderThan] old (copies that died mid-flight). Returns the
/// removed count. Never throws: every entry is best-effort.
int sweepStaleShadows({Duration olderThan = const Duration(hours: 24)}) {
  final now = DateTime.now();
  var swept = 0;
  late final List<FileSystemEntity> entries;
  try {
    entries = Directory.systemTemp.listSync();
  } catch (_) {
    return 0;
  }
  for (final entry in entries) {
    if (entry is! Directory) continue;
    if (!_basenameOf(_absoluteNormalized(entry.path))
        .startsWith(MutationRunner.shadowDirPrefix)) {
      continue;
    }
    try {
      final marker = File('${entry.path}/$_shadowMarkerName');
      final stamp = marker.existsSync()
          ? marker.lastModifiedSync()
          : entry.statSync().modified;
      if (now.difference(stamp) >= olderThan) {
        entry.deleteSync(recursive: true);
        swept++;
      }
    } catch (_) {
      continue;
    }
  }
  return swept;
}

/// Rewrites the relative import(s) in [testSource] that resolve to
/// [sourceAbs] so the staged sibling copy keeps compiling: any layout
/// in, `'<sourceBase>'` out. Throws [ArgumentError] when no relative
/// import reaches the source.
String _siblingImport(
  String testSource,
  String testAbs,
  String sourceAbs,
  String sourceBase,
  String testPath,
  String sourcePath,
) {
  final unit = parseString(content: testSource, throwIfDiagnostics: false).unit;
  final collector = _ImportCollector();
  unit.accept(collector);
  final testDir = _dirOf(testAbs);
  final hits = <({int offset, int length})>[];
  for (final uri in collector.imports) {
    final raw = uri.stringValue;
    if (raw == null || raw.startsWith('dart:') || raw.startsWith('package:')) {
      continue;
    }
    final resolved = Uri.directory(testDir)
        .resolve(raw)
        .normalizePath()
        .toFilePath();
    if (_absoluteNormalized(resolved) == sourceAbs) {
      hits.add((offset: uri.offset, length: uri.length));
    }
  }
  if (hits.isEmpty) {
    throw ArgumentError(
      'test does not relatively import the source: $testPath -> $sourcePath',
    );
  }
  hits.sort((a, b) => b.offset.compareTo(a.offset));
  var staged = testSource;
  for (final hit in hits) {
    staged = staged.replaceRange(
      hit.offset,
      hit.offset + hit.length,
      "'$sourceBase'",
    );
  }
  return staged;
}

/// True when [testSource] reaches [sourceAbs], relatively or via the
/// [packageUri] (`package:<name>/<lib-relative>`, null when the
/// source has no package identity). Routing reachability for shadow
/// staging — nothing is rewritten there.
bool _reachesSource(
  String testSource,
  String testAbs,
  String sourceAbs,
  String? packageUri,
) {
  final unit = parseString(content: testSource, throwIfDiagnostics: false).unit;
  final collector = _ImportCollector();
  unit.accept(collector);
  final testDir = _dirOf(testAbs);
  for (final uri in collector.imports) {
    final raw = uri.stringValue;
    if (raw == null || raw.startsWith('dart:')) continue;
    if (raw.startsWith('package:')) {
      if (packageUri != null && raw == packageUri) return true;
      continue;
    }
    final resolved = Uri.directory(testDir)
        .resolve(raw)
        .normalizePath()
        .toFilePath();
    if (_absoluteNormalized(resolved) == sourceAbs) return true;
  }
  return false;
}

/// Nearest directory enclosing [sourceAbs] that carries a
/// `pubspec.yaml` (absolute, no trailing separator); null past the
/// filesystem root.
String? _packageRootFor(String sourceAbs) {
  var dir = Directory(_dirOf(sourceAbs));
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return _stripTrailingSep(_absoluteNormalized(dir.path));
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// `package:<name>/<lib-relative>` for [sourceAbs] under
/// [packageRoot] (from its `pubspec.yaml`); null when the pubspec is
/// unparseable or nameless, or the source sits outside `lib/`.
String? _packageUriForSource(String sourceAbs, String packageRoot) {
  String? name;
  try {
    final doc = loadYamlNode(
      File('$packageRoot/pubspec.yaml').readAsStringSync(),
    );
    if (doc is YamlMap) {
      final value = doc['name'];
      if (value is String && value.isNotEmpty) name = value;
    }
  } catch (_) {
    return null;
  }
  if (name == null) return null;
  final rootSegs = Uri.file(packageRoot).pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  final sourceSegs = Uri.file(sourceAbs).pathSegments;
  if (sourceSegs.length <= rootSegs.length + 1) return null;
  for (var i = 0; i < rootSegs.length; i++) {
    if (sourceSegs[i] != rootSegs[i]) return null;
  }
  if (sourceSegs[rootSegs.length] != 'lib') return null;
  final libRelative = sourceSegs.sublist(rootSegs.length + 1).join('/');
  return 'package:$name/$libRelative';
}

/// True when the pubspec at [packageRoot] depends on the Flutter SDK
/// (`flutter` or `flutter_test` in either dependency section).
bool _usesFlutterSdk(String packageRoot) {
  try {
    final doc = loadYamlNode(
      File('$packageRoot/pubspec.yaml').readAsStringSync(),
    );
    if (doc is! YamlMap) return false;
    for (final section in const ['dependencies', 'dev_dependencies']) {
      final deps = doc[section];
      if (deps is YamlMap &&
          (deps.containsKey('flutter') || deps.containsKey('flutter_test'))) {
        return true;
      }
    }
  } catch (_) {
    return false;
  }
  return false;
}

/// Copies the working tree at [from] into [to] (created):
/// directories named `build`, `.dart_tool`, or `.git` are pruned at
/// every level, symlinks are skipped, everything else is copied
/// byte-identical. The working tree (including uncommitted edits) is
/// what stages — never a VCS snapshot.
void _copyPackage(Directory from, Directory to) {
  const pruned = {'build', '.dart_tool', '.git'};
  to.createSync(recursive: true);
  final rootAbs = _absoluteNormalized(from.path);
  final entities = from.listSync(recursive: true, followLinks: false)
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final entity in entities) {
    final rel = _relativeTo(rootAbs, _absoluteNormalized(entity.path));
    if (rel.split(Platform.pathSeparator).any(pruned.contains)) continue;
    final dest = '${to.path}/$rel';
    if (entity is Directory) {
      Directory(dest).createSync(recursive: true);
    } else if (entity is File) {
      File(dest).parent.createSync(recursive: true);
      entity.copySync(dest);
    }
  }
}

/// Writes [original] back to [file] and fails closed when the
/// read-back differs — a staging that cannot restore cannot judge.
void _restoreChecked(File file, String original) {
  file.writeAsStringSync(original);
  if (file.readAsStringSync() != original) {
    throw StateError(
      'shadow restore mismatch for ${file.path}; refusing to judge '
      'further mutants',
    );
  }
}

/// Deletes [dir] when present; failures linger for the stale
/// sweep (a breaker-killed child may still hold file handles).
/// Cleanup must never fail a computed verdict.
void _deleteBestEffort(Directory dir) {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {
    // The stale sweep reaps whatever survives.
  }
}

/// Heartbeats [marker] so the stale sweep spares live runs. Never
/// throws: bookkeeping must not fail a run.
void _touch(File marker) {
  try {
    marker.setLastModifiedSync(DateTime.now());
  } catch (_) {
    // A vanished marker just ages the shadow for the sweep.
  }
}

/// Exit-code comparator (fail-closed): only a real non-zero kill
/// passes; green-on-mutant and breaker trips fail.
MutantStatus _statusForExit(int exit) => exit == breakerTimeoutExit
    ? MutantStatus.timeout
    : exit == 0
    ? MutantStatus.survived
    : MutantStatus.killed;

class _ImportCollector extends RecursiveAstVisitor<void> {
  final List<StringLiteral> imports = [];

  @override
  void visitImportDirective(ImportDirective node) {
    imports.add(node.uri);
    super.visitImportDirective(node);
  }
}

/// Incomplete-run marker inside a shadow package (see
/// [sweepStaleShadows]).
const _shadowMarkerName = '.fg-mutprobe-incomplete';

/// UTC-timestamp slug, sortable and unique per microsecond.
String _slug() =>
    DateTime.now().toUtc().toIso8601String().replaceAll(RegExp('[^0-9]'), '');

/// Absolute, separator- and `..`-normalized path for identity checks
/// (no `path` dependency allowed without amending the owning spec).
String _absoluteNormalized(String path) =>
    Uri.file(File(path).absolute.path).normalizePath().toFilePath();

String _basenameOf(String absolutePath) =>
    Uri.file(absolutePath).pathSegments.last;

String _dirOf(String absolutePath) {
  final file = Uri.file(absolutePath);
  return file
      .replace(
        pathSegments: [
          ...file.pathSegments.sublist(0, file.pathSegments.length - 1),
          '',
        ],
      )
      .toFilePath();
}

/// [path] without trailing separators (a bare drive root keeps one).
String _stripTrailingSep(String path) {
  var stripped = path;
  while (stripped.length > 1 &&
      (stripped.endsWith('/') || stripped.endsWith(r'\')) &&
      !RegExp(r'^[A-Za-z]:[\\/]?$').hasMatch(stripped)) {
    stripped = stripped.substring(0, stripped.length - 1);
  }
  return stripped;
}

/// True when [inner] is [outer] or lives under it (separator-aware,
/// so `/pkg2` never matches `/pkg`).
bool _isWithin(String inner, String outer) =>
    inner == outer || inner.startsWith('$outer${Platform.pathSeparator}');

/// [absolutePath] relative to [rootAbs] (both absolute-normalized,
/// [rootAbs] without trailing separator).
String _relativeTo(String rootAbs, String absolutePath) =>
    absolutePath.substring(rootAbs.length + 1);
