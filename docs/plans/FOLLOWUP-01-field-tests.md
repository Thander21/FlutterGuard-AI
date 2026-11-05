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

(No field findings yet — append below as `F-001`, `F-002`, ...)

| ID | Date | Finding | Disposition |
|---|---|---|---|
| | | | |

## Rules

- One row per finding; link the graduated spec/plan amendment in Disposition.
- Re-entries also append to AUDIT-01 §6 (the re-entry log stays the audit
  trail).
- Closed seeds move to Disposition with the closing commit; never delete rows.
