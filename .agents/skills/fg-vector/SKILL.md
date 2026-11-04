---
name: fg-vector
description: Author golden eval vectors (.bad/.good pair) for a rule spec. Use after fg-spec, before the visitor exists.
---

# fg-vector — Golden Vector Authoring (`*vector`)

Writes the read-only golden evals the grader runs. No MCP tools (pure
authoring); row 2 of the SYS-MCP-001 chat-skills table.

## Inputs

- Rule spec `specs/TS-NN-*.md` (invariant + `fp_limits` drive the
  `.good` near-misses).

## Steps

1. Write `benchmark/vectors/TC-NN_<slug>.bad.dart`: the smallest code
   that violates the invariant. It MUST be flagged (a `.bad` that
   stays clean is a broken fixture).
2. Write `benchmark/vectors/TC-NN_<slug>.good.dart`: the fixed code
   PLUS one near-miss per `fp_limits` row (code that looks guilty but
   must stay clean). It MUST stay clean (zero false positives).
3. Keep vectors dependency-free (parse-only analysis, no package
   imports beyond what the pattern needs).
4. Never edit vectors to satisfy a visitor — vectors are the oracle;
   the visitor adapts to them.

## Done criteria

- Pair exists at the exact `failing`/`passing` paths declared in the
  spec front-matter.
- Next skill: `fg-visitor` (RED test + visitor against this pair).
