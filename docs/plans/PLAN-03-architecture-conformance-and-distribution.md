---
plan_version: "1.0"
id: "PLAN-03"
title: "Architecture conformance and distribution"
status: "proposed"
source_docs:
  - "docs/_origem/Architecture.md"
  - "docs/_origem/FormalVerificationAlgorithms.md"
  - "docs/Methodology/ForceFieldHarness.md"
  - "docs/plans/PLAN-01-implementation-to-submission.md"
  - "docs/plans/PLAN-02-functional-scope-to-working-system.md"
---

# PLAN-03: Architecture Conformance and Distribution

## Goal

Reconcile docs, plans, and rule specs with the implemented reality (three
AST rules, validated EDD loop), and record the decided direction for
self-validation (dogfood) and distribution (install/MCP) without building
either yet. Implementation is frozen at FG-ST-001; this plan is docs,
plans, and specs only.

## Success Criteria

- Scope notes and lifecycle bullets cite 3 rules with correct IDs, in
  English and Portuguese.
- Every normative §3 bullet of all three rule specs carries a coverage tag
  (`eval` / `partial` / `unevaluated`); `analysis: parse-only` is present
  in specs and template (PLAN-02 requirement).
- PLAN-01/02 reflect FG-ST-001 done, the hook running `check` (not
  `grade`), and this plan registered as PLAN-03.
- No edits under `lib/`, `bin/`, `test/`; `evidence.jsonl` untouched;
  suite stays 9/9.

## Approach

Docs follow verified code (PLAN-01 precedent: docs as starting point, not
truth). Reconciliation keeps the Architecture doc's single-package layout,
MCP target, distribution options, evidence schema, and gate ladder; adds
the grade-vs-check doctrine (`grade` = repo-local dev-loop, `check` =
portable gate), the read-only shipped-gates principle with an explicit
pollution budget (zero tracked files in the target by default), and a
scope-note maintenance rule (every new rule updates the notes). Doc rot
fixed: MCP config snippet, `.flutterguard/` + agent-file injection made
opt-in, `sandbox reset` reference, stale "2 rules" notes.

Decisions: D0 implementation frozen, docs-only; D5 docs follow verified
code (applied to the PLAN-02 prescribed visitor filename); D1–D4 recorded
under Deferred.

## Steps

### D0 — Read-only re-verify (no `grade`)

`dart test` (9/9 expected) + `dart analyze lib bin test` (clean). `grade`
does not run: it would append to `evidence.jsonl` and dirty the tree
pre-publish; grade state is cited as last-verified.

### D1 — Architecture.md

Scope note (3 rules + grade/check doctrine line), `FG-ST-001` ID on the
lifecycle bullet, corrected MCP snippet (`flutterguard_mcp` global exe),
opt-in flags + pollution-budget note for `.flutterguard/` and agent-file
injection, §7-C commands fixed.

### D2 — README/LEIAME

Scope notes 2→3 rules, mirrored in both languages. Install stays
[PLANNED] (packaging deferred); URL placeholders kept (release gate).

### D3 — Specs

`analysis: parse-only` front-matter on TS-01/02/03 + template
(grader-safe: the parser only reads `id`/`kind`/`failing`/`passing`); §3
coverage tags on every normative bullet; tagging convention added to the
template.

### D4 — Plans

This file; PLAN-01 (ST-001 done, hook `grade`→`check`, `dart install`
note); PLAN-02 (TS-03/TC-03 verified, next numbers TS-04/TC-04, ST-001
done with implemented filename, Step 0/prerequisites refresh, FORMAL
disposition line). Phase structures, P1–P3 backlog, and non-goals
untouched.

## Validation Plan

- Read-only gates: `dart test` 9/9 (unchanged count proves zero behavior
  drift) + analyzer clean; `git status` shows only intended files and
  `evidence.jsonl` keeps its pre-existing state.
- Front-matter safety: diff shows only the additive `analysis:` key plus
  §3 prose; `id`/`kind`/`failing`/`passing` untouched.
- Cross-check: every cited spec ID/section resolves; README/LEIAME in
  sync; LEIAME accents intact after edit.
- Final diff review per unit (D1–D4 separable for sliced publishing).

## Deferred (decided, not scheduled)

Packaging first via `dart install <Git URL>` (D1; recommended per
dart.dev, `pub global` legacy; SDK ships 3.13.7, needs 3.10+),
`pub global activate --source git` fallback for older SDKs. Rejected:
MCP-first (bigger chunk, needs protocol spike; exe unblocks install+hook
now) and copying a file block into the target (version drift, pollutes
the tree — the bundle lives in the Dart global cache, not in the
project).

- U1 dogfood L0 tests (D2): self-check (`check` over `lib`/`bin`/`test`
  exits 0, vectors excluded by design) + non-pollution properties
  (read-only tree hash, CWD independence). Meta-rules (FG-META) later via
  the same EDD loop.
- U2 `executables` + install proof: stanza, then install from the
  checkout and prove `flutterguard check` from a foreign directory.
- D3 validation: property tests now; full install-e2e manual once,
  automation after push.
- D4: `grade` never distributed; install docs cover `check` only.
- Open (R3): recipe pointers outside the checkout — repo-relative paths
  don't resolve once installed. Decide before MCP, which
  `get_canonical_recipe` depends on. Options: `rule` command, embedded
  specs, published URLs.
- Non-goals carried: MCP implementation, protocol spike, CI, threshold
  calibration, multi-vector evals, P1–P3 backlog changes.

## Risks

- R4 active: FG-ST-001 verified but uncommitted; docs pile onto it.
  Publish FG-ST-001 first as a separate unit (explicit direction
  required), docs second; boundaries are clean by construction (this plan
  touches only docs/plans/specs/README/LEIAME).
- R1/R2 dormant (no install step here); R3 open (see Deferred).
- Open questions: none.
