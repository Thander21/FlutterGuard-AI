---
name: fg-visitor
description: Implement a rule visitor (RED test + RecursiveAstVisitor + registry entry). Use after fg-vector, when the golden pair exists.
---

# fg-visitor — Visitor Implementation (`*visitor`)

Turns the spec + vectors into a green gate. Row 3 of the SYS-MCP-001
chat-skills table.

## Inputs

- Rule spec `specs/TS-NN-*.md` + golden pair `benchmark/vectors/TC-NN_*`.

## Steps

1. RED: write `test/<guard>_test.dart` asserting the `.bad` vector is
   flagged (exact lines), the `.good` twin is clean, and unit
   edge-cases from §3. Watch it fail.
2. GREEN: implement `lib/src/ast/<guard>.dart` as a
   `RecursiveAstVisitor` honoring the spec's `analysis` choice
   (`parse-only`: `parseString`, no element model). Tolerance:
   partial ASTs still report valid sites.
3. Register one entry in `lib/src/cli/rules.dart` (`id` + `spec` +
   `analyze` + `severity`).
4. Verify: MCP `analyze_ast` on both vectors (or CLI fallback:
   `dart test test/<guard>_test.dart` + `check` on the pair).
5. `dart analyze lib bin test` clean; findings carry the spec §2
   recipe pointer (SYS-RECIPE-001).

## MCP tools / CLI fallback

- MCP: `analyze_ast` (verify on vectors).
- CLI: `dart test`, `check`.

## Done criteria

- Unit test green, `.bad` flagged / `.good` clean through the
  registry, analyzer clean.
- Next skill: `fg-grade` (eval + evidence).
