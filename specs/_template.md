---
spec_version: "openspec-1.0"
id: "FG-XXX-000"
title: "Short rule title"
status: "draft"
severity: "error"
ast_nodes:
  - "MethodInvocation[name='example']"
invariant: "State the inviolable AST invariant in one sentence."
golden_vectors:
  failing: "benchmark/vectors/TC-00_slug.bad.dart"
  passing: "benchmark/vectors/TC-00_slug.good.dart"
auto_heal_strategy: "insert_before_invocation"
---

# 1. Anti-Pattern Diagnosis

Describe the bug this rule prevents: what the AI-generated code does wrong,
why it is harmful, and where it typically appears.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
- violating line
+ healed line
```

# 3. Edge Cases and Non-Compliance

- List borderline constructs the visitor must handle.
- List constructs that must NOT be flagged.
