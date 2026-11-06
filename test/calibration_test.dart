// SYS-CAL-001 tripwire: pins the ratified MET flag set, DRY pair
// membership, and the unparseable-skip set. Any detector or
// codebase change that moves the numbers fails here ON PURPOSE —
// re-run `dart tool/calibrate.dart`, re-judge every flag, amend
// SYS-CAL-001, then update these pins. Never update pins without
// re-judging. (CRAP is excluded: slow suites trip the 8s breaker,
// so it cannot pin deterministically.)
import 'dart:io';

import 'package:flutterguard_ai/flutterguard_ai.dart';
import 'package:test/test.dart';

/// Ratified MET flag set (SYS-CAL-001 §2): `file:line`.
/// v2 (2026-11-04): both FP classes excluded by the detector
/// (data-holder params, scaffold transparency) — only the two
/// labeled TPs remain.
/// M1 (2026-11-06): +1 FP (`rules.dart:42` declarative config
/// ctor — pinned, HOLD).
/// M2 (2026-11-06): re-keyed rules 42 -> 43 (import shift).
const _ratifiedMetFlags = {
  'benchmark/vectors/TC-13_met.bad.dart:7',
  'benchmark/vectors/TC-13_met.bad.dart:29',
  'lib/src/cli/rules.dart:43',
};

/// Ratified unparseable-skip set (SYS-CAL-001 §2): corpus files the
/// MET scan skips (they cannot be measured). Exactly one by design:
/// TS-17's golden negative.
const _ratifiedSkipped = {'benchmark/vectors/TC-17_syn.bad.dart'};

/// Ratified DRY pairs over `lib/` (SYS-CAL-001 §2):
/// `fileA:lineA~fileB:lineB` in canonical order. The 3 TPs were
/// healed into `lib/src/util.dart` (re-ratification 2026-11-03);
/// v2 (2026-11-04): data-holder exclusion eliminated the ten
/// data-class pairs; the 3 survivors are known FP classes
/// (guard idiom ×2, thin wrappers).
/// REL-001 R3: +1 procedural-flow twin (moved `init()`); 4 pinned.
/// Wave 2: +1 procedural-flow twin (new `heal()`); 5 pinned.
/// SYS-CAL-002 P0-1: analyzer-14 token change eliminated the
/// metric~widget guard-idiom pair; reformat shifted 3 keys; 4 pinned.
/// SYS-CAL-002 P1+P2: init growth dissolved the 2 procedural twins;
/// new CoverageRunner~=MutationRunner runner-pipeline FP; 3 pinned.
/// SYS-CAL-003 R2-1: AsyncContextGuard growth (scope + closures)
/// surfaced the async~listkey guard-idiom FP; 4 pinned.
/// SYS-CAL-003 R2-2: check() growth (baseline/diff/counts)
/// surfaced the check~=init procedural-flow-twin FP; 5 pinned.
/// SYS-CAL-003 R2-3: CTX-006 rewrite surfaced the collector
/// guard-idiom FP; 6 pinned.
/// SYS-CAL-003 R2-4: ListKeyGuard rewrite dissolved the
/// async~=listkey twin (eliminated-FP) and shifted the collector
/// pair key 223 -> 306; 5 pinned.
/// SYS-CAL-003 R2-5 gate 1: new BannedSymbolGuard growth
/// surfaced the banned~=metric guard-idiom FP; the init
/// template example shifted the check~=init key 75 -> 80;
/// 6 pinned.
/// SYS-CAL-003 R2-5 gate 2: shared rule_params extraction +
/// new PrintLoggerGuard surfaced the entry-function
/// runner-pipeline FP; the BAN shrink shifted banned 160 ->
/// 130 and the init example shifted init 80 -> 85; 7 pinned.
/// SYS-CAL-003 R2-5 gate 3: new ThemeTokenGuard surfaced the
/// config-class and entry-function runner-pipeline FPs; the
/// init example shifted init 85 -> 90; 9 pinned.
/// SYS-CAL-003 R2-5 gate 4: FlatRuleConfig heal dissolved all
/// 8 config/entry twins; 2 whole-guard idiom FPs survive; the
/// init example shifted init 90 -> 95; 8 pinned.
/// SYS-CAL-003 R2-5 gate 7: RuleListConfig heal dissolved the
/// config/parse twins; the residual entry twin rates FP
/// (wiring only); BAN keys to 73/97, tok to 98, init to 100;
/// 9 pinned.
/// SYS-CAL-003 R2-5 tail T1: complexity guard twins nothing;
/// 9 pinned.
/// SYS-CAL-003 R2-5 tail T2: new ProviderNamingGuard surfaced
/// the ctx~=prov whole-guard idiom FP; 10 pinned.
/// SYS-CAL-003 R2-5 tail T4: check() growth (file scopes +
/// batch filter) re-keyed check~=init 221 -> 233 and surfaced
/// the checkFiles~=_siblingImport procedural-flow-twin FP;
/// 11 pinned.
/// SYS-CAL-003 R2-5 tail T5: init template growth (pii
/// example) re-keyed check~=init 100 -> 107; new PiiGuard
/// surfaced the banned~=_ArgScanner guard-idiom FP; 12 pinned.
/// SYS-CAL-003 R2-5 tail T6: call-site growth (prefix scopes)
/// re-keyed checkFiles 111 -> 112 and check 233 -> 234; new
/// EnvGuard surfaced the enc~=env runner-pipeline FP; 13 pinned.
/// SYS-CAL-003 R2-5 medium M1: `names:` call-site growth
/// re-keyed checkFiles 112 -> 113 and check 234 -> 235; new
/// AssetGuard surfaced the asset~=env runner-pipeline FP; the
/// RuleAnalyzer 8th param surfaced the rules:42 MET FP; 14 pinned.
/// SYS-CAL-003 R2-5 medium M2: import shift re-keyed
/// checkFiles 113 -> 114 and rules 42 -> 43; the check~=init
/// procedural twin dissolved (eliminated-FP); no new twins
/// from 9 new files; 13 pinned.
/// SYS-CAL-003 R2-5 medium M3-M5: the checkFiles twin
/// dissolved (2nd check-family elimination); new _git~=
/// runDepAudit runner-pipeline FP + new heal~=init
/// procedural-flow-twin FP; 14 pinned.
const _ratifiedLibPairs = {
  'lib/src/ast/arch_layer_guard.dart:74~lib/src/ast/controller_build_guard.dart:54',
  'lib/src/ast/asset_guard.dart:30~lib/src/ast/env_guard.dart:30',
  'lib/src/ast/banned_symbol_guard.dart:73~lib/src/ast/layer_guard.dart:81',
  'lib/src/ast/banned_symbol_guard.dart:97~lib/src/ast/i18n_guard.dart:67',
  'lib/src/ast/banned_symbol_guard.dart:97~lib/src/ast/metric_guard.dart:53',
  'lib/src/ast/banned_symbol_guard.dart:97~lib/src/ast/pii_guard.dart:182',
  'lib/src/ast/context_scope_guard.dart:43~lib/src/ast/provider_naming_guard.dart:60',
  'lib/src/ast/context_scope_guard.dart:91~lib/src/ast/list_key_guard.dart:306',
  'lib/src/ast/encoding_guard.dart:39~lib/src/ast/env_guard.dart:30',
  'lib/src/ast/i18n_guard.dart:67~lib/src/ast/theme_token_guard.dart:98',
  'lib/src/cli/baseline.dart:169~lib/src/cli/deps.dart:87',
  'lib/src/cli/heal.dart:76~lib/src/cli/init.dart:113',
  'lib/src/mcp/tools.dart:197~lib/src/mcp/tools.dart:219',
};

const _ratifiedViewportPairs = {
  'viewport/test/fixtures/bad_layout.dart:5~viewport/test/fixtures/good_layout.dart:5',
};

void main() {
  group('SYS-CAL-001 tripwire', () {
    test('MET flag set is exactly the ratified 3', () {
      final files = _corpusFiles([
        'lib',
        'bin',
        'test',
        'tool',
        'viewport/lib',
        'viewport/test',
        'samples',
        'benchmark/vectors',
      ]);
      final flags = <String>{};
      final skipped = <String>{};
      for (final file in files) {
        try {
          for (final violation in analyzeMetricFile(file)) {
            flags.add('$file:${violation.line}');
          }
        } on ArgumentError {
          skipped.add(file);
        }
      }
      expect(
        skipped,
        _ratifiedSkipped,
        reason:
            'unparseable corpus files must stay exactly the designed one'
            ' — re-calibrate per SYS-CAL-001 §5',
      );
      expect(
        flags,
        _ratifiedMetFlags,
        reason: 'MET numbers moved — re-calibrate per SYS-CAL-001 §5',
      );
    });

    test('DRY pair membership is exactly the ratified set', () {
      String keyOf(ClonePair pair) =>
          '${pair.fileA}:${pair.lineA}~${pair.fileB}:${pair.lineB}';

      final lib = findDuplication('lib');
      expect(lib.errors, isEmpty);
      expect(
        {for (final p in lib.pairs) keyOf(p)},
        _ratifiedLibPairs,
        reason: 'DRY/lib numbers moved — re-calibrate per SYS-CAL-001 §5',
      );

      for (final root in ['bin', 'tool']) {
        final verdict = findDuplication(root);
        expect(verdict.errors, isEmpty, reason: root);
        expect(verdict.pairs, isEmpty, reason: root);
      }

      final viewport = findDuplication('viewport');
      expect(viewport.errors, isEmpty);
      expect(
        {for (final p in viewport.pairs) keyOf(p)},
        _ratifiedViewportPairs,
        reason: 'DRY/viewport numbers moved — re-calibrate per SYS-CAL-001 §5',
      );
    });
  });
}

List<String> _corpusFiles(List<String> roots) {
  final files = <String>[];
  for (final root in roots) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path.replaceAll(r'\', '/'));
      }
    }
  }
  return files..sort();
}
