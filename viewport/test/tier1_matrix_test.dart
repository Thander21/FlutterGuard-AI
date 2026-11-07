// SYS-VIEW-001 contract test: bad layout red, good layout green,
// screenshots harvested, evidence lines match the SYS-TELE-001 canon.
//
// Run with cwd `viewport/`: `flutter test` (pure, no evidence writes).
// Proof run: `flutter test --dart-define=FG_EVIDENCE=../evidence.jsonl`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tier1_rig/tier1.dart';

import 'fixtures/bad_layout.dart';
import 'fixtures/good_layout.dart';

/// Opt-in evidence sink (SYS-VIEW-001 §2); empty = pure mode.
const _evidence = String.fromEnvironment('FG_EVIDENCE');

String? get _evidencePath => _evidence.isEmpty ? null : _evidence;

void main() {
  for (final c in tier1Matrix) {
    testWidgets('bad layout breaks: ${c.name}', (tester) async {
      final errors = await runTier1Case(
        tester,
        app: () => const BadLayout(),
        c: c,
        fixture: 'bad_layout',
      );
      appendTier1Evidence(
        fixture: 'bad_layout',
        c: c,
        errors: errors,
        evidencePath: _evidencePath,
      );
      expect(
        errors,
        isNotEmpty,
        reason: 'bad_layout must overflow ${c.name} (red)',
      );
      expect(
        File('build/test_snapshots/bad_layout_${c.name}.png').existsSync(),
        isTrue,
        reason: 'Tier-2 feed PNG is contractual',
      );
    }, timeout: const Timeout(Duration(seconds: 8)));
  }

  for (final c in tier1Matrix) {
    testWidgets('good layout clean: ${c.name}', (tester) async {
      final errors = await runTier1Case(
        tester,
        app: () => const GoodLayout(),
        c: c,
        fixture: 'good_layout',
      );
      appendTier1Evidence(
        fixture: 'good_layout',
        c: c,
        errors: errors,
        evidencePath: _evidencePath,
      );
      expect(
        errors,
        isEmpty,
        reason: 'good_layout must stay clean on ${c.name} (green)',
      );
      expect(
        File('build/test_snapshots/good_layout_${c.name}.png').existsSync(),
        isTrue,
        reason: 'Tier-2 feed PNG is contractual',
      );
    }, timeout: const Timeout(Duration(seconds: 8)));
  }

  test('evidence lines match the SYS-TELE-001 canon', () {
    final dir = Directory.systemTemp.createTempSync('tier1_evidence_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/evidence.jsonl';
    appendTier1Evidence(
      fixture: 'good_layout',
      c: tier1Matrix.first,
      errors: const [],
      evidencePath: path,
    );
    appendTier1Evidence(
      fixture: 'bad_layout',
      c: tier1Matrix.first,
      errors: const ['A RenderFlex overflowed by 1680 pixels.'],
      evidencePath: path,
    );
    final lines = File(path).readAsLinesSync();
    expect(lines, hasLength(2));
    final clean = jsonDecode(lines[0]) as Map<String, dynamic>;
    expect(clean.keys.toList(), [
      'timestamp',
      'phase',
      'rule_id',
      'file',
      'status',
      'error_message',
      'recipe_injected',
      'iteration',
      'action',
    ]);
    expect(clean['phase'], 'VIEWPORT_GATE');
    expect(clean['rule_id'], 'SYS-VIEW-001');
    expect(clean['file'], 'good_layout:compact-pos');
    expect(clean['status'], 'PASSED');
    expect(clean['error_message'], '');
    expect(clean['recipe_injected'], '');
    expect(clean['iteration'], 1);
    expect(clean['action'], 'EVAL_RECORDED');
    final broken = jsonDecode(lines[1]) as Map<String, dynamic>;
    expect(broken['file'], 'bad_layout:compact-pos');
    expect(broken['status'], 'FAILED');
    expect(broken['error_message'], 'A RenderFlex overflowed by 1680 pixels.');
  });

  test('null evidence path is pure (no writes)', () {
    appendTier1Evidence(
      fixture: 'good_layout',
      c: tier1Matrix.first,
      errors: const [],
      evidencePath: null,
    );
  });
}
