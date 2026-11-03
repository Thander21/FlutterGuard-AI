// SYS-COV-001: coverage pipeline (`dart test --coverage` ->
// `format_coverage` -> lcov) with per-method CRAP scoring.
//
// The only async unit besides the mutation runner. Temp artifacts are
// fully parsed into the verdict and deleted; no repo residue.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'complexity.dart';
import 'lcov.dart';

/// CRAP score at or above which a method is flagged (advisory in v1).
const crapThreshold = 10.0;

/// CRAP score of one scored method.
class MethodScore {
  const MethodScore({
    required this.name,
    required this.file,
    required this.line,
    required this.complexity,
    required this.coverage,
  });

  final String name;
  final String file;
  final int line;
  final int complexity;

  /// Fraction of executable lines hit (0..1).
  final double coverage;

  /// `CC(m)^2 x (1 - cov(m))^3 + CC(m)`.
  double get crap =>
      (complexity * complexity * pow(1 - coverage, 3) + complexity)
          .toDouble();

  /// True at `CRAP >= 10` (advisory: reported, never fails).
  bool get overBudget => crap >= crapThreshold;
}

/// Outcome of [CoverageRunner.run]: advisory scores per method.
class CoverageVerdict {
  const CoverageVerdict({
    required this.passed,
    required this.methods,
    required this.filesScored,
  });

  /// Advisory v1: always true; the blocking flip is owned by
  /// SYS-CAL-001.
  final bool passed;

  /// Scored methods, sorted by file, then line.
  final List<MethodScore> methods;
  final int filesScored;
}

/// Runs the two-hop coverage pipeline and scores CRAP per method.
class CoverageRunner {
  CoverageRunner({this.timeout = const Duration(seconds: 8)});

  /// Circuit-breaker budget per subprocess hop.
  final Duration timeout;

  /// Scores [reportOn] (files or dirs) under [testPath] (single file).
  ///
  /// Throws [ArgumentError] on missing inputs; [StateError] on a red
  /// suite, a breaker timeout, or a `format_coverage` failure.
  Future<CoverageVerdict> run({
    required String testPath,
    required List<String> reportOn,
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError('timeout must be positive: $timeout');
    }
    if (!File(testPath).existsSync()) {
      throw ArgumentError('test not found: $testPath');
    }
    if (reportOn.isEmpty) {
      throw ArgumentError('reportOn must not be empty');
    }
    final files = <String>[];
    for (final entry in reportOn) {
      final type = FileSystemEntity.typeSync(entry);
      if (type == FileSystemEntityType.notFound) {
        throw ArgumentError('report-on not found: $entry');
      }
      if (type == FileSystemEntityType.directory) {
        for (final entity in Directory(entry).listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            files.add(_normalize(entity.path));
          }
        }
      } else if (entry.endsWith('.dart')) {
        files.add(_normalize(entry));
      }
    }
    files.sort();
    if (files.isEmpty) {
      return const CoverageVerdict(passed: true, methods: [], filesScored: 0);
    }

    final tmp = Directory.systemTemp.createTempSync('fg_cov_');
    try {
      final raw = Directory('${tmp.path}/raw')..createSync();
      final testExit = await _run([
        'test',
        testPath,
        '--coverage=${raw.path}',
        '--concurrency=1',
      ]);
      if (testExit == _timedOut) {
        throw StateError('coverage run timed out after $timeout');
      }
      if (testExit != 0) {
        throw StateError(
            'test suite failed (exit $testExit) — refusing to score coverage');
      }
      final lcovPath = '${tmp.path}/lcov.info';
      final formatted = await _runCapture([
        'run',
        'coverage:format_coverage',
        '-i',
        raw.path,
        '-o',
        lcovPath,
        '-l',
        '--package',
        '.',
        for (final file in files) ...['--report-on', file],
      ]);
      if (formatted.exit == _timedOut) {
        throw StateError('format_coverage timed out after $timeout');
      }
      if (formatted.exit != 0) {
        throw StateError(
            'format_coverage failed (exit ${formatted.exit}): ${_tail(formatted.stderr)}');
      }
      final lcov = parseLcov(File(lcovPath).readAsStringSync());
      final methods = <MethodScore>[];
      for (final file in files) {
        final source = File(file).readAsStringSync();
        final hits = _hitsFor(lcov, file);
        for (final m in analyzeComplexity(source, path: file)) {
          var total = 0;
          var covered = 0;
          hits.forEach((line, count) {
            if (line >= m.line && line <= m.endLine) {
              total++;
              if (count > 0) covered++;
            }
          });
          methods.add(MethodScore(
            name: m.name,
            file: file,
            line: m.line,
            complexity: m.complexity,
            coverage: total == 0 ? 0.0 : covered / total,
          ));
        }
      }
      methods.sort((a, b) {
        final byFile = a.file.compareTo(b.file);
        return byFile != 0 ? byFile : a.line.compareTo(b.line);
      });
      return CoverageVerdict(
          passed: true, methods: methods, filesScored: files.length);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  }

  /// Runs `dart` with [args]; [_timedOut] when the breaker fires.
  Future<int> _run(List<String> args) async {
    final result = await _runCapture(args);
    return result.exit;
  }

  Future<({int exit, String stderr})> _runCapture(List<String> args) async {
    final executable =
        Platform.resolvedExecutable.isNotEmpty ? Platform.resolvedExecutable : 'dart';
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
    await stdoutDone;
    final stderr = await stderrDone;
    return (exit: timedOut ? _timedOut : exit, stderr: stderr);
  }
}

/// Exit code reported when the circuit breaker kills a hop.
const _timedOut = -1;

/// Last 2000 chars of [text] for failure diagnostics.
String _tail(String text) =>
    text.length <= 2000 ? text : text.substring(text.length - 2000);

/// Hit map for [file] from the parsed lcov, or empty when the file has
/// no record (never imported = untested).
Map<int, int> _hitsFor(Map<String, LcovFile> lcov, String file) {
  final want = _absoluteNormalized(file);
  for (final record in lcov.values) {
    var sf = record.path;
    if (sf.startsWith('file:')) {
      sf = Uri.parse(sf).toFilePath();
    }
    if (_absoluteNormalized(sf) == want) return record.lineHits;
  }
  return const {};
}

/// Absolute, separator- and `..`-normalized path for identity checks
/// (no `path` dependency allowed without amending the owning spec).
String _absoluteNormalized(String path) =>
    Uri.file(File(path).absolute.path).normalizePath().toFilePath();

/// Forward slashes on every platform, so paths sort and compare the same
/// on Windows, macOS, and Linux.
String _normalize(String path) => path.replaceAll(r'\', '/');
