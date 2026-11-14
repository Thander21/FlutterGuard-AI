# External Corpus #2 Report: Null-Chronicle Game (2026-11-13)

Field evaluation of FlutterGuard-AI on a second, non-ERP codebase,
executed per `docs/prompt.md` (generic external-evaluation prompt).

## Method deviations (recorded)

- FG version is HEAD `06df48f` (detached worktree, cleaned up
  after), not the prompt's pinned `bc46a7b`: the pin predates R3
  and the residue program, and the pinned commits with the new
  rules are still local-only (third parties cannot fetch them
  until the origin push). The pin must advance together with
  that push.
- Agent-run, not third-party: corpus #2 is owner-adjacent (the
  owner's game), so independence is domain-level (game vs ERP
  business app), not evaluator-level. A true third-party run
  remains available as future hardening.
- Supplementary root-scope run added (labeled extra below) to
  witness the non-`lib/` rules for the first time.

## 0. Environment

- FG worktree `06df48f`, `dart pub get` clean (2 packages with
  newer incompatible versions noted, constraints respected).
- Dart 3.13.7 / Windows x64; Flutter 3.47.9 present (not used).
- Target `xGames/Null-Chronicle/lib` @ `19b4447`, git clean
  before AND after (non-pollution proven).
- Denominator: 102 `.dart` files.

## 1–2. Headline + per-rule tables

277 findings (202 errors / 75 warnings), exit 1, 15.4 s
sequential (15.3 s `--jobs 4`, finding-identical);
0 per-file errors, 0 `FG-SYN-017` (102/102 parse-clean),
0 duplicates, 0 generated-file findings.

| Rule | Findings | Files | Severity |
|---|---|---|---|
| FG-TOK-020 | 168 | 20+ | error |
| FG-MET-007 | 75 (66 depth / 9 params) | 12 | warning |
| FG-FMT-016 | 22 | 22 | error |
| FG-DOC-032 | 8 | 3 | error |
| FG-LINT-009 | 3 | 2 | error |
| FG-LAY-004 | 1 | 1 | error |

28 rules with zero findings: ARCH, ASYNC, LIFE, BUILD, CC,
KEY, ENC, RIV-001, RIV-026, SYNC, ST-001, ST-005, CTX-006,
WID-008, BLOC-001, IMP-015, BAN-018, LOG-019, I18N-021,
ORP-023, LYR-024, ARB-027, PII-028, ENV-029, ASSET-030,
VER-031, DOC-outside-`lib`, TST-033. Verified true
negatives: zero denylisted-package imports (ARCH), zero
`*Sync`/`sleep(` names (SYNC). SYNC is now silent on two
corpora (sticky-note watch, same posture as CTX-006).

## 3. Sampling TP/FP

- **TOK-020 (~9/168 TP-weak)** — palette file
  (`core/utils/constants.dart:15`, `AppColors` game palette —
  FP, same family as `*_colors` by content not name);
  level config (`fase1_config.dart`, 22× centralized per-level
  theme data — FP, a single app theme cannot hold per-level
  palettes); custom-painted Flame components
  (`floating_joystick.dart:33`, alpha-computed paints — FP);
  procedural renderer (`ground_renderer.dart`, const colors
  as a zero-alloc perf choice — FP); enemies/backgrounds/HUD
  sprites (FP, game-idiomatic). Closest to TP: Material
  overlay (`game_over_overlay.dart`, 9× neon literals —
  TP-weak, one-off game aesthetic).
- **MET-007 (TP-metric, advisory)** — depth 66× in 3 UI
  screens (same per-line noise profile as ERP); params
  census 9/9 (non-const wide ctors e.g. `alien_tree:52`
  with mutable fields; `power_up_config:86` const
  13-named with derived getters — correctly still flags
  per v4, second field confirmation of the partial fix).
- **FMT-016 (oracle-true)** — 22 files of formatting drift
  across gameplay code (full list in eval.json); project
  hygiene, out of FG scope.
- **DOC-032 (8/8 TP, first field witness)** —
  `ato1_endless_fragment_fall.md:498–501` (4 dead relative
  links incl. a duplicated-`lib/` stale path),
  `docs/USAGE.md:97/:292` (missing `ambiente.md`),
  `shared/null_character/USAGE.md:513/:514` (one-`../`-too-many
  links). All targets verified missing.
- **LINT-009 (3/3 TP)** — rationale-less `// ignore:
  unused_element` (:93) and `// ignore: discarded_futures`
  (:47); one real empty `catch (_) {}` (:156).
- **LAY-004 (1/1 TP)** — `game_over_overlay.dart:159`:
  bare `Text('JOGAR NOVAMENTE')` in a flex-less Row with no
  Expanded/ellipsis anywhere — genuine overflow risk,
  not the short-label strictness shape.

## 4. Judgments

| Rule | Precision | Judgment | Pattern |
|---|---|---|---|
| FG-TOK-020 | ~9/168 | RUIDOSA | game-idiomatic color sites |
| FG-MET-007 | metric-TP | RUIDOSA (aviso) | per-line depth noise, as ERP |
| FG-FMT-016 | oracle | CONFIÁVEL | formatting drift |
| FG-DOC-032 | 8/8 | CONFIÁVEL | rotting game-doc links |
| FG-LINT-009 | 3/3 | CONFIÁVEL | — |
| FG-LAY-004 | 1/1 | CONFIÁVEL | unguarded Text |

## 5. Defaults

All six silent-without-config rules absent with no
`flutterguard.yaml`: no defaults bug.

## 6. Adoption demo

- `--update-baseline`: exit 0 (51 files, 277 findings).
- Second run with `--baseline`: green, exit 0.
- Keys `lib/`-relative (portable).
- `--diff --diff-base origin/main`: exit 1, 216 findings
  scoped to the 208-file merge-base(`d35fb0a`)→HEAD delta
  (active dev branch) — scoping + blocking proven
  non-vacuously.

## 7. Extras

- `--jobs 4`: finding-identical (sorted sets equal).
- Root-scope run (extra, labeled): 308 findings; +21 DOC
  (rotting `.agents/` + `Docs/` + root READMEs, same TP
  class, one spot-verified), +8 FMT, +1 TOK (test file),
  +1 LINT. **Tool finding**: 2 noise findings on
  `.dart_tool/flutter_build/dart_plugin_registrant.dart`
  (FMT-016 + LINT-009 on a generated file) — the
  generated-file skip does not cover `.dart_tool/`
  (FOLLOWUP-01 F-028; needs owner direction on scope).

## 8. MVP verdict (game profile)

a) Crash/parse error in a valid file? No (102/102 clean,
   0 errors).
b) Read coverage? 100%.
c) Precision? DOC/LINT/LAY all-TP; MET TP-metric;
   TOK ~9/168 (game-idiom noise); FMT oracle-true.
d) Time acceptable? Yes (15 s for 102 files).
e) Baseline+diff for legacy adoption? Yes (both proven,
   diff non-vacuous).

**Recomendação: APROVAR-COM-RESSALVAS** — engine sound on
a second domain; game profile needs selective yaml.
Top 3 blockers: (1) TOK-020 game-idiom noise (168),
(2) MET per-line depth noise (advisory), (3) project
FMT drift (22, hygiene). Suggested selective yaml:

```yaml
rules:
  FG-TOK-020: false   # game-idiomatic color sites; or except game dirs
```

Everything else on (MET is warning-only; FMT/LINT/LAY/DOC
all-TP here; the rest silent).
