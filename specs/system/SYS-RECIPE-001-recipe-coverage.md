---
spec_version: "openspec-1.0"
id: "SYS-RECIPE-001"
title: "Recipe-per-rule coverage with rule-id lookup"
status: "approved"
kind: "system"
---

# 1. Problem

A flag without a fix teaches nothing: every rule the harness can raise
must carry the Before/After patch the agent applies, retrievable by the
same key the finding reports. Without that coverage contract, rules
land unhealable (detection without remedy) and consumers invent
ad-hoc recipe sources that drift from the specs.

# 2. Interface / Schema

Lookup key = rule id (`FG-XXX-NNN`). Resolution chain (pointer form,
no file I/O in the CLI today):

`finding.rule_id` → `ruleAnalyzers` entry → `spec` path → `§2 Canonical
Auto-Heal Recipe` → Before/After `diff` block.

Requirements:

- Every top-level rule spec (`specs/TS-*.md`) carries `§2 Canonical
  Auto-Heal Recipe` with exactly the template heading and at least one
  `diff` fence containing a changed line (`-` and/or `+`; insertion-only
  recipes legitimately lack `-`).
- Every `ruleAnalyzers` entry's `spec` file exists, and its
  front-matter `id` equals the entry id (lookup-key integrity).
- Every top-level rule spec has a registry entry (no orphan specs).
- `specs/_template.md` mandates the §2 section (new rules inherit it).
- `check` findings carry the resolved pointer (`spec`, `recipe`
  fields); heal/MCP consume the same pointer. Repo-relative pointer
  resolution stands until PLAN-03 R3 (installed distribution) decides
  between a `rule` command, embedded specs, or published URLs — no
  runtime spec file reader lands before that decision.

No new dependencies.

# 3. File Placement

- `specs/system/SYS-RECIPE-001-recipe-coverage.md` (this contract;
  the grader skips `specs/system/` non-recursively and `kind: system`
  explicitly).
- `test/recipe_coverage_test.dart` (contract test: registry↔spec↔§2
  join over every rule, plus the template mandate).
- Consumers (read-only): `lib/src/cli/rules.dart` (id→spec),
  `CheckFinding.recipe` (pointer rendering), `SYS-HEAL-001`
  (takes the recipe as input; lookup wiring is this contract).
- Methodology catalog `docs/_origem/CanonicalRecipesCatalog.md`:
  frozen reference (study only, never extended); live recipes live in
  each spec's §2. `MuseCode.md` injection already points at spec §2
  (conforming, no edit).

# 4. Evidence Wiring

This contract emits no `evidence.jsonl`. Coverage is enforced by the
contract test in the unit suite, not by a gate line.

# 5. Errors and Edges

- Rule spec without §2 (or without a Before/After diff): contract
  test fails, naming the spec — the rule is not done.
- Registry entry whose spec file is missing, or whose front-matter
  `id` differs: contract test fails (broken lookup key).
- Top-level spec without a registry entry: contract test fails
  (orphan spec — detectable but unrunnable, or runnable but
  ungraded).
- Strategy values (`auto_heal_strategy`) stay declarative:
  fast-path semantics live in SYS-HEAL-001 §2; anything else is
  model-owned per its closed list. This contract does not adjudicate
  strategy names, only recipe presence and lookup integrity.

# 6. Contradictions Resolved

- Recipe source of truth: each rule spec's §2 wins (live, graded);
  the methodology catalog is archived context (PLAN-02
  SYS-RECIPE-001; `docs/_origem/` frozen per AGENTS.md).
- Lookup shape: pointer-by-rule-id now (registry + finding fields);
  resolved-content lookup is PLAN-03 R3's deferred decision, not
  this contract's.
