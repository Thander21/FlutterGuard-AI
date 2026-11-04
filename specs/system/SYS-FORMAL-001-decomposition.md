---
spec_version: "openspec-1.0"
id: "SYS-FORMAL-001"
title: "Formal prover decomposition (build or drop)"
status: "approved"
kind: "system"
---

# 1. Problem

`FormalVerificationAlgorithms.md` specifies 5 prover-grade engines
(DFA typestate, Cassowary intervals, program slicing, Lamport
happens-before, Cousot lattices) that none build as documented:
they need CFGs, constraint propagation, dataflow, and interleaving
proofs no parse-only visitor can do. This contract decomposes each
prover into covered subsets (existing rules), one new EDD rule,
recorded drops, and one v2 backlog — so every formal idea ends
built, covered, dropped with reason, or explicitly backlogued.
Zero orphans.

# 2. Interface / Schema

Decomposition table (IDs assigned here at decomposition time):

| prover | subset | disposition | detail |
|---|---|---|---|
| FORMAL-001 typestate (§1.2.3 async gap) | context-after-await without guard | COVERED | FG-ASYNC-002 + FG-BLOC-001 enforce the checkable subset (dominator formalism not implemented; parse-only approximation) |
| FORMAL-001 (§1.2.4 liveness) | every dispose() exit path releases | DROP | needs CFG path-sensitivity; `try/finally` + conditional disposal defeat parse-only order checks; FG-LIFE-001 covers the common case (missing release entirely) |
| FORMAL-001 closures | FG-MEM-011 retained closures | ABSORBED + DROP | listener-add without `removeListener` already a FG-LIFE-001 table row; capture-escape remainder needs region analysis — dropped |
| FORMAL-002 intervals (theorem) | unbounded scrollable in flex | COVERED | FG-LAY-004 v0 proves the Column×ListView case |
| FORMAL-002 engine | interval vectors + screen dims | DROP | needs runtime dimensions + constraint propagation across the tree — not a static rule |
| FORMAL-002 axes | Row-axis + GridView/CustomScrollView | COVERED | TS-07 v2 (2026-11-04): Row axis + GridView/CustomScrollView in Column/Row; runtime truth probed on Flutter 3.47.9 (Row ignores shrinkWrap); spec + vectors + visitor amended, no new ID |
| FORMAL-003 purity (§3.2.1 controllers) | controller allocation in build() | COVERED | FG-ST-001 |
| FORMAL-003 purity (§3.2.1 async) | fire-and-forget async in build() | BUILD | FG-BUILD-014 — full EDD loop (TS-14): `Future.*` (minus `value`), `Timer`, socket allowlist, `.then/.catchError/.whenComplete`, `unawaited` directly in build scope; closures (event handlers) skipped |
| FORMAL-003 slicing (§3.2.2) | FG-WASTE-015 RebuildWasteIndex > 0.80 | DROP | forward-slice "reads derived values" needs resolved dataflow + reads analysis; unimplementable statically at precision |
| FORMAL-004 happens-before | FG-RACE-013 stale-race guards | DROP (spike) | absence-of-guard ≠ presence-of-race: most unguarded async emits are race-free (serialized UI flows); no trigger separates them parse-only (nor resolved — needs interleaving proof). Lifecycle half already covered (BLOC-001/ASYNC-002) |
| FORMAL-005 lattice | FG-FSM-012 boolean-soup FSM | DROP (spike) | boolean-density trigger too weak (legit multi-bool states everywhere); sealed-mandate + no-`default` remedy fights framework idioms (`AsyncValue` IS a sum type; `default` is valid forward-compat) |

Spike method (RACE-013, FSM-012): trigger-precision analysis
against the parse-only ceiling + remedy-proportionality check. No
code was written: a spike that cannot name a precise trigger with
a proportionate remedy ends in a recorded drop, not a prototype.

# 3. File Placement

- `specs/system/SYS-FORMAL-001-decomposition.md` (this record).
- FG-BUILD-014 EDD set (only build in this contract):
  `specs/TS-14-async-in-build-guard.md`,
  `benchmark/vectors/TC-14_build.bad.dart` (+ `.good.dart`),
  `lib/src/ast/async_build_guard.dart`,
  `test/async_build_guard_test.dart`, `rules.dart` entry,
  regenerated `lib/src/mcp/recipes.dart` (14 rules).
- Dropped IDs (FG-MEM-011, FG-WASTE-015, FG-RACE-013, FG-FSM-012)
  live ONLY in this table — never minted as specs, never reused.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: decomposition publishes here.
FG-BUILD-014 emits the standard grade lines (2 vectors) once its
EDD loop lands.

# 5. Errors and Edges

- Dropped ≠ forbidden forever: a drop records why the subset is
  unbuildable under the CURRENT analysis ceiling (parse-only) or
  precision bar. A future resolved-analysis or CFG engine may
  revisit any drop by amending this table — never by silently
  minting the ID.
- TS-07 v2 backlog was the only backlog: built 2026-11-04,
  amending TS-07 (spec + vectors + visitor) — no new rule ID,
  no new golden pair namespace (extended TC-07). No backlogs
  remain in this table.
- BUILD-014 vectors stay MET/DRY-neutral (shallow trees, small
  ctors, no 16-line twins): the calibration tripwire pins the
  ratified sets, and deliberate vector shapes must not force a
  re-calibration. The new visitor itself re-ratifies DRY (new
  guard-idiom pairs judged under SYS-CAL-001 §5 on landing).
- MEM-011's ID is consumed by the absorb+drop: no future rule
  may take FG-MEM-011 (same for all dropped IDs in §2).

# 6. Contradictions Resolved

- Provers vs EDD loop (PLAN-01/02: "none builds as documented"):
  confirmed per prover — the engines drop, their checkable
  subsets were already (or are now) EDD rules. The formal doc
  stays the theoretical reference; this table is the build
  disposition.
- ST-001 naming (PLAN-02 pre-audit wart: `FG-ST-001` +
  `FG-ST-005` share the prefix): BUILD-014 takes a fresh area
  (`BUILD`) instead of overloading `ST` — full IDs stay the
  lookup key either way.
