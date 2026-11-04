---
spec_version: "openspec-1.0"
id: "SYS-PROF-001"
title: "Rebuild-counter API spike (dropped generic gate)"
status: "dropped"
kind: "system"
---

# 1. Problem

A rebuild-budget gate needs a real per-Element rebuild counter:
which API counts rebuilds, where the counting points are, and what
budget a flow must meet. This spike ran before any profiler spec
(PLAN-02): it verifies the API question against the Flutter SDK
(3.47.9) and drops the GENERIC gate with reason — the mechanism
is real, but per-flow budgets are app-specific and uncalibratable
here.

# 2. Interface / Schema

Spike findings (verified in SDK source):

## Counting API: VERIFIED (better than expected)

`debugOnRebuildDirtyWidget` (`widgets/debug.dart`) is a real
callback API — `void Function(Element e, bool builtOnce)` —
invoked for every dirty widget built each frame (`framework.dart`
`Element.rebuild`, inside `assert`, hence active in widget
tests). Counting points: the callback itself, keyed by Element
identity (per-Element) or `widget.runtimeType` (per-type).
Precedent: `WidgetInspectorService` aggregates rebuild stats
through this same callback
(`ext.flutter.inspector.trackRebuildDirtyWidgets`). No print
scraping needed. Companions: `debugPrintRebuildDirtyWidgets`
(console log of the same events), `debugProfileBuildsEnabled`
(DevTools timeline instead of console).

## Per-flow limits: UNDEFINABLE generically — gate DROPPED

A budget needs flows ("tapping checkout rebuilds ≤ N widgets"),
and flows are app screens + interactions — no generic flow set
exists. Candidate generic budgets all fail the calibration bar
(REVIEW-01 §3.9): same-Element rebuild caps FP on animation tests
(60fps rebuilds are expected); per-pump totals depend on screen
size. This repo has 2 fixture widgets — no corpus to calibrate
against. Any number would be an uncalibrated guess behind a
blocking gate: barred.

## Re-entry shape (app-specific adoption, not a gate)

An app defines its flows; a test helper sets
`debugOnRebuildDirtyWidget`, pumps the flow, asserts its own
budgets. Proposed evidence keys IF a future SYS-PROF-002 gate
exists (none emitted today; TELE amendment required first):
`phase` = `REBUILD_GATE`, `rule_id` = `SYS-PROF-002`,
`file` = `<test>:<flow>`, `status` = FAILED on over-budget flow,
`error_message` = `<type> rebuilt <n>× (budget <k>)`.

# 3. File Placement

- `specs/system/SPIKE-PROF-001-rebuild-counter.md` (this record;
  `SPIKE-` prefix marks research records, never contracts).
- No `lib/`, `bin/`, or `test/` files: a dropped spike ships no
  code. Validation is this record (API citations checkable in the
  pinned SDK).

# 4. Evidence Wiring

Emits no `evidence.jsonl`: no gate runs. Proposed keys live in §2
only.

# 5. Errors and Edges

- Debug-only APIs (`assert`-gated): counting works in widget
  tests, never in release — correct for a test gate, useless
  for production telemetry. No confusion between the two.
- `builtOnce` distinguishes mount builds from rebuilds: budgets
  count rebuilds (`builtOnce == true`), mounts are free.
- Re-entry needs a widget-test corpus with labeled flows before
  any generic number is proposed — same calibration bar as
  SYS-CAL-001, applied to flows.
- No ID is consumed beyond SYS-PROF-001 itself: SYS-PROF-002
  stays reserved for the future gate (unminted).

# 6. Contradictions Resolved

- Profiler vs static gates (docs assume per-Element budgets):
  the static side wins the argument — rebuild budgets are
  dynamic, app-specific, and corpus-gated; no static proxy
  (including FORMAL-003's waste-index, dropped in
  SYS-FORMAL-001) substitutes for measured rebuilds.
