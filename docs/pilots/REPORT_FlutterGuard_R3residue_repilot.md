# Post-R3-Residue Re-pilot Report (ERP `lib/`, 2026-11-13)

Agent-run field re-pilot after the R3 residue program (BUILD-014 message,
ARCH-003 carve-out, MET-007 v4, LIFE-001 `releasers:`), following the
PILOT-03 runbook method (read-only, scratch artifacts) against the
CAL-004 §5 acceptance bar.

## Provenance

- FlutterGuard: `ce9dda4` (clean tree, this repo), Dart 3.13.7, Windows x64.
- ERP: `2e19d2a` (clean tree, no `flutterguard.yaml`, no init).
- Denominator: 727 `.dart` files under `lib/` (+30 since the MVP run).
- Artifacts (ephemeral scratch, not archived): `postr3.json` (primary),
  `postr3-gates.txt`, `baseline.json`, `postr3-jobs4.json`.

## 0. Headline numbers

| | pilot 2 (`fb61306`) | MVP (`bc46a7b`) | R3 merged | this run |
|---|---|---|---|---|
| Files read clean | 694 / 694 | 697 / 697 | 697 / 697 | 727 / 727 |
| Parse errors (`FG-SYN-017`) | 0 | 0 | 0 | 0 |
| Per-file errors | — | 0 | 0 | 0 |
| Generated-file findings | 0 | 0 | 0 | 0 |
| Duplicates (file, line, rule) | 76 | 0 | 0 | 0 |
| Time (sequential / `--jobs 4`) | 31.6 s | 40 s / 28 s | — | 46.9 s / 27.6 s |
| Total findings (E / W) | 2,355 | 2,353 (516 / 1,837) | 1,974 (130 E) | 1,936 (114 / 1,822) |

Both main runs exit 1 (errors present); stderr empty.

## Per-rule table (vs R3 merged)

| Rule | R3 merged | This run | Delta cause |
|---|---|---|---|
| FG-MET-007 (W) | 1,826 | 1,810 | v4: params 145 → 48; depth 1,681 → 1,762 (ERP growth) |
| FG-LAY-004 | 80 | 80 | stable (all Text-in-Row strictness) |
| FG-LINT-009 | 27 | 28 (16E / 12W) | ERP evolution (+1 net) |
| FG-ASYNC-002 | 15 | 6 | new corpus census (ERP refactored the old files) |
| FG-ARCH-003 | 5 | 4 | Drift TPs fixed at source; 1 new per-contract |
| FG-TOK-020 | 3 | 3 | same TPs (line-shifted) |
| FG-LIFE-001 | 4 | 2 | support-modal TPs fixed at source; 2 new per-contract |
| FG-BUILD-014 | 1 | 1 | same TP, new message verified |
| FG-CC-025 | 1 | 1 | same TP (line-shifted) |
| FG-KEY-001r | 1 | 1 | new file, same inconclusive class |
| FG-ENC-022 | 4 | 0 | all 4 old TPs byte-verified fixed at source |
| FG-SYNC-034 | — (new) | 0 | no witness in corpus |
| FG-RIV-001 | 0 | 0 | clean |

Silent-without-config rules (BAN-018, LOG-019, I18N-021, ORP-023,
LYR-024, TST-033) are all absent: no defaults bug.

## Sampling verdicts

Census (≤10 findings) for ASYNC/ARCH/LIFE/BUILD/CC/KEY/TOK/ENC;
LINT error census + trio check; LAY directory-spread sample (8).

- **ASYNC-002, 6/6 TP** — all in
  `verticals/food_service/ui/tables/pages/tables_map_page.dart`
  (:487/:493/:499/:553/:555/:557): twin methods
  `_persistTableItem` / `_persistWeighedItem` use `S.of(context)!`
  in message closures after `await _launchTableItem` with no
  mounted guard. Real post-await gaps, no new FP class.
- **ARCH-003, 2 TP + 2 known-gap FP** — `user_form_page.dart:26`
  TP retained (`sb.Supabase` in UI);
  `pos_terminal_page_smartform.dart:35` TP-per-contract (`show
  PostgrestException` + parameter-type use at :623 breaks the
  carve-out, exactly per the ratified text);
  `company_form_page.dart:27` + `web_login_page.dart:32` FP,
  bare-exception imports (pinned known gap). The Drift TPs
  (`cbenef`/`cclasstrib`) are FIXED at source (denylisted
  imports gone).
- **LIFE-001, 2/2 per-contract** —
  `platform/update/update_service.dart:51/:52` (`Timer?`
  fields cancelled only in never-invoked `stopPeriodicCheck()`
  — the TS-04 K2 example shape, live). Needs ERP-side triage:
  owner-called (cross-file class) or dead (real leak).
  Support-modal TPs FIXED at source (proper `dispose()` added
  after the move to `modules/identity/ui/`).
- **ENC-022, 0 correct** — byte proof: `terminal_model` :83
  (`C3 9A`/`C3 BA`/`C3 A9`), `emergency_auth` :38 (`C3 89`/
  `C3 9A`), `form_section` :40 (`C3 8D`/`C3 A7 C3 A3`) are
  all valid UTF-8 now; C3-follower census over the three
  files shows only valid continuations; C2 count is zero.
  The single remaining `C3 83` sits in legitimate `ATENÇÃO`
  followed by ASCII `O` — the FP shape R3 deliberately
  passes. All 4 calibration TPs fixed at source.
- **BUILD-014, 1/1 TP** — `dashboard_page.dart:96` (line-shifted
  from :89): the new enclosing-builder message verified in
  the wild ("already inside a FutureBuilder").
- **TOK-020, 3/3 TP** — `app_shell_page.dart:416` (shifted),
  `main.dart:37` + `:46` (light/dark seedColors with bare
  `// ignore: design_tokens`). None in `lib/themes/`:
  default self-clean holds.
- **KEY-001r, FP (watch)** — `sequence_report_page.dart:272`:
  stateless `_SequenceCard` in a paginated static report
  list (no reorder, no local state). Same inconclusive
  class as the MVP 0/1; KEY stays 0/2 across runs, no
  action per R3-5.
- **LINT-009** — 16 errors = the 13 empty catches (incl. the
  `connection_io` trio at :47/:58/:83, line-shifted) + 3
  rationale-less `// ignore:` (by-rule TPs); 12 warnings.
  Retention holds exactly (13/13).
- **LAY-004** — all 80 are Text-in-Row strictness (documented
  T3 behavior, accepted, no action); `sale_history:160`
  retained at the same line (+:346 second instance).
- **SYNC-034** — no witness in corpus. The gate proves
  itself on vectors + unit fixtures; the field is silent
  (sticky-note watch, same posture as CTX-006).
- **CC-025** — same TP, line-shifted (:465 → :434).

## Adoption engine

- Baseline: `--update-baseline` exits 0 (156 files, 1,936
  findings); second run green, exit 0. Keys are `lib/`-relative
  (portable) — R3-4 holds in the field.
- `--diff --diff-base origin/main`: clean, exit 0 — vacuous
  (tree clean at HEAD, merge-base `2e19d2a` == HEAD).
- `--diff --diff-base HEAD~3`: clean, exit 0 — vacuous
  (6-file delta, docs-only, zero Dart files in scope).
- `--jobs 4`: finding-identical to sequential (sorted
  `(file, line, rule)` sets equal; 114/1,822), 27.6 s vs
  46.9 s.

## CAL-004 §5 bar verdict: met except the external corpus

ENC FP class gone with live correct-pass evidence; ASYNC
samples clean-per-contract with TP witnesses; LIFE census
per contract with reasons; baseline portable; TOK
self-clean; no new FP class; real signals retained or
fixed-at-source (Drift ×2, support-modal ×2, ENC ×4, plus
13/13 empty catches and sale_history:160 still flagging);
suite 540/540 + grade green; fixture-fidelity holds (every
residue fixture came from these shapes); bars hold on
vectors + dogfood. External corpus still pending (Q8,
third parties) — the charter stays draft until it lands.

## ERP-side backlog (out of this repo)

- ASYNC: `tables_map_page.dart` — 6 unguarded post-await
  context uses in `_persistTableItem`/`_persistWeighedItem`
  (add mounted guards).
- LIFE: `update_service.dart:51/:52` — wire up or drop
  `stopPeriodicCheck()` (timers unreleased otherwise).
- ARCH (info): `pos_terminal_page_smartform.dart:35` flags
  per contract (exception parameter type); no action
  unless the rule widens to exception-typed parameters.
