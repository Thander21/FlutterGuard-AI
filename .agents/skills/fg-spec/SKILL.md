---
name: fg-spec
description: Author a FlutterGuard rule spec (TS-NN) from an anti-pattern. Use when a new AST rule is needed, before vectors or visitor exist.
---

# fg-spec — Rule Spec Authoring (`*spec`)

Writes the normative rule contract. No MCP tools (pure authoring);
row 1 of the SYS-MCP-001 chat-skills table.

## Inputs

- Rule id (`FG-XXX-NNN`, next free number).
- Anti-pattern: what the agent does wrong, and the production incident
  it causes.
- AST nodes involved, invariant in one sentence, false-positive limits,
  auto-heal strategy (`insert_before_invocation` |
  `replace_invocation` | model-owned).

## Steps

1. Copy `specs/_template.md` to `specs/TS-NN-<slug>.md` (next `TS`
   number; never reuse).
2. Fill front-matter: `id`, `severity`, `analysis` (`parse-only` |
   `resolved` — default `parse-only`), `ast_nodes`, `invariant`,
   `fp_limits`, `golden_vectors` (`failing`/`passing` paths),
   `auto_heal_strategy`.
3. §1: anti-pattern diagnosis (why AI code triggers it).
4. §2: Canonical Auto-Heal Recipe with a Before/After `diff` fence
   containing a changed line — exactly the template heading.
5. §3: edge cases, every normative bullet tagged `eval` / `partial` /
   `unevaluated`.
6. English only (AGENTS.md docs policy). Do not invent scope the
   template does not ask for.

## Done criteria

- Spec file complete with exact template headings; front-matter
  parses (`id`/`failing`/`passing` present).
- Next skill: `fg-vector` (golden vectors for this spec).
