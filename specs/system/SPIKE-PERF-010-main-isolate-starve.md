---
spec_version: "openspec-1.0"
id: "FG-PERF-010"
title: "Main Isolate Starve spike (criteria defined, gate dropped)"
status: "dropped"
kind: "system"
---

# 1. Problem

"Heavy sync work on the main isolate" janks frames, but heaviness
is a runtime property (payload sizes, loop bounds) — this spike
(PLAN-02) defines what is statically detectable before any spec
exists. Outcome: the general gate is DROPPED (heaviness needs
profiling, not parsing); the definable I/O subset is recorded as
a future EDD candidate with exact criteria.

# 2. Interface / Schema

## Defined criteria (static subset)

"Heaviness" splits by detectability:

| class | examples | statically definable? |
|---|---|---|
| blocking sync I/O | `readAsStringSync`, `writeAsStringSync`, `readAsBytesSync`, `listSync`, `existsSync`, `statSync`, `createSync`, `deleteSync`, `sleep()` | YES — closed `*Sync` + `sleep` name set (`dart:io`), always blocks |
| unbounded loops | `while` on network state, recursion | NO — bound-dependent |
| payload decode | `jsonDecode`, `utf8.decode`, image decode | NO — size-dependent; flagging all `jsonDecode` is FP city |
| compute kernels | hashing, layout math | NO — input-dependent |

Jank scopes (where blocking matters): `build()` bodies and `on*`
widget-handler closures (`onPressed: () { ...Sync... }`) —
frames. CLI tools, tests, `initState`, and isolate callbacks
(`compute`) are NOT jank scopes: sync work there is legitimate.

## Disposition: DROP the gate, keep the candidate

FG-PERF-010 as a general "heavy sync work" rule is DROPPED:
three of four classes need runtime measurement (same family as
the SYS-PROF-001 conclusion — profiling questions get profilers,
not parsers). The `*Sync`-in-jank-scopes subset is a recorded
FUTURE EDD CANDIDATE (criteria above; no spec minted, no vectors):
tight trigger (closed name set × jank scopes), high precision,
narrow value (async-first ecosystem rarely emits it). A future
turn builds it through the standard loop (spec → vectors →
visitor → test → grade) if prioritized.

## Explicit non-subsets

- `compute()` is the FIX (moves work off the isolate) — never a
  trigger (also an FG-BUILD-014 fp_limit).
- `Future`/`Timer`/sockets-in-build belong to FG-BUILD-014
  (already built) — no overlap claimed here.

# 3. File Placement

- `specs/system/SPIKE-PERF-010-main-isolate-starve.md` (this
  record; `SPIKE-` prefix marks research records).
- No `lib/`, `bin/`, or `test/` files: a dropped spike ships no
  code. The FG-PERF-010 ID is consumed by this record — no future
  rule may take it (same rule as the SYS-FORMAL-001 dropped IDs).
  The `*Sync` candidate mints a fresh ID if ever built.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: no gate runs.

# 5. Errors and Edges

- Scope precision note: `on*` handlers match by named-argument
  shape (`onPressed: () {...}`), the same callback doctrine as
  FG-RIV-001 — torn-off or stored callbacks stay out of reach
  (documented ceiling, not a gap).
- `dart:io` on web: `*Sync` does not exist on Flutter web —
  the candidate only fires where the names resolve syntactically
  (parse-only matching is textual; platform reachability is the
  author's problem, same as every type-name match in the suite).
- Re-entry: build the candidate through EDD; do NOT widen it to
  loops/decode without a profiler (that reverts this spike's
  core finding).

# 6. Contradictions Resolved

- Static vs dynamic perf (docs imply static detection of
  "heavy"): dynamic wins for heaviness — only blocking-ness
  (the I/O subset) is statically decidable, and only that
  subset survives as a candidate.
- Candidate built (2026-11-07): the `*Sync` subset landed as
  FG-SYNC-034 (TS-34) through the standard EDD loop — the
  fresh-ID rule from §2. The general-gate DROP above stands
  and FG-PERF-010 stays consumed.
