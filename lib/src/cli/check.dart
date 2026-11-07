// `check` core: run every registered visitor over a file or directory,
// plus the thin `check()` CLI wrapper (moved from `bin/` by SYS-REL-001
// R3).
//
// `checkPath` is pure library code (no stdout/stderr side effects) so the
// behavior is unit-testable; only the `check()` wrapper touches stdio.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';

import '../ast/format_guard.dart';
import '../rule_params.dart';
import '../util.dart';
import 'analyze.dart';
import 'baseline.dart';
import 'config.dart';
import 'deps.dart';
import 'ledger.dart';
import 'licenses.dart';
import 'rules.dart';

/// One violation found by `check`.
class CheckFinding {
  const CheckFinding({
    required this.ruleId,
    required this.spec,
    required this.file,
    required this.line,
    required this.message,
    this.severity = 'error',
  });

  final String ruleId;
  final String spec;
  final String file;
  final int line;
  final String message;

  /// Gate impact: `error` fails the gate, `warning` is advisory-only
  /// (reported but never fails; FG-MET-007 until SYS-CAL-001).
  final String severity;

  /// Pointer to the Before/After recipe (§2 of the spec contract).
  String get recipe => '$spec (§2)';

  Map<String, Object?> toJson() => {
    'rule_id': ruleId,
    'spec': spec,
    'recipe': recipe,
    'file': file,
    'line': line,
    'message': message,
    'severity': severity,
  };
}

/// One file `check` could not analyze (unreadable or unparseable).
class CheckError {
  const CheckError({required this.file, required this.error});

  final String file;
  final String error;

  Map<String, Object?> toJson() => {'file': file, 'error': error};
}

/// Findings in [findings] carrying [severity].
int _countSeverity(List<CheckFinding> findings, String severity) =>
    findings.where((finding) => finding.severity == severity).length;

/// Result of [checkPath]: findings plus per-file errors.
class CheckResult {
  const CheckResult({
    required this.findings,
    required this.errors,
    this.msByRule = const {},
  });

  final List<CheckFinding> findings;
  final List<CheckError> errors;

  /// Milliseconds spent per rule id (rules that scanned no file
  /// carry no entry). Measured always, reported with `--by-gate`.
  final Map<String, int> msByRule;

  Map<String, Object?> toJson() => {
    'findings': [for (final f in findings) f.toJson()],
    'errors': [for (final e in errors) e.toJson()],
    'summary': {
      'errors': _countSeverity(findings, 'error'),
      'warnings': _countSeverity(findings, 'warning'),
    },
  };
}

/// Rule id judged by subprocess batches instead of the per-file loop
/// (FG-FMT-016: bounded `dart format` spawns per run, not per file).
const batchRuleId = 'FG-FMT-016';

/// One per-gate verdict for `--by-gate` reporting.
class GateVerdict {
  const GateVerdict({
    required this.ruleId,
    required this.status,
    required this.errors,
    required this.warnings,
    required this.ms,
  });

  final String ruleId;

  /// `PASS`, `WARN` (warnings only), or `FAIL` (any error).
  final String status;
  final int errors;
  final int warnings;

  /// Milliseconds the rule spent scanning (0 when unscanned).
  final int ms;

  Map<String, Object?> toJson() => {
    'rule_id': ruleId,
    'status': status,
    'errors': errors,
    'warnings': warnings,
    'ms': ms,
  };
}

/// Text row for [verdict] (`gate FAIL FG-X (1 errors, 0 warnings, 2 ms)`).
String gateLine(GateVerdict verdict) =>
    'gate ${verdict.status} ${verdict.ruleId} '
    '(${verdict.errors} errors, ${verdict.warnings} warnings, '
    '${verdict.ms} ms)';

/// Per-gate verdicts over [rules] from reported [findings] and
/// [msByRule] timings (missing timings read 0). Registry order.
List<GateVerdict> gateReport({
  required List<RuleAnalyzer> rules,
  required List<CheckFinding> findings,
  required Map<String, int> msByRule,
}) {
  final verdicts = <GateVerdict>[];
  for (final rule in rules) {
    final scoped = [
      for (final finding in findings)
        if (finding.ruleId == rule.id) finding,
    ];
    final errors = _countSeverity(scoped, 'error');
    final warnings = _countSeverity(scoped, 'warning');
    verdicts.add(
      GateVerdict(
        ruleId: rule.id,
        status: errors > 0 ? 'FAIL' : (warnings > 0 ? 'WARN' : 'PASS'),
        errors: errors,
        warnings: warnings,
        ms: msByRule[rule.id] ?? 0,
      ),
    );
  }
  return verdicts;
}

/// Runs every registered visitor over [target] (one file or a
/// directory scanned recursively, sorted; the walk covers the
/// registered extension union — `.dart` plus every non-Dart scope
/// some rule declares).
///
/// One bad file never kills the run: per-file failures are collected once
/// per file in [CheckResult.errors]. Throws [ArgumentError] when [target]
/// is missing. Generated files are skipped unless [includeGenerated]
/// is true (see [collectScannableFiles]). Every rule sees only its
/// scoped extensions, so Dart visitors never parse catalog files.
/// Rules disabled by the nearest `flutterguard.yaml` are skipped
/// (see [enabledAnalyzers]).
/// Results sort by file, rule id, line, and message, then deduplicate
/// on (file, line, rule) (see [deduplicateFindings]).
CheckResult checkPath(String target, {bool includeGenerated = false}) {
  final files = collectScannableFiles(
    target,
    extensions: registeredExtensions,
    namePrefixes: registeredPrefixes,
    names: registeredNames,
    includeGenerated: includeGenerated,
  );
  return checkFiles(files, target);
}

/// Runs every enabled visitor over [files] (already walked);
/// [target] anchors config discovery. Findings sort and dedup
/// per SYS-CLI-001a §2.
CheckResult checkFiles(List<String> files, String target) {
  final enabled = enabledAnalyzers(target, ruleAnalyzers);
  final batched = enabled.where((r) => r.id == batchRuleId).toList();
  final immediate = enabled.where((r) => r.id != batchRuleId).toList();
  final (:findings, :errors, :msByRule) = analyzeFilesWithRules(
    files,
    immediate,
  );
  final all = [...findings];
  for (final rule in batched) {
    final batch = analyzeBatchRule(files, target, rule);
    all.addAll(batch.findings);
    errors.addAll(batch.errors);
    msByRule[rule.id] = (msByRule[rule.id] ?? 0) + batch.ms;
  }
  all.sort(_byFileRuleLine);
  return CheckResult(
    findings: deduplicateFindings(all),
    errors: errors,
    msByRule: msByRule,
  );
}

/// Runs the subprocess-batch rule over its scoped [files]
/// (FG-FMT-016: bounded `dart format` spawns, not per file).
/// Shared by the sequential and parallel scans so batch
/// verdicts never drift.
({List<CheckFinding> findings, List<CheckError> errors, int ms})
analyzeBatchRule(List<String> files, String target, RuleAnalyzer rule) {
  final findings = <CheckFinding>[];
  final errors = <CheckError>[];
  final watch = Stopwatch()..start();
  try {
    final verdicts = analyzeFormatBatch([
      for (final file in files)
        if (rule.scopes(file)) file,
    ]);
    for (final entry in verdicts.entries) {
      for (final violation in entry.value) {
        findings.add(
          CheckFinding(
            ruleId: rule.id,
            spec: rule.spec,
            file: entry.key,
            line: violation.line,
            message: violation.message,
            severity: rule.severityFor?.call(violation) ?? rule.severity,
          ),
        );
      }
    }
  } catch (error) {
    errors.add(CheckError(file: target, error: '$error'));
  }
  watch.stop();
  return (findings: findings, errors: errors, ms: watch.elapsedMilliseconds);
}

/// Deterministic finding order: file, rule id, line, then message
/// (the message tiebreak keeps the dedup collapse byte-stable).
int _byFileRuleLine(CheckFinding a, CheckFinding b) {
  final byFile = a.file.compareTo(b.file);
  if (byFile != 0) return byFile;
  final byRule = a.ruleId.compareTo(b.ruleId);
  if (byRule != 0) return byRule;
  final byLine = a.line.compareTo(b.line);
  if (byLine != 0) return byLine;
  return a.message.compareTo(b.message);
}

/// Collapses [sorted] findings on (file, line, rule), joining distinct
/// messages with `; `. Input must be in [_byFileRuleLine] order so the
/// collapse is byte-stable (SYS-CLI-001a §2).
List<CheckFinding> deduplicateFindings(List<CheckFinding> sorted) {
  final merged = <CheckFinding>[];
  final seen = <String>{};
  for (final finding in sorted) {
    final last = merged.isEmpty ? null : merged.last;
    final same =
        last != null &&
        last.file == finding.file &&
        last.line == finding.line &&
        last.ruleId == finding.ruleId;
    if (!same) {
      seen.clear();
      merged.add(finding);
      seen.add(finding.message);
    } else if (seen.add(finding.message)) {
      merged[merged.length - 1] = CheckFinding(
        ruleId: last.ruleId,
        spec: last.spec,
        file: last.file,
        line: last.line,
        message: '${last.message}; ${finding.message}',
        severity: last.severity,
      );
    }
  }
  return merged;
}

/// Runs [analyzers] over [files], collecting findings and one error
/// per broken file. Shared `check`/lite loop: findings sort by file,
/// then rule id, then line for determinism. Timings accrue per rule
/// (crash paths included — the clock stops past the catch).
({
  List<CheckFinding> findings,
  List<CheckError> errors,
  Map<String, int> msByRule,
})
analyzeFilesWithRules(List<String> files, List<RuleAnalyzer> analyzers) {
  final findings = <CheckFinding>[];
  final errors = <CheckError>[];
  final msByRule = <String, int>{};
  final seenErrors = <(String, String)>{};
  for (final file in files) {
    for (final rule in analyzers) {
      if (!rule.scopes(file)) continue;
      final watch = Stopwatch()..start();
      try {
        for (final violation in rule.analyze(file)) {
          findings.add(
            CheckFinding(
              ruleId: rule.id,
              spec: rule.spec,
              file: file,
              line: violation.line,
              message: violation.message,
              severity: rule.severityFor?.call(violation) ?? rule.severity,
            ),
          );
        }
      } catch (error) {
        // One broken file fails every visitor the same way; record it once.
        if (seenErrors.add((file, '$error'))) {
          errors.add(CheckError(file: file, error: '$error'));
        }
      }
      watch.stop();
      msByRule[rule.id] = (msByRule[rule.id] ?? 0) + watch.elapsedMilliseconds;
    }
  }
  findings.sort(_byFileRuleLine);
  return (findings: findings, errors: errors, msByRule: msByRule);
}

/// Runs the per-file × per-rule loop over one shard [request]
/// (keys `files` and `rules`: plain data only — no function
/// crosses the boundary; the worker re-resolves the registry
/// by id from its own copy, so the FG-LINT-009 `severityFor`
/// closure stays in-isolate). Top-level: the [Isolate.run]
/// computation shape. Returns plain-data maps (`findings`,
/// `errors`, `ms`) for [checkFilesParallel] to rehydrate.
/// Unknown rule ids are ignored (fail-open on ids: a typo
/// scans less, never verdicts).
Map<String, Object?> analyzeShard(Map<String, Object?> request) {
  final files = (request['files'] as List).cast<String>();
  final ids = Set<String>.from(request['rules'] as List);
  final analyzers = [
    for (final rule in ruleAnalyzers)
      if (ids.contains(rule.id)) rule,
  ];
  final (:findings, :errors, :msByRule) = analyzeFilesWithRules(
    files,
    analyzers,
  );
  return {
    'findings': [for (final finding in findings) finding.toJson()],
    'errors': [for (final error in errors) error.toJson()],
    'ms': msByRule,
  };
}

/// Splits [files] into at most [jobs] contiguous shards (empty
/// input yields no shards; [jobs] clamps to the file count so
/// no worker idles on an empty shard).
List<List<String>> shardFiles(List<String> files, int jobs) {
  if (files.isEmpty) return const [];
  final workers = jobs.clamp(1, files.length);
  final shards = <List<String>>[];
  var start = 0;
  for (var i = 0; i < workers; i++) {
    final size = ((files.length - start) / (workers - i)).ceil();
    shards.add(files.sublist(start, start + size));
    start += size;
  }
  return shards;
}

/// Runs one [request] in a worker isolate; on worker death the
/// shard re-runs sequentially in this isolate (fail-closed
/// fallback — output stays finding-identical, only slower).
/// [runShard] injects the spawn for tests; [onFallback] fires
/// once per fallen-back shard (tests pin the happy path at
/// zero).
Future<Map<String, Object?>> _runShard(
  Map<String, Object?> request, {
  Future<Map<String, Object?>> Function(Map<String, Object?> request)? runShard,
  void Function()? onFallback,
}) async {
  try {
    if (runShard != null) return await runShard(request);
    return await Isolate.run(() => analyzeShard(request));
  } catch (_) {
    onFallback?.call();
    return analyzeShard(request);
  }
}

/// Parallel scan: the same contract as [checkFiles], fanning
/// the per-file loop over [jobs] worker isolates (file shards;
/// the FG-FMT-016 batch still runs in this isolate). Merges
/// through the same deterministic tail, so results are
/// finding-identical to [checkFiles] (only `ms` values
/// differ). [jobs] ≤ 1 runs the sequential loop with no
/// isolate overhead; above the core count clamps to it.
/// [runShard] and [onFallback] are test seams (see [_runShard]).
Future<CheckResult> checkFilesParallel(
  List<String> files,
  String target, {
  required int jobs,
  Future<Map<String, Object?>> Function(Map<String, Object?> request)? runShard,
  void Function()? onFallback,
}) async {
  final enabled = enabledAnalyzers(target, ruleAnalyzers);
  final batched = enabled.where((r) => r.id == batchRuleId).toList();
  final immediate = enabled.where((r) => r.id != batchRuleId).toList();
  final ruleIds = [for (final rule in immediate) rule.id];
  var workers = jobs.clamp(1, Platform.numberOfProcessors);
  if (files.isNotEmpty) workers = workers.clamp(1, files.length);
  final findings = <CheckFinding>[];
  final errors = <CheckError>[];
  final msByRule = <String, int>{};
  if (workers <= 1) {
    final sync = analyzeFilesWithRules(files, immediate);
    findings.addAll(sync.findings);
    errors.addAll(sync.errors);
    msByRule.addAll(sync.msByRule);
  } else {
    final shards = shardFiles(files, workers);
    final results = await Future.wait([
      for (final shard in shards)
        _runShard(
          {'files': shard, 'rules': ruleIds},
          runShard: runShard,
          onFallback: onFallback,
        ),
    ]);
    for (final shard in results) {
      for (final raw in shard['findings'] as List) {
        final map = (raw as Map).cast<String, Object?>();
        findings.add(
          CheckFinding(
            ruleId: map['rule_id'] as String,
            spec: map['spec'] as String,
            file: map['file'] as String,
            line: map['line'] as int,
            message: map['message'] as String,
            severity: map['severity'] as String,
          ),
        );
      }
      for (final raw in shard['errors'] as List) {
        final map = (raw as Map).cast<String, Object?>();
        errors.add(
          CheckError(
            file: map['file'] as String,
            error: map['error'] as String,
          ),
        );
      }
      for (final entry in (shard['ms'] as Map).entries) {
        final id = entry.key as String;
        msByRule[id] = (msByRule[id] ?? 0) + (entry.value as int);
      }
    }
  }
  final all = [...findings];
  for (final rule in batched) {
    final batch = analyzeBatchRule(files, target, rule);
    all.addAll(batch.findings);
    errors.addAll(batch.errors);
    msByRule[rule.id] = (msByRule[rule.id] ?? 0) + batch.ms;
  }
  all.sort(_byFileRuleLine);
  return CheckResult(
    findings: deduplicateFindings(all),
    errors: errors,
    msByRule: msByRule,
  );
}

/// CLI usage for `check` (SYS-CLI-001a).
const _checkUsage =
    'Usage: dart run bin/flutterguard.dart check <path> [--json] [--include-generated] [--baseline=<path>] [--update-baseline] [--diff] [--diff-base=<ref>] [--analyze] [--dep-audit] [--license-audit] [--by-gate] [--evidence=<path>] [--jobs=<n>] [--help]';

/// Audits one target with every registered visitor. Returns 1 when any
/// error-severity violation is found, 0 when clean or warnings-only,
/// 2 on bad arguments. R2-2: `--baseline`/`--update-baseline` ratchet
/// plus `--diff` scope, with error/warning counts in the output.
/// The scan fans out to worker isolates when `--jobs` ≥ 2.
Future<int> check(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('json', negatable: false, help: 'Report findings as JSON.')
    ..addFlag(
      'include-generated',
      negatable: false,
      help: 'Scan generated files too.',
    )
    ..addOption(
      'baseline',
      help: 'Suppress findings ratcheted in this baseline file.',
    )
    ..addFlag(
      'update-baseline',
      negatable: false,
      help: 'Rewrite the --baseline file from this run.',
    )
    ..addFlag(
      'diff',
      negatable: false,
      help: 'Check only files changed vs the merge-base.',
    )
    ..addOption(
      'diff-base',
      help: 'Diff base ref (default origin/main; implies --diff).',
    )
    ..addFlag(
      'analyze',
      negatable: false,
      help: 'Also run dart analyze --fatal-infos (fails on issues).',
    )
    ..addFlag(
      'dep-audit',
      negatable: false,
      help: 'Also audit dependencies (fails on signals).',
    )
    ..addFlag(
      'license-audit',
      negatable: false,
      help: 'Also audit dependency licenses (fails on policy).',
    )
    ..addFlag(
      'by-gate',
      negatable: false,
      help: 'Report per-gate verdicts with timings.',
    )
    ..addOption('evidence', help: 'Append per-gate ledger lines to this path.')
    ..addOption(
      'jobs',
      defaultsTo: '1',
      help: 'Fan the scan out to N worker isolates (1 = sequential).',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  late final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_checkUsage);
    return 2;
  }
  if (parsed['help'] as bool) {
    stdout.writeln(_checkUsage);
    stdout.writeln(parser.usage);
    return 0;
  }
  final targets = parsed.rest;
  if (targets.length != 1) {
    stderr.writeln(_checkUsage);
    return 2;
  }
  final asJson = parsed['json'] as bool;
  final includeGenerated = parsed['include-generated'] as bool;
  final baselinePath = parsed['baseline'] as String?;
  final updateBaseline = parsed['update-baseline'] as bool;
  final diffBase = parsed['diff-base'] as String?;
  final diffMode = (parsed['diff'] as bool) || diffBase != null;
  if (updateBaseline && diffMode) {
    stderr.writeln('--update-baseline cannot be combined with --diff.');
    stderr.writeln(_checkUsage);
    return 2;
  }
  final updatePath = updateBaseline ? baselinePath : null;
  if (updateBaseline && updatePath == null) {
    stderr.writeln('--update-baseline requires --baseline <path>.');
    stderr.writeln(_checkUsage);
    return 2;
  }
  final jobsRaw = parsed['jobs'] as String?;
  final jobs = int.tryParse(jobsRaw ?? '');
  if (jobs == null || jobs < 1) {
    stderr.writeln('--jobs must be a positive integer (got "$jobsRaw").');
    stderr.writeln(_checkUsage);
    return 2;
  }
  final target = targets.single;
  late final CheckResult result;
  try {
    var files = collectScannableFiles(
      target,
      extensions: registeredExtensions,
      namePrefixes: registeredPrefixes,
      names: registeredNames,
      includeGenerated: includeGenerated,
    );
    if (diffMode) {
      final changed = resolveChangedFiles(target, diffBase ?? 'origin/main');
      files = [
        for (final file in files)
          if (changed.contains(absoluteNormalized(file))) file,
      ];
    }
    result = jobs <= 1
        ? checkFiles(files, target)
        : await checkFilesParallel(files, target, jobs: jobs);
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    return 2;
  }
  var analyzeFailed = false;
  var depFailed = false;
  var licenseFailed = false;
  var errors = result.errors;
  if (parsed['analyze'] as bool) {
    final AnalyzerResult analyzer;
    try {
      analyzer = runAnalyzer(target);
    } on ArgumentError catch (error) {
      stderr.writeln(error.message);
      return 2;
    }
    if (!analyzer.passed) {
      analyzeFailed = true;
      errors = [
        ...errors,
        for (final entry in groupAnalyzerIssues(analyzer.issues).entries)
          CheckError(file: entry.key, error: 'analyzer: ${entry.value}'),
      ];
    }
  }
  if (parsed['dep-audit'] as bool) {
    for (final pubspec in collectScannableFiles(
      target,
      extensions: const {},
      names: const {'pubspec.yaml'},
    )) {
      final DepAuditResult audit;
      try {
        audit = runDepAudit(File(pubspec).parent.path);
      } on ArgumentError catch (error) {
        stderr.writeln(error.message);
        return 2;
      }
      for (final finding in audit.findings) {
        depFailed = true;
        errors.add(
          CheckError(
            file: pubspec,
            error: 'dep-audit: ${finding.package}: ${finding.message}',
          ),
        );
      }
    }
  }
  if (parsed['license-audit'] as bool) {
    final section = RuleSection.load(target, 'licenses').value;
    final deny = <String>{};
    var allowPkgs = const <String, String>{};
    if (section is Map) {
      final rawDeny = section['deny'];
      if (rawDeny is List) {
        for (final entry in rawDeny) {
          if (entry is String && entry.isNotEmpty) deny.add(entry);
        }
      }
      final rawAllow = section['allow_pkgs'];
      if (rawAllow is Map) {
        allowPkgs = {
          for (final entry in rawAllow.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
        };
      }
    }
    if (deny.isEmpty) {
      stderr.writeln('no licenses.deny configured (nothing to enforce).');
      return 2;
    }
    for (final pubspec in collectScannableFiles(
      target,
      extensions: const {},
      names: const {'pubspec.yaml'},
    )) {
      final audit = runLicenseAudit(
        File(pubspec).parent.path,
        deny: deny,
        allowPkgs: allowPkgs,
      );
      for (final finding in audit.findings) {
        licenseFailed = true;
        errors.add(
          CheckError(
            file: pubspec,
            error: 'licenses: ${finding.package}: ${finding.message}',
          ),
        );
      }
    }
  }
  var findings = result.findings;
  if (baselinePath != null && !updateBaseline) {
    try {
      findings = applyBaseline(
        findings,
        loadBaseline(baselinePath),
        root: baselineRoot(target),
      );
    } on ArgumentError catch (error) {
      stderr.writeln(error.message);
      return 2;
    }
  }
  final byGate = parsed['by-gate'] as bool;
  final evidencePath = parsed['evidence'] as String?;
  final gates = byGate || evidencePath != null
      ? gateReport(
          rules: enabledAnalyzers(target, ruleAnalyzers),
          findings: findings,
          msByRule: result.msByRule,
        )
      : const <GateVerdict>[];
  if (evidencePath != null) {
    try {
      appendLedger(
        evidencePath,
        buildLedgerLines(
          target: target,
          gates: [
            for (final gate in gates)
              (ruleId: gate.ruleId, status: gate.status),
          ],
          findings: [
            for (final finding in findings)
              (ruleId: finding.ruleId, message: finding.message),
          ],
        ),
      );
    } on ArgumentError catch (error) {
      stderr.writeln(error.message);
      return 2;
    }
  }
  if (updatePath != null) {
    final root = baselineRoot(target);
    try {
      writeBaseline(updatePath, result.findings, root: root);
    } on ArgumentError catch (error) {
      stderr.writeln(error.message);
      return 2;
    }
    final files = baselineCounts(result.findings, root: root).length;
    if (asJson) {
      final payload = <String, Object?>{
        'baseline': updatePath,
        'files': files,
        'summary': {
          'errors': _countSeverity(result.findings, 'error'),
          'warnings': _countSeverity(result.findings, 'warning'),
        },
        if (byGate) 'gates': [for (final gate in gates) gate.toJson()],
      };
      stdout.writeln(jsonEncode(payload));
    } else {
      stdout.writeln(
        'Baseline written to $updatePath: $files files, '
        '${result.findings.length} findings '
        '(${_countSeverity(result.findings, 'error')} errors, '
        '${_countSeverity(result.findings, 'warning')} warnings).',
      );
      if (byGate) {
        for (final gate in gates) {
          stdout.writeln(gateLine(gate));
        }
      }
    }
    return analyzeFailed || depFailed || licenseFailed ? 1 : 0;
  }
  final shown = CheckResult(
    findings: findings,
    errors: errors,
    msByRule: result.msByRule,
  );
  for (final error in shown.errors) {
    stderr.writeln('error: ${error.file}: ${error.error}');
  }
  if (asJson) {
    final payload = shown.toJson();
    if (byGate) {
      payload['gates'] = [for (final gate in gates) gate.toJson()];
    }
    stdout.writeln(jsonEncode(payload));
  } else {
    for (final finding in shown.findings) {
      final prefix = finding.severity == 'warning' ? 'warning: ' : '';
      stdout.writeln(
        '$prefix${finding.ruleId} ${finding.file}:${finding.line} ${finding.message}',
      );
    }
    if (byGate) {
      for (final gate in gates) {
        stdout.writeln(gateLine(gate));
      }
    }
    stdout.writeln(
      '${shown.findings.length} violation(s) '
      '(${_countSeverity(shown.findings, 'error')} errors, '
      '${_countSeverity(shown.findings, 'warning')} warnings) '
      'in $target.',
    );
  }
  final gateFailed =
      analyzeFailed ||
      depFailed ||
      licenseFailed ||
      shown.findings.any((f) => f.severity == 'error');
  return gateFailed ? 1 : 0;
}
