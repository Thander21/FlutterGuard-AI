---
plan_version: "2.0"
id: "PLAN-03"
title: "Architecture conformance and distribution"
status: "proposed"
source_docs:
  - "docs/_origem/Architecture.md"
  - "docs/_origem/FormalVerificationAlgorithms.md"
  - "docs/_origem/ForceFieldHarness.md"
  - "docs/plans/PLAN-01-implementation-to-submission.md"
  - "docs/plans/PLAN-02-functional-scope-to-working-system.md"
---

# PLAN-03: Architecture Conformance and Distribution

## Goal

Reconcile docs, plans, and rule specs with the implemented reality (three
AST rules, validated EDD loop); land the conformance as docs-only units
(D0–D4); then build distribution (packaging, install proof, dogfood) after
P0, with the MCP server owned by SYS-MCP-001.

## Success Criteria

- Scope notes and lifecycle bullets cite 3 rules with correct IDs, in
  English and Portuguese.
- Every normative §3 bullet of all three rule specs carries a coverage tag
  (`eval` / `partial` / `unevaluated`); `analysis: parse-only` is present
  in specs and template (PLAN-02 requirement).
- PLAN-01/02 reflect FG-ST-001 done, the hook running `check` (not
  `grade`), and this plan registered as PLAN-03.
- No edits under `lib/`, `bin/`, `test/` in the docs units (D0–D4);
  `evidence.jsonl` untouched; suite stays 9/9.
- Distribution build scheduled after P0: `dart install <git URL>` works,
  `flutterguard check` runs from a foreign directory, dogfood L0 is green.

## Approach

Docs follow verified code (PLAN-01 precedent: docs as starting point, not
truth). Reconciliation keeps the Architecture doc's single-package layout,
MCP target, distribution options, evidence schema, and gate ladder; records
the grade-vs-check doctrine (`grade` = repo-local dev-loop, `check` =
portable gate), the read-only shipped-gates principle with an explicit
pollution budget (zero tracked files in the target by default), and a
scope-note maintenance rule (every new rule updates the notes) in
working-tree-owned docs (README/LEIAME, specs) — `docs/_origem/` is frozen
per `AGENTS.md` and is never edited. Doc rot fixed: MCP config snippet,
`.flutterguard/` + agent-file injection made opt-in, `sandbox reset`
reference, stale "2 rules" notes.

Decisions: D0 conformance-first (docs-only units D0–D4), distribution
build scheduled after P0; D5 docs follow verified code (applied to the
PLAN-02 prescribed visitor filename).

## Steps

### D0 — Read-only re-verify (no `grade`)

`dart test` (9/9 expected) + `dart analyze lib bin test` (clean). `grade`
does not run: it would append to `evidence.jsonl` and dirty the tree
pre-publish; grade state is cited as last-verified.

### D1 — Conformance notes (frozen-archive safe)

`docs/_origem/Architecture.md` is frozen per `AGENTS.md`: no edits there.
Its reconciliation content lands in working-tree-owned docs instead: scope
note (3 rules + grade/check doctrine line), corrected MCP snippet
(`flutterguard_mcp` global exe), opt-in flags + pollution-budget note for
`.flutterguard/` and agent-file injection, and fixed §7-C install commands
all go to README/LEIAME (D2). The `FG-ST-001` lifecycle ID is already
normative in `specs/TS-03-controller-in-build-guard.md` (no change needed).

### D2 — README/LEIAME

Scope notes 2→3 rules + grade/check doctrine line, mirrored in both
languages; corrected MCP snippet, opt-in flags + pollution-budget note,
and fixed §7-C install commands folded in from D1. Install stays
[PLANNED] (packaging deferred); URL placeholders kept (release gate).

### D3 — Specs

`analysis: parse-only` front-matter on TS-01/02/03 + template
(grader-safe: the parser only reads `id`/`kind`/`failing`/`passing`); §3
coverage tags on every normative bullet; tagging convention added to the
template.

### D4 — Plans

This file; PLAN-01 v2.0 (production reframe, hackathon scope dropped);
PLAN-02 v3.0 (TS-03/TC-03 verified, next numbers TS-04/TC-04, ST-001 done
with implemented filename, Step 0/prerequisites refresh, FORMAL
disposition line, P2/P3 promoted to build). Phase structures, backlog, and
non-goals reframed for production use — nothing untouched by design.

## Validation Plan

- Read-only gates: `dart test` 9/9 (unchanged count proves zero behavior
  drift) + analyzer clean; `git status` shows only intended files and
  `evidence.jsonl` keeps its pre-existing state.
- Front-matter safety: diff shows only the additive `analysis:` key plus
  §3 prose; `id`/`kind`/`failing`/`passing` untouched.
- Cross-check: every cited spec ID/section resolves; README/LEIAME in
  sync; LEIAME accents intact after edit.
- Final diff review per unit (D1–D4 separable for sliced publishing).

## Distribution build (scheduled after P0)

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
- Non-goals carried: protocol spike beyond SYS-MCP-001's contract, CI,
  multi-vector evals, P1–P3 backlog changes. MCP implementation is
  scheduled (SYS-MCP-001); threshold calibration is scheduled (SYS-CAL-001
  after P1).

## Risks

- R4 retired: FG-ST-001 committed (`143ca7f`); conformance lands as
  separate docs units, distribution as separate code units. Docs units
  touch only docs/plans/specs/README/LEIAME; distribution units touch
  pubspec/bin/install scripts.
- R1/R2 scheduled with the distribution build; R3 open (see above).
- Open questions: none.
