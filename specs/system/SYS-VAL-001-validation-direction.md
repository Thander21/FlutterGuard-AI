---
spec_version: "openspec-1.0"
id: "SYS-VAL-001"
title: "Validation direction: MCP-002 + FOLLOWUP-01 ordered backlog"
status: "approved"
kind: "system"
---

# 1. Problem

Two pending artifacts hold the project's entire forward backlog with no
ordered direction: SYS-MCP-002 (draft, 5 build items) and FOLLOWUP-01
(open, 7 seeds, zero findings). Without an order, effort can land on
blocked items (Tier-2 has no endpoint, rebuild budget has no API) while
the one build that generates field evidence — client packaging — waits.
Smallest observable misbehavior this must prevent: a week spent on a
blocked seed while the distribution path that would produce the first
field finding stays unbuilt. This contract consolidates all 12 pending
points into one ordered backlog ranked by validation leverage, and
records the direction decision. Owner approved the wave order on
2026-11-05 (see §2) and decided F6 (thin `heal` CLI) and plugin
distribution (GitHub-installed folder + marketplace). Next step: the
MCP-002 build starts (Wave 1).

# 2. Interface / Schema

Consolidated backlog (M = MCP-002 item, F = FOLLOWUP seed; F7 expands
into M1–M5):

| # | Source | Item | Cost | Blocked? | Validation signal |
|---|---|---|---|---|---|
| M1 | MCP-002 §2 | Build-time decisions (plugin root, manifest, local-vs-marketplace) | S | No | Design gate for M2–M5 |
| M2 | MCP-002 §2 | Per-client install matrix (Claude/Cursor/Gemini/Muse) | M | M1 | Core thesis: agents run governed in real clients |
| M3 | MCP-002 §2 | `fg-use` row in MCP-001 chat-skills table | S | No | Daily-loop contract coherence |
| M4 | MCP-002 §3 | README/LEIAME one-install path | S | M1 | Stranger-install onboarding |
| M5 | MCP-002 §5 | Scratch-install end-to-end proof | S | M2+M4 | Whole distribution story; first field finding |
| F1 | FOLLOWUP-01 | Tier-2 visual gate | L | YES — endpoint/auth/schema | Visual semantics beyond Tier-1 |
| F2 | FOLLOWUP-01 | Rebuild budget gate | M | YES — no per-Element API | Rebuild discipline |
| F3 | FOLLOWUP-01 | `*Sync` detection subset | S | No | PERF-010 scope precision before speccing |
| F4 | FOLLOWUP-01 | MET/DRY/CRAP advisory→blocking flips | M | No (needs corpus) | Calibration rigor (precision-1.0 bar) |
| F5 | FOLLOWUP-01 | Full-harness viewport orchestration | M/L | Scope decision | Orchestration value over Tier-1-lite |
| F6 | FOLLOWUP-01 | `heal` CLI command — DECIDED thin CLI | S/M | No (decided 2026-11-05) | HEAL-001 in real hands; human loop closure |
| F7 | = M1–M5 | Claude Code plugin + full skills | — | — | Distribution; generates findings for F1–F6 |

Wave order (APPROVED 2026-11-05 — "distribution before detection
depth"):

- Wave 1 — distribution (M1→M3+M4→M2→M5): decisions, then docs/table +
  matrix, then the scratch-install proof. Exit: governed loop proven
  from a clean machine; first finding lands in FOLLOWUP-01.
- Wave 2 — cheap loop closure (F6 thin-CLI build, F3 spike, F5 scope
  decision): all unblocked, small, high signal. F6 completes the
  human check→heal→recheck loop; F3 prevents an over-broad PERF-010.
- Wave 3 — data-driven (F4 corpus pass; F5 build only if the Wave-2
  scope decision says so): F4 ideally consumes the Wave-1 field
  corpus, falls back to existing vectors.
- Parked (re-entry owned by FOLLOWUP-01 + AUDIT-01 §6): F1, F2 —
  externally blocked; any spend before re-entry criteria is waste.

Decided inputs (2026-11-05, recorded here; MCP-002 §2 takes the final
build shape at Wave-1 build time):

- Plugin ships BOTH as a GitHub-installed folder (no review gate,
  first) and via marketplace (in-plan, not demand-gated).
- F6 builds a thin CLI over `HealDispatcher` + `healRecipeFor`: no new
  heal logic in the CLI layer; any needed logic lands in
  `lib/src/heal/` (HEAL-001 owns heal logic).

# 3. File Placement

- `specs/system/SYS-VAL-001-validation-direction.md` (this contract;
  the grader skips `specs/system/` non-recursively and `kind: system`
  explicitly).
- References, not copies: `specs/system/SYS-MCP-002-client-packaging.md`
  (packaging content owner), `docs/plans/FOLLOWUP-01-field-tests.md`
  (intake owner). This spec orders; it never forks their content.
- Wave outputs land where their owners say: plugin root + README/LEIAME
  (MCP-002), `F-NNN` rows (FOLLOWUP-01), re-entry log (AUDIT-01 §6).
- No `lib/`, `bin/`, or `test/` files: an ordering contract ships no
  code.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: no gate runs. The Wave-1 proof produces a
manual scratch-install log referenced from the first FOLLOWUP-01
finding row. Any future telemetry from shipped waves MUST amend
SYS-TELE-001 first (canon rule §4).

# 5. Errors and Edges

- Owner rejects the wave order: this spec re-orders; MCP-002 and
  FOLLOWUP-01 stay untouched (single responsibility per artifact).
- A parked seed unblocks early (endpoint/API appears): re-entry via
  FOLLOWUP-01 rules + AUDIT-01 §6 log; this spec's PARKED verdict is
  history, not a lock.
- F6 is DECIDED thin CLI (2026-11-05): the "no CLI" outcome is off
  the table. If the build finds the wrapper needs new heal logic,
  that logic lands in `lib/src/heal/`, never in the CLI layer.
- F5 scope decision says "lite suffices": same DROP treatment;
  Tier-1-lite remains the orchestration story.
- F4 corpus pass misses the flip bar: no flip; the pass itself is the
  finding (bar holds, precision protected).
- Exit bar (decision clauses met 2026-11-05): wave order approved;
  F6 + distribution decided. Execution handoff: MCP-002 build starts
  next (Wave 1); FOLLOWUP-01 gains its first finding from the M5
  proof. This spec needs no further edits unless the wave order is
  challenged mid-flight.

# 6. Contradictions Resolved

- Depth vs distribution (implicit across FOLLOWUP seeds): distribution
  wins for sequencing — field evidence first, detection depth after.
  F1/F2 depth is parked, not cancelled.
- Consolidation vs duplication (this spec vs MCP-002/FOLLOWUP-01):
  this spec orders and references; content owners keep their files.
  Any duplicated paragraph here is a bug.
- `heal` CLI existence (FOLLOWUP seed 6 vs HEAL-001 lib-only):
  settled 2026-11-05 — thin CLI wins; HEAL-001 keeps owning all heal
  logic, the CLI only wraps it.
- Plugin distribution (MCP-002 "marketplace on field demand" vs
  owner intent): settled 2026-11-05 — BOTH channels in-plan,
  GitHub-installed folder first (no gate), marketplace alongside.
  MCP-002 §2 records the final shape at build; its "demand-gated"
  sequencing is superseded.
