---
spec_version: "openspec-1.0"
id: "SYS-REL-001"
title: "Release hardening: license, changelog, CLI layering, heal table, gates"
status: "approved"
kind: "system"
---

# 1. Problem

Field tests are about to start, but the repo is not release-shaped: no
license (a public git URL is all-rights-reserved by default), no changelog,
product logic living in `bin/` and imported by tests through relative
paths, a heal dispatcher whose HEAL-001-promised production recipe lookup
does not exist, P2 gates without documented CLI limits, a default analyzer
(no lints), dogfood blind to `tool/`, unrecorded evidence retention, no CI,
no docs index, and README links that do not mark hackathon history as
history. Smallest observable misbehavior this prevents: shipping 0.1.0
unlicensed, or with "auto-heal" claims the production code cannot honor.

# 2. Interface / Schema

Disposition table (all 11 hardening items):

| # | Item | Disposition | Validate |
|---|---|---|---|
| R1 | LICENSE (MIT) | BUILD (new file) | File exists, full MIT body, holder line exact |
| R2 | CHANGELOG.md 0.1.0 | BUILD (new file) | Exists, heading matches pubspec version, covers the §2 list |
| R3 | CLI layering (`bin/` → `lib/src/cli/`) | BUILD (refactor, byte-identical) | Full suite green, no `../bin/` imports, thin `bin/` |
| R4 | Heal fast-path production table | BUILD (new file + tests) | Table pins + red→green per entry, suite green |
| R5 | P2-limits note (README + LEIAME) | BUILD (docs) | Paragraph present in both, claims match this spec |
| R6 | `analysis_options.yaml` + `lints` | BUILD (land-clean rule) | `dart analyze --fatal-infos` clean, zero new suppressions |
| R7 | Dogfood covers `tool/` | BUILD (one-line + fixes) | Dogfood green |
| R8 | Evidence retention policy | DECIDE (no code) | Policy recorded in §4; nothing to run |
| R9 | Minimal CI workflow | BUILD (new file) | YAML valid; commands green locally, observed green on push |
| R10 | Docs index (`docs/README.md`) | BUILD (new file) | Exists; every link resolves |
| R11 | Hackathon-history note (README + LEIAME) | BUILD (docs) | One line in both; links untouched |

Per-item contracts:

- **R1**: root `LICENSE`, MIT text, `Copyright (c) 2026 Rahman Brussolo`
  (holder confirmed by owner at go).
  MIT wins per §6. No per-file headers (root file suffices by Dart
  convention).
- **R2**: root `CHANGELOG.md`, `## 0.1.0` entry covering: 17 AST rules
  (16 blocking + MET-007 advisory), `check`/`grade`/`init`/`sandbox` CLI
  + pre-commit hook, heal dispatcher, mutation runner, Tier-1 viewport +
  lite fallback, coverage/CRAP + duplication (advisory), MCP server
  (5 tools), calibration HOLD verdicts, Tier-2 deferred.
- **R3**: move `grade*` → `lib/src/cli/grade.dart`, `init*` →
  `lib/src/cli/init.dart`, `sandbox` → `lib/src/cli/sandbox.dart`,
  `check()` wrapper → `lib/src/cli/check.dart` (joins `checkPath`);
  export from `lib/flutterguard_ai.dart`. `bin/flutterguard.dart`
  keeps `main` (explicit `exit()`, REVIEW-01) + `_run` dispatch only
  (~60 lines). Tests import the package, never `../bin/`. Behavior is
  byte-identical: exit codes, stdout/stderr, evidence lines.
- **R4**: new `lib/src/heal/recipes.dart`: `const fastPathRecipes =
  <String, HealRecipe>` with exactly the HEAL-001 closed mechanical
  list — `FG-BLOC-001` insert `if (isClosed) return;`, `FG-RIV-001`
  replace `ref.watch` → `ref.read`, `FG-ASYNC-002` insert
  `if (!context.mounted) return;` — plus `HealRecipe?
  healRecipeFor(String ruleId)` (unknown id → null). Export from the
  package. Execution stays agent-dispatched; a `heal` CLI command is a
  non-goal here (FOLLOWUP-01 seed at implementation).
- **R5**: one paragraph (EN + PT) stating: mutation/coverage/
  duplication/heal ship as Dart API + tests + partial MCP
  (`run_mutation_check`, lite `verify_viewport`); the terminal surface
  is `check`/`grade`/`init`/`sandbox`; fuller CLI coverage is follow-up.
- **R6**: root `analysis_options.yaml` with `include:
  package:lints/recommended.yaml` + `lints` dev-dep (version resolved
  by `dart pub add --dev lints` at implementation — the only new
  dependency allowed here). Land-clean rule: `dart analyze
  --fatal-infos` clean by FIXING; suppressions forbidden (FG-LINT-009);
  a noisy rule may be disabled in the yaml only with an inline reason,
  recorded as a spec amendment.
- **R7**: add `'tool'` to `_roots` in `test/dogfood_test.dart`; fix any
  error-severity findings in `tool/`.
- **R8**: `evidence.jsonl` stays tracked; checkpoint commits after eval
  milestones; rotation revisit trigger at 1MB. Schema stays owned by
  SYS-TELE-001 (rotation would amend it first).
- **R9**: `.github/workflows/ci.yml` (creates `.github/`): on push +
  pull_request, Dart stable: `dart pub get`, `dart analyze
  --fatal-infos lib bin test tool`, `dart test`. Non-goals:
  Flutter/viewport job, grade
  job (repo-local doctrine, PLAN-03), publish job.
- **R10**: `docs/README.md` index: plans = process + intake (incl.
  FOLLOWUP-01), `_origem/` frozen, `_rulesHackathon/` out of scope,
  `specs/` normative, root README/LEIAME entry points.
- **R11**: one line (EN + PT) in the README/LEIAME doc maps marking the
  three hackathon links as event history, not requirements.

Build order: docs batch (R1, R2, R5, R10, R11; R8 records itself) → R6
→ R3 → R4 → R7 → R9. R6 lands before R3/R4 so moved and new code is
lint-clean on arrival; R9 last (it guards everything above).

# 3. File Placement

- `specs/system/SYS-REL-001-release-hardening.md` (this contract; the
  grader skips `specs/system/` non-recursively and `kind: system`
  explicitly).
- Creates: `LICENSE`, `CHANGELOG.md`, `analysis_options.yaml`,
  `docs/README.md`, `.github/workflows/ci.yml`,
  `lib/src/cli/grade.dart`, `lib/src/cli/init.dart`,
  `lib/src/cli/sandbox.dart`, `lib/src/heal/recipes.dart`.
- Modifies: `bin/flutterguard.dart` (thin dispatch),
  `lib/src/cli/check.dart` (+ `check()` wrapper),
  `lib/flutterguard_ai.dart` (+ exports), `pubspec.yaml` (`lints`
  dev-dep), `test/check_cli_test.dart`, `test/grade_test.dart`,
  `test/init_test.dart`, `test/telemetry_canon_test.dart` (package imports),
  `test/dogfood_test.dart`
  (`tool/` root), `test/heal_dispatcher_test.dart` (table pins +
  ASYNC-002 fixture), `README.md` + `LEIAME.md` (R5, R11),
  `docs/plans/FOLLOWUP-01-field-tests.md` (`heal`-CLI seed),
  `specs/system/SYS-CAL-001-calibration.md` (re-ratification for R3;
  see §5).

# 4. Evidence Wiring

Emits no `evidence.jsonl`: this contract changes no gate verdict. R3 is
byte-identical (grade lines unchanged or the suite fails); R4 is
additive API. CI runs no `grade` (repo-local doctrine). Retention
policy (R8): tracked + checkpoint commits, 1MB revisit trigger.

# 5. Errors and Edges

- The CAL-001 tripwire is EXPECTED to fail when R3 lands (DRY/lib
  pairs shift as `bin/` code enters `lib/`) and possibly after R6
  fixes: follow the designed process — `dart tool/calibrate.dart`,
  re-judge, amend SYS-CAL-001, update pins. Never update pins without
  re-judging. New files SHOULD land MET/DRY-clean to avoid widening
  the re-ratification.
- `cli/*` must never import `bin/` (one-way layering; the move exists
  to kill that direction).
- R4 ASYNC-002 anchor is the violation line (guard inserted above the
  flagged use — the §2 injected form); fixture red→green per entry is
  mandatory, not just table pins.
- R6 surprise volume: unknown until the first linted run. If fixes
  exceed a focused pass, land the yaml with the offending rules
  disabled + inline reasons (allowed above), and carry the remainder
  as a FOLLOWUP-01 row — never suppress per-line.
- R1 holder override and R6 `lints` version resolve at implementation;
  record both in the landing commit message.
- R9 runs untrusted-PR-safe commands only (no secrets, no publish).

# 6. Contradictions Resolved

- PLAN-03 CI non-goal vs R9: reversed for the minimal workflow only —
  the field-test phase needs a regression signal; Flutter/viewport and
  publish jobs stay non-goal.
- HEAL-001 §3 "production wiring" vs reality (lookup by rule id
  promised, only §2 markdown for agents exists): this contract delivers
  the `HealRecipe` lookup; markdown recipes stay agent-facing per
  SYS-RECIPE-001. No contradiction remains.
- Evidence tracked vs rotate: tracked wins at current scale (59KB);
  the 1MB trigger decides later with data.
- MIT vs Apache-2.0: MIT wins — the simplest permissive grant matching
  "free for use and edit", without patent-clause machinery the project
  does not need.
