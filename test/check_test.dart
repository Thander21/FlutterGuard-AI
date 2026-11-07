import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

void main() {
  group('check', () {
    test('flags every .bad vector and spares every .good vector', () {
      final result = checkPath('benchmark/vectors');
      expect(
        result.errors,
        hasLength(1),
        reason: 'only the intentional TC-17 syntax error throws visitors',
      );
      expect(result.errors.single.file, endsWith('TC-17_syn.bad.dart'));
      expect(result.errors.single.error, contains('missing_identifier'));
      final flagged = result.findings.map((f) => f.file).toSet();
      expect(
        flagged,
        containsAll([
          'benchmark/vectors/TC-01_bloc.bad.dart',
          'benchmark/vectors/TC-02_riverpod.bad.dart',
          'benchmark/vectors/TC-03_controller.bad.dart',
          'benchmark/vectors/TC-04_life.bad.dart',
          'benchmark/vectors/TC-05_arch.bad.dart',
          'benchmark/vectors/TC-06_async.bad.dart',
          'benchmark/vectors/TC-07_lay.bad.dart',
          'benchmark/vectors/TC-08_st.bad.dart',
          'benchmark/vectors/TC-09_ctx.bad.dart',
          'benchmark/vectors/TC-10_wid.bad.dart',
          'benchmark/vectors/TC-11_lint.bad.dart',
          'benchmark/vectors/TC-12_key.bad.dart',
          'benchmark/vectors/TC-13_met.bad.dart',
          'benchmark/vectors/TC-14_build.bad.dart',
          'benchmark/vectors/TC-15_imp.bad.dart',
          'benchmark/vectors/TC-16_fmt.bad.dart',
          'benchmark/vectors/TC-17_syn.bad.dart',
          'benchmark/vectors/tc18/TC-18_ban.bad.dart',
          'benchmark/vectors/tc19/TC-19_log.bad.dart',
          'benchmark/vectors/TC-20_tok.bad.dart',
          'benchmark/vectors/tc21/TC-21_i18n.bad.dart',
          'benchmark/vectors/TC-22_enc.bad.dart',
          'benchmark/vectors/tc24/ui/TC-24_layer.bad.dart',
          'benchmark/vectors/TC-25_cc.bad.dart',
          'benchmark/vectors/TC-27_arb.bad.arb',
          'benchmark/vectors/tc28/TC-28_pii.bad.dart',
          'benchmark/vectors/tc29/bad/.env',
        ]),
      );
      expect(
        flagged.any((f) => f.contains('.good.')),
        isFalse,
        reason: 'zero false positives on .good vectors',
      );
    });

    test('reports rule id, line, and recipe pointer per finding', () {
      final result = checkPath('benchmark/vectors/TC-01_bloc.bad.dart');
      expect(result.findings, hasLength(1));
      final finding = result.findings.single;
      expect(finding.ruleId, 'FG-BLOC-001');
      expect(finding.line, 26);
      final json = finding.toJson();
      expect(json['rule_id'], 'FG-BLOC-001');
      expect(json['spec'], 'specs/TS-01-bloc-emit-guard.md');
      expect(json['recipe'], contains('TS-01'));
    });

    test('throws on a missing target', () {
      expect(() => checkPath('does/not/exist'), throwsArgumentError);
    });

    test('rules run only on files matching their extensions', () {
      RuleAnalyzer probe(String id, {Set<String>? extensions}) {
        return RuleAnalyzer(
          id: id,
          spec: 'specs/TS-01-bloc-emit-guard.md',
          analyze: (file) => [_ProbeViolation(file)],
          extensions: extensions ?? const {'.dart'},
        );
      }

      final result = analyzeFilesWithRules(
        ['a.dart', 'b.arb'],
        [
          probe('FG-PROBE-DART'),
          probe('FG-PROBE-ARB', extensions: const {'.arb'}),
        ],
      );
      expect(result.findings.map((f) => '${f.ruleId}:${f.file}'), [
        'FG-PROBE-DART:a.dart',
        'FG-PROBE-ARB:b.arb',
      ]);
      expect(result.errors, isEmpty);
    });

    test('rules match basename prefixes (.env*)', () {
      final envOnly = RuleAnalyzer(
        id: 'FG-PROBE-ENV',
        spec: 'specs/TS-01-bloc-emit-guard.md',
        analyze: (file) => [_ProbeViolation(file)],
        extensions: const {},
        namePrefixes: const {'.env'},
      );
      final result = analyzeFilesWithRules(
        ['a.dart', '.env', 'dir/.env.local'],
        [envOnly],
      );
      expect(result.findings.map((f) => f.file), ['.env', 'dir/.env.local']);
      expect(result.errors, isEmpty);
    });

    test('analyzer crash becomes a report-only error, run continues', () {
      final boom = RuleAnalyzer(
        id: 'FG-BOOM-000',
        spec: 'specs/TS-01-bloc-emit-guard.md',
        analyze: (_) => throw StateError('boom'),
      );
      final result = analyzeFilesWithRules(
        ['benchmark/vectors/TC-01_bloc.good.dart'],
        [boom],
      );
      expect(result.findings, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.error, contains('boom'));
    });

    test('each .bad vector is flagged only by its own rule', () {
      const expected = <String, String>{
        'benchmark/vectors/TC-01_bloc.bad.dart': 'FG-BLOC-001',
        'benchmark/vectors/TC-02_riverpod.bad.dart': 'FG-RIV-001',
        'benchmark/vectors/TC-03_controller.bad.dart': 'FG-ST-001',
        'benchmark/vectors/TC-04_life.bad.dart': 'FG-LIFE-001',
        'benchmark/vectors/TC-05_arch.bad.dart': 'FG-ARCH-003',
        'benchmark/vectors/TC-06_async.bad.dart': 'FG-ASYNC-002',
        'benchmark/vectors/TC-07_lay.bad.dart': 'FG-LAY-004',
        'benchmark/vectors/TC-08_st.bad.dart': 'FG-ST-005',
        'benchmark/vectors/TC-09_ctx.bad.dart': 'FG-CTX-006',
        'benchmark/vectors/TC-10_wid.bad.dart': 'FG-WID-008',
        'benchmark/vectors/TC-11_lint.bad.dart': 'FG-LINT-009',
        'benchmark/vectors/TC-12_key.bad.dart': 'FG-KEY-001r',
        'benchmark/vectors/TC-13_met.bad.dart': 'FG-MET-007',
        'benchmark/vectors/TC-14_build.bad.dart': 'FG-BUILD-014',
        'benchmark/vectors/TC-15_imp.bad.dart': 'FG-IMP-015',
        'benchmark/vectors/TC-16_fmt.bad.dart': 'FG-FMT-016',
        'benchmark/vectors/TC-17_syn.bad.dart': 'FG-SYN-017',
        'benchmark/vectors/tc18/TC-18_ban.bad.dart': 'FG-BAN-018',
        'benchmark/vectors/tc19/TC-19_log.bad.dart': 'FG-LOG-019',
        'benchmark/vectors/TC-20_tok.bad.dart': 'FG-TOK-020',
        'benchmark/vectors/tc21/TC-21_i18n.bad.dart': 'FG-I18N-021',
        'benchmark/vectors/TC-22_enc.bad.dart': 'FG-ENC-022',
        'benchmark/vectors/tc24/ui/TC-24_layer.bad.dart': 'FG-LYR-024',
        'benchmark/vectors/TC-25_cc.bad.dart': 'FG-CC-025',
        'benchmark/vectors/TC-26_prov.bad.dart': 'FG-RIV-026',
        'benchmark/vectors/TC-27_arb.bad.arb': 'FG-ARB-027',
        'benchmark/vectors/tc28/TC-28_pii.bad.dart': 'FG-PII-028',
        'benchmark/vectors/tc29/bad/.env': 'FG-ENV-029',
      };
      final result = checkPath('benchmark/vectors');
      for (final entry in expected.entries) {
        final rules = result.findings
            .where((f) => f.file == entry.key)
            .map((f) => f.ruleId)
            .toSet();
        expect(rules, isNotEmpty, reason: '${entry.key} was not flagged');
        expect(
          rules,
          everyElement(entry.value),
          reason: '${entry.key} has cross-rule findings: $rules',
        );
      }
    });

    test('fails closed on an unparseable file (FG-SYN-017 finding)', () {
      final root = Directory.systemTemp.createTempSync('check_test.');
      try {
        File('${root.path}/broken.dart').writeAsStringSync('class { !!!');
        final result = checkPath(root.path);
        expect(result.findings, isNotEmpty);
        expect(
          result.findings.map((f) => f.ruleId),
          everyElement('FG-SYN-017'),
          reason: 'unparseable files fail closed via FG-SYN-017',
        );
        expect(result.errors, hasLength(1));
        expect(result.errors.single.file, endsWith('broken.dart'));
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('marks blocking findings error and advisories warning', () {
      final errors = checkPath('benchmark/vectors/TC-01_bloc.bad.dart');
      expect(errors.findings, isNotEmpty);
      expect(errors.findings.every((f) => f.severity == 'error'), isTrue);
      expect(errors.findings.single.toJson()['severity'], 'error');

      final advisories = checkPath('benchmark/vectors/TC-13_met.bad.dart');
      expect(advisories.findings, isNotEmpty);
      expect(advisories.findings.every((f) => f.severity == 'warning'), isTrue);
      expect(
        advisories.findings.every((f) => f.ruleId == 'FG-MET-007'),
        isTrue,
      );
      expect(advisories.findings.first.toJson()['severity'], 'warning');
    });

    test('skips generated files unless opted in (SYS-CAL-002 P0-3)', () {
      final root = Directory.systemTemp.createTempSync('check_test.');
      try {
        final bad = File('benchmark/vectors/TC-01_bloc.bad.dart')
            .readAsStringSync();
        File('${root.path}/plain.dart').writeAsStringSync(bad);
        final generated = File('${root.path}/store.g.dart')
          ..writeAsStringSync(bad);
        File('${root.path}/app_localizations_en.dart').writeAsStringSync(bad);
        final genDir = Directory('${root.path}/generated')..createSync();
        File('${genDir.path}/schema.dart').writeAsStringSync(bad);

        final skipped = checkPath(root.path);
        expect(skipped.findings, isNotEmpty);
        expect(
          skipped.findings.map((f) => f.file),
          everyElement(endsWith('plain.dart')),
        );

        final included = checkPath(root.path, includeGenerated: true);
        expect(included.findings.map((f) => f.file).toSet(), hasLength(4));

        expect(checkPath(generated.path).findings, isEmpty);
        expect(
          checkPath(generated.path, includeGenerated: true).findings,
          isNotEmpty,
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('skips config-disabled rules (immediate path)', () {
      final root = Directory.systemTemp.createTempSync('check_test.');
      try {
        File('${root.path}/bloc.dart').writeAsStringSync(
          File('benchmark/vectors/TC-01_bloc.bad.dart').readAsStringSync(),
        );
        expect(checkPath(root.path).findings, isNotEmpty);
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('version: 2\nrules:\n  FG-BLOC-001: false\n');
        expect(checkPath(root.path).findings, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('skips config-disabled rules (batched FMT path)', () {
      final root = Directory.systemTemp.createTempSync('check_test.');
      try {
        File('${root.path}/messy.dart').writeAsStringSync('void  main()  {}\n');
        expect(checkPath(root.path).findings, isNotEmpty);
        File('${root.path}/flutterguard.yaml')
            .writeAsStringSync('version: 2\nrules:\n  FG-FMT-016: false\n');
        expect(checkPath(root.path).findings, isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    });

    test('deduplicates findings on file, line, and rule (R2-2)', () {
      const first = CheckFinding(
        ruleId: 'FG-X',
        spec: 's',
        file: 'f.dart',
        line: 3,
        message: 'first',
      );
      const dupe = CheckFinding(
        ruleId: 'FG-X',
        spec: 's',
        file: 'f.dart',
        line: 3,
        message: 'first',
      );
      const second = CheckFinding(
        ruleId: 'FG-X',
        spec: 's',
        file: 'f.dart',
        line: 3,
        message: 'second',
      );
      const other = CheckFinding(
        ruleId: 'FG-Y',
        spec: 's',
        file: 'f.dart',
        line: 3,
        message: 'first',
      );
      final merged = deduplicateFindings([first, dupe, second, other]);
      expect(merged, hasLength(2));
      expect(merged.first.message, 'first; second');
      expect(merged.last.ruleId, 'FG-Y');
    });

    test('checkPath emits no duplicate finding keys over the vectors', () {
      final result = checkPath('benchmark/vectors');
      final keys = result.findings
          .map((f) => '${f.file}:${f.line}:${f.ruleId}')
          .toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('checkPath summary counts errors and warnings (R2-2)', () {
      final errors = checkPath('benchmark/vectors/TC-01_bloc.bad.dart');
      expect(errors.toJson()['summary'], {'errors': 1, 'warnings': 0});
      final advisories = checkPath('benchmark/vectors/TC-13_met.bad.dart');
      final summary = advisories.toJson()['summary'] as Map;
      expect(summary['errors'], isZero);
      expect(summary['warnings'], greaterThan(0));
    });
  });

  group('parallel scan (--jobs)', () {
    List<String> vectorFiles() => collectScannableFiles(
      'benchmark/vectors',
      extensions: registeredExtensions,
      namePrefixes: registeredPrefixes,
      names: registeredNames,
    );

    List<Map<String, Object?>> findingMaps(CheckResult result) => [
      for (final finding in result.findings) finding.toJson(),
    ];

    List<Map<String, Object?>> errorMaps(CheckResult result) => [
      for (final error in result.errors) error.toJson(),
    ];

    test('parallel scan is finding-identical to sequential', () async {
      final files = vectorFiles();
      final sequential = checkFiles(files, 'benchmark/vectors');
      var fallbacks = 0;
      final parallel = await checkFilesParallel(
        files,
        'benchmark/vectors',
        jobs: 4,
        onFallback: () => fallbacks++,
      );
      expect(
        fallbacks,
        isZero,
        reason: 'happy path must run in workers, never fall back',
      );
      expect(findingMaps(parallel), equals(findingMaps(sequential)));
      expect(errorMaps(parallel), equals(errorMaps(sequential)));
      expect(parallel.msByRule.keys.toSet(), sequential.msByRule.keys.toSet());
    });

    test('jobs 1 runs the sequential loop with no isolates', () async {
      final files = vectorFiles();
      final sequential = checkFiles(files, 'benchmark/vectors');
      var fallbacks = 0;
      final parallel = await checkFilesParallel(
        files,
        'benchmark/vectors',
        jobs: 1,
        onFallback: () => fallbacks++,
      );
      expect(fallbacks, isZero);
      expect(findingMaps(parallel), equals(findingMaps(sequential)));
    });

    test(
      'dead worker falls back to sequential with identical output',
      () async {
        final files = vectorFiles();
        final sequential = checkFiles(files, 'benchmark/vectors');
        var fallbacks = 0;
        final parallel = await checkFilesParallel(
          files,
          'benchmark/vectors',
          jobs: 4,
          runShard: (_) => throw StateError('dead worker'),
          onFallback: () => fallbacks++,
        );
        expect(fallbacks, greaterThan(0));
        expect(findingMaps(parallel), equals(findingMaps(sequential)));
        expect(errorMaps(parallel), equals(errorMaps(sequential)));
      },
    );

    test('analyzeShard resolves the registry by id, ignoring unknown ids', () {
      final result = analyzeShard({
        'files': ['benchmark/vectors/TC-01_bloc.bad.dart'],
        'rules': ['FG-BLOC-001', 'FG-NOPE-999'],
      });
      final findings = result['findings'] as List;
      expect(findings, isNotEmpty);
      expect(
        findings.every((raw) => (raw as Map)['rule_id'] == 'FG-BLOC-001'),
        isTrue,
      );
      expect((result['ms'] as Map).keys, ['FG-BLOC-001']);
    });

    test('shardFiles splits contiguously without empty shards', () {
      expect(shardFiles([], 4), isEmpty);
      expect(shardFiles(['a', 'b', 'c', 'd', 'e'], 2), [
        ['a', 'b', 'c'],
        ['d', 'e'],
      ]);
      expect(shardFiles(['a', 'b'], 8), [
        ['a'],
        ['b'],
      ]);
    });
  });
}

/// Probe violation for the extension-scope test.
class _ProbeViolation implements RuleViolation {
  _ProbeViolation(this.file);

  final String file;

  @override
  int get line => 1;

  @override
  String get message => 'probe $file';
}
