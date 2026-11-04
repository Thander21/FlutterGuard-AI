// SYS-MUT-001: mutation runner — sandbox copies, `dart test`
// invocation with a circuit breaker, and the green-on-mutant
// comparator. The only async unit in the package.
import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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
/// `dart test --concurrency=1` per mutant, and classifies the outcome.
///
/// The originals are never touched: every run happens on copies under
/// [sandboxRoot]/`<runId>`/, which is kept after the run for
/// inspection (volatile, gitignored — never cleaned automatically).
class MutationRunner {
  MutationRunner({
    this.timeout = const Duration(seconds: 8),
    this.sandboxRoot = 'fixtures/mutation',
  });

  /// Circuit-breaker budget per test invocation (baseline included).
  final Duration timeout;

  /// Volatile root for sandbox copies (default inside the package so
  /// `package:` imports in the copies keep resolving).
  final String sandboxRoot;

  /// Judges [testPath] against mutants of [sourcePath].
  ///
  /// Throws [ArgumentError] on missing files, identical paths, a
  /// non-positive [timeout], or a test that does not relatively import
  /// the source. Throws [StateError] when the clean baseline is red.
  Future<MutationVerdict> run({
    required String sourcePath,
    required String testPath,
    String? runId,
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError('timeout must be positive: $timeout');
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
    final siblingTest = _siblingImport(test, testAbs, sourceAbs,
        _basenameOf(sourceAbs), testPath, sourcePath);

    final id = runId ?? _slug();
    final runDir = Directory('$sandboxRoot/$id');
    if (runDir.existsSync()) {
      throw ArgumentError('run id already exists: $id');
    }
    final baselineTest =
        _stage(runDir, 'baseline', _basenameOf(sourceAbs), source,
            _basenameOf(testAbs), siblingTest);

    final baselineExit = await _runTest(baselineTest);
    if (baselineExit != 0) {
      throw StateError(
          'test fails on unmutated code (exit $baselineExit) — refusing '
          'to judge mutants; see ${runDir.path}/baseline/');
    }

    final results = <MutantResult>[];
    final mutants = findMutants(source, path: sourcePath);
    for (var i = 0; i < mutants.length; i++) {
      final mutant = mutants[i];
      final dir = 'mutant_${i.toString().padLeft(2, '0')}';
      final staged =
          _stage(runDir, dir, _basenameOf(sourceAbs), applyMutant(source, mutant),
              _basenameOf(testAbs), siblingTest);
      final exit = await _runTest(staged);
      results.add(MutantResult(
        mutant: mutant,
        status: exit == breakerTimeoutExit
            ? MutantStatus.timeout
            : exit == 0
                ? MutantStatus.survived
                : MutantStatus.killed,
        exitCode: exit,
      ));
    }
    return MutationVerdict(
      passed: results.every((r) => r.status == MutantStatus.killed),
      results: results,
    );
  }

  /// Copies one unmutated-or-mutated pair into [runDir]/[dir]; returns
  /// the staged test path.
  String _stage(Directory runDir, String dir, String sourceName,
      String sourceContent, String testName, String testContent) {
    final target = Directory('${runDir.path}/$dir')..createSync(recursive: true);
    File('${target.path}/$sourceName').writeAsStringSync(sourceContent);
    final staged = File('${target.path}/$testName')
      ..writeAsStringSync(testContent);
    return staged.path;
  }

  /// Runs `dart test` on [testPath]; [_timedOut] when the breaker fires.
  Future<int> _runTest(String testPath) async {
    final executable = Platform.resolvedExecutable.isNotEmpty
        ? Platform.resolvedExecutable
        : 'dart';
    final result = await runWithBreaker(
        executable, ['test', testPath, '--concurrency=1'], timeout);
    return result.exitCode;
  }
}

/// Rewrites the relative import(s) in [testSource] that resolve to
/// [sourceAbs] so the staged sibling copy keeps compiling: any layout
/// in, `'<sourceBase>'` out. Throws [ArgumentError] when no relative
/// import reaches the source.
String _siblingImport(String testSource, String testAbs, String sourceAbs,
    String sourceBase, String testPath, String sourcePath) {
  final unit =
      parseString(content: testSource, throwIfDiagnostics: false).unit;
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
        'test does not relatively import the source: $testPath -> $sourcePath');
  }
  hits.sort((a, b) => b.offset.compareTo(a.offset));
  var staged = testSource;
  for (final hit in hits) {
    staged = staged.replaceRange(
        hit.offset, hit.offset + hit.length, "'$sourceBase'");
  }
  return staged;
}

class _ImportCollector extends RecursiveAstVisitor<void> {
  final List<StringLiteral> imports = [];

  @override
  void visitImportDirective(ImportDirective node) {
    imports.add(node.uri);
    super.visitImportDirective(node);
  }
}

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
  return file.replace(pathSegments: [
    ...file.pathSegments.sublist(0, file.pathSegments.length - 1),
    ''
  ]).toFilePath();
}
