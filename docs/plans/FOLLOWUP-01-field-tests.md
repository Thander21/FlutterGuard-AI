---
id: "FOLLOWUP-01"
title: "Field-test feedback log"
status: "open"
---

# FOLLOWUP-01: Field-Test Feedback Log

## Purpose

Collect findings from real-world use of FlutterGuard AI (post-release field
tests). Each finding graduates to a spec amendment, a calibration re-run, or
an item in a future plan — this file is the intake, not the disposition.

## Intake Seeds (carried, not started)

| # | Seed | Source | Re-entry |
|---|---|---|---|
| 1 | Tier-2 visual gate | SYS-VIEW-002 | Reachable endpoint + auth + verified schema + mask→widget mapping |
| 2 | Rebuild budget gate | SYS-PROF-001 (dropped spike) | A real per-Element rebuild-counter API |
| 3 | `*Sync` detection subset | AUDIT-01 §1.9 | Define "heavy sync work" criteria (FG-PERF-010) |
| 4 | MET/DRY/CRAP advisory→blocking flips | SYS-CAL-001 | Fresh corpus pass meeting the flip bar (precision 1.0, N ≥ 5) |
| 5 | Full-harness viewport orchestration | SYS-MCP-001 (`verify_viewport` v2) | v2 scope decision |
| 6 | `heal` CLI command | SYS-REL-001 R4 | Scope decision (lib driver exists: `HealDispatcher` + `healRecipeFor`) |
| 7 | Claude Code plugin + full skills | SYS-MCP-002 (draft) | Next feature: record §2 build decisions, implement matrix, scratch-install proof |

## Findings

| ID | Date | Finding | Disposition |
|---|---|---|---|
| F-001 | 2026-11-05 | Wave-1 scratch proof (SYS-MCP-002 M5): marketplace add + install from local folder works (`flutterguard@flutterguard` 0.1.0, enabled); `claude plugin validate` passes on plugin + marketplace (also `--strict`); MCP auto-registers and connects with the CLI present (`✔ Connected`); `fg-use` skill auto-discovers (`flutterguard:fg-use`); hooks fire in live sessions with `${CLAUDE_PLUGIN_ROOT}` expanding on Windows; missing CLI → PreToolUse exit 2 + install command, Edit blocked, agent relays the exact remediation (2/2 live runs with shipped files); hook + real global `check` → exit 2 with FG-FMT-016/IMP-015/LINT-009 findings + recipe pointers. Hermetic suite: `test/plugin_bundle_test.dart` 16/16, full `dart test` 218/218, `grade` all-green. Gaps found while proving: (a) Bash-mediated file writes bypass Edit/Write hooks — hooks are a tripwire, the pre-commit hook stays the barrier; (b) first-ever live session showed Pre/Post exit 0 once, irreproducible across 3 subsequent runs (suspected cold-start stdin stall — watch item, not a blocker); (c) `-p` sessions do not inherit the caller's PATH (shims invisible; global install required for in-session CLI); (d) path-activation `dart run` noise on check stdout falls back to raw findings text (verdict unaffected; git installs are silent). | Closes MCP-002 exit bar → spec approved; (a) recorded in MCP-002 §5 + README honesty note |
| F-002 | 2026-11-05 | Seed 6 (`heal` CLI) built per the SYS-VAL-001 thin-CLI decision: `lib/src/cli/heal.dart` + `heal` branch in `bin/` over `HealDispatcher` + `healRecipeFor` (zero heal logic in CLI); exit 0 healed / 1 rolled back / 2 bad args-or-rules; guided no-rule mode; `--json`; v1 emits no evidence (TELE-001 canon untouched — a HEAL producer needs `phase`/`action` values). Tests: `test/heal_cli_test.dart` 13/13 (exit codes, red→green ×3 fast-path rules, rollback + report, cap override, JSON map). Docs: HEAL-001 §2/§3/§4/§6 amended, `recipes.dart` follow-up note retired, README/LEIAME terminal surface +`heal`. | Seed 6 CLOSED by build (this commit); no re-entry |
| F-003 | 2026-11-05 | Seed 3 (`*Sync` subset) closed as ANSWERED: "heavy sync work" criteria were already defined in SPIKE-PERF-010 §2 (closed `*Sync`+`sleep` name set × jank scopes; general gate DROPPED with reason; subset parked as future EDD candidate). Correction: FG-PERF-010 is consumed by the dropped spike — the seed's "(FG-PERF-010)" label and VAL-001 F3's "PERF-010" shorthand are stale; the candidate mints a fresh ID per the spike §3 if ever built. No build (spike disposition stands). | Seed 3 CLOSED (criteria pre-exist); AUDIT-01 `*Sync` re-audit trigger stays (candidate still parked by design) |
| F-004 | 2026-11-05 | Seed 5 (viewport v2) decided: DROP full-harness orchestration ("lite suffices"). Foreign pumping needs target SDK + deps + unknowable constructors + context injection; no demanding target, no field finding; lite FG-LAY-004 covers the dominant class; rig verified 14/14 green 2026-11-05 and stays as own-fixture gate. Recorded in MCP-001 §2/§6 + VIEW-001 §6 pointer. | Seed 5 CLOSED as DROP with re-entry (target with widget tests + SDK requesting matrix-wrap, or field evidence of lite misses) |
| F-005 | 2026-11-05 | Seed 4 (MET/DRY/CRAP flips) evaluated: fresh corpus pass (118 files) + re-judgment of every flag. Params 1/1 N=1 (sole flag labeled TP), depth 1/1 N=1, DRY 0/5 actionable (all FP, known classes), CRAP 3/3 N=3 (findDuplication, visitExtensionDeclaration, _bagOf — same v2 methods). Sound measurement (no breaker timeouts, no new SKIPs). Flip bar (precision 1.0 + N≥5 + no open FP + sound) unmet everywhere → NO flips; all HOLD. No field corpus exists (validation records only) — repo+vectors fallback per VAL-001. Logged in CAL-001 §5; no pin changes. | Seed 4 CLOSED as evaluated-no-flip; re-entry automatic (tripwire fails on new real-code flags → forced re-calibration → flip re-evaluated) or future field corpus |

| F-006 | 2026-11-05 | Round-2 ERP re-pilot (`fb61306`, clean clone, same method): 694/694 parse-clean, FMT runs on Windows, zero generated findings; 2,355 findings led by MET-007 (1,913 advisory) and ASYNC-002 (209, 6/6 sampled FP — trust killer); new FP classes in MET/KEY/CTX/LIFE-ownership; no baseline/ratchet or diff mode (legacy adoption blocked); 76 exact duplicates. Real signals kept: 2 Drift-in-widget (ARCH-003), 1 undisposed controller (LIFE-001), 13 empty catches (LINT-009). Verdict: improved, still not gate-ready; interim selective yaml (ARCH/ST on, LIFE advisory, rest off). Report archived verbatim at `docs/pilots/RELATORIO_FlutterGuard_reteste_ERP.md`. | Chartered SYS-CAL-003 (draft): §2 verifies every claim, §3 programs R2-1–R2-6 in pilot order, Q1–Q3 + Q8–Q9 ratified 2026-11-05; R2-1 unblocked |
| F-007 | 2026-11-06 | R2-6 field probe r26-fiscal-03 (owner-run): first end-to-end mutation run on the ERP fiscal contingency guard (`nfce_contingency_limit_guard.dart` + `flutter_test` suite) via the `flutter test` path on Windows — 14 mutants, 9 killed, 5 survived, 181 s, green 10-test baseline (33.6 s, 5 min timeout), clean worktree. Shadow-package staging, the compile canary, and snapshot Flutter spawning held; the 9 kills confirm the mutant loads under `package:` imports. All 5 survivors are real test gaps, none equivalent (both block tests skip `hasSoftLimitWarning`; warning covered only at exactly count 30; the 24 h branch untested). Boundary note: the ERP AGENTS.md says `>24h`/`>72h` but the code uses `inHours >= 24`/`>= 72` — the contract must be pinned before the new tests land. | Closes the R2-6 execution bar (SYS-CAL-003 §5/§6); ERP test gaps → ERP-side test-only backlog (out of this repo); operator gaps → F-008 |
| F-008 | 2026-11-06 | Mutation operator gaps found by r26-fiscal-03: the v1 set (`>`→`<`, `>=`→`<=`, `==`→`!=`, `true`→`false`) never mutates `<=` (the ERP tenant guard `tenant <= 0` at line 90 went unmeasured) nor `false`→`true`. Specified follow-up: extend SYS-MUT-001 with `<=`→`>=` (sense-flip mirror of `>=`→`<=`, boundary kept) and `false`→`true` (mirror of `true`→`false`) — AST-sited (`BinaryExpression` LT_EQ, `BooleanLiteral` value `false`), same single-site discipline, one mutant per site. Work: amend the §2 operator table, extend `_MutantCollector`, flip the `<=`/`false` ignore-pins in `mutation_runner_test.dart` into positive cases, and update the AUDIT-01 §1.1/§1.10 "3 ops" rows. | CLOSED by SYS-MUT-001 amendment (this change): §2 table + `_MutantCollector` extended, ignore-pins flipped to positive cases, AUDIT-01 §1.1/§1.10/§6 updated |

## Rules

- One row per finding; link the graduated spec/plan amendment in Disposition.
- Re-entries also append to AUDIT-01 §6 (the re-entry log stays the audit
  trail).
- Closed seeds move to Disposition with the closing commit; never delete rows.
