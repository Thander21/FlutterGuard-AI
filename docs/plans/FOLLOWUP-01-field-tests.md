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

## Rules

- One row per finding; link the graduated spec/plan amendment in Disposition.
- Re-entries also append to AUDIT-01 §6 (the re-entry log stays the audit
  trail).
- Closed seeds move to Disposition with the closing commit; never delete rows.
