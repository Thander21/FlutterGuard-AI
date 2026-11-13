---
spec_version: "openspec-1.0"
id: "FG-YAGNI-001"
title: "Fake-abstraction (YAGNI) spike (dropped, no candidate)"
status: "dropped"
kind: "system"
---

# 1. Problem

The documented rule (`DisruptiveInnovations.md` Part 3 §3, "Fake
Abstraction Detector"): interfaces or abstract classes with exactly
1 concrete implementation project-wide and no polymorphic test
must be collapsed (forced simplification, YAGNI). PLAN-01/02
carried it as "deferred with reason" without ever spelling the
reason out. This spike runs the standard method
(trigger-precision against the parse-only ceiling +
remedy-proportionality, no code): it ends in a recorded DROP with
no surviving candidate — and records the reason the deferral
never had.

# 2. Interface / Schema

## The documented trigger, decomposed

Three conjuncts: (a) an abstraction (Dart: `abstract class`,
including `abstract interface` / `mixin class` spellings); (b)
exactly 1 implementation project-wide; (c) no polymorphic test.

- (a) is per-file detectable (`ClassDeclaration` with an
  abstract marker).
- (b) needs a project-wide implements/extends census: every
  file's clauses resolved against the abstraction's identity.
  Per-file registry visitors cannot do this (one file in,
  verdict out — `grade` evals single vectors), and bare name
  matching is unresolvable (same-name types across
  packages/prefixes collide). This is the same ceiling that
  deferred framework-mixing (dependency graph + cross-file
  census). A DRY-style root-walking detector could census
  name-occurrences — but DRY lives outside the registry
  precisely because project-wide properties cannot ride the
  per-file eval contract (`findDuplication` is called only by
  `tool/calibrate.dart` and tests, never by `check`/`grade`/MCP).
  A YAGNI census would inherit that non-eval status:
  corpus-judged advisory at best, never a graded rule.
- (c) "no polymorphic test" needs the test corpus: does any test
  exercise the abstraction through 2+ implementations (or a
  fake)? That is cross-directory (`lib` ↔ `test`) reference
  analysis plus a definition of "polymorphic exercise" no
  static trigger carries. Note the collapse: a mocktail `Mock`
  implements its subject, so tested seams trivially have 2+
  implementations — the conjunct reduces to "untested
  single-impl seam" (see the remedy section).

## Candidate subsets (all fail)

- Same-file single-impl (abstract + sole implementer + zero
  in-file annotation-use, all in one file): per-file checkable,
  but near-zero recall (real seams span domain/`data` files)
  and no evidence bar is reachable — N=0 on this repo's corpus
  (its sole abstraction, `RuleViolation`, has ~34
  implementations). Real instances are rare deliberate
  scaffolding, not smells worth a gate.
- Zero-annotation-use project-wide ("unused abstraction"): still
  needs the census; and unused ≠ premature (public API surface,
  plugin points, API boundaries).
- Dead abstraction (zero implementations): a different rule
  (dead code), not YAGNI — explicitly not claimed here.

## Remedy proportionality (the deeper failure)

The prescribed remedy — collapse the abstraction — is backwards
for the most common single-impl shape: the untested seam. A
single-impl interface with no test is fixed by ADDING the test
(whose fake becomes the legitimate second implementation), not
by deleting the seam testing needs. Beyond that, single-impl is
usually intentional (ports/adapters, plugin interfaces, API
boundaries, test seams) or transitional (second implementation
coming; TDD interface-first). Forcing multi-file collapse on
that trigger is high-churn and frequently wrong — the same
family as the FG-FSM-012 drop (weak trigger, remedy fights
idioms). A test-presence-flavored variant would duplicate
FG-TST-033's job (opt-in mirror rule, already built).

## Disposition: DROP, no candidate

Unlike PERF-010 (which kept a tight subset), no YAGNI subset
survives both the ceiling and the proportionality check. The
documented rule stays a design-review heuristic (human
judgment over intent context), not a gate.

# 3. File Placement

- `specs/system/SPIKE-YAGNI-001-fake-abstraction.md` (this
  record; `SPIKE-` prefix marks research records).
- No `lib/`, `bin/`, or `test/` files: a dropped spike ships no
  code. The FG-YAGNI-001 ID is consumed by this record — no
  future rule may take it (same rule as the SYS-FORMAL-001 and
  PERF-010 dropped IDs). PLAN-01/02's bare "FG-YAGNI" label now
  resolves to this consumed spike ID.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: no gate runs.

# 5. Errors and Edges

- The repo census above (`RuleViolation` + ~34 implementers) is
  regex-illustrated; the structural arguments (registry
  contract, eval inexpressibility, remedy direction) do not
  depend on it.
- Re-entry: a resolved-analysis engine with project-wide
  reference indexing could revisit the census half — but must
  still pass remedy-proportionality (the collapse remedy stays
  suspect) and the calibration bar (needs a corpus with real
  positives; this repo has N=0).
- `mocktail` interplay: Mock fakes implement their subject —
  any future census must classify test fakes as legitimate
  implementations, which reframes the trigger as "untested
  seam" (a testing gap, not an abstraction smell).
- Dead-abstraction (zero implementations) detection is
  explicitly not claimed here; a future turn may propose it as
  its own rule with its own trigger analysis.

# 6. Contradictions Resolved

- Deferred-with-reason (PLAN-01/02) vs buildable: the deferral
  stands, now with the actual reason recorded here (it was
  never spelled out).
- Human review vs gate (docs imply automatic detection): human
  review wins — single-impl judgment needs intent context
  (transitional? seam? public API?) that no static trigger
  carries.
