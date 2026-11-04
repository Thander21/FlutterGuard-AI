---
spec_version: "openspec-1.0"
id: "FG-SYN-017"
title: "Sources must parse without syntactic errors"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(parser diagnostics: no AST node; ParseStringResult.errors)"
invariant: "Every scanned file parses with zero syntactic errors."
fp_limits:
  - "resolved-analysis diagnostics (unused imports, override mismatches) are never reported: the oracle is syntactic errors only"
  - "files with zero parse errors are never flagged, including files flagged by other rules (the syntax verdict is independent)"
golden_vectors:
  failing: "benchmark/vectors/TC-17_syn.bad.dart"
  passing: "benchmark/vectors/TC-17_syn.good.dart"
auto_heal_strategy: "repair_syntax"
---

# 1. Anti-Pattern Diagnosis

AI generators occasionally emit unbalanced delimiters, truncated
statements, or malformed declarations. Before this rule, `check`
collected such files in report-only `errors` (SYS-CLI-001a §5) and
the gate stayed green — a fail-open hole in `validate-light`: a
file no tool can parse passed the lightest gate. This rule closes
it: syntactic errors become error-severity findings (the gate
fails), while genuinely unreadable files (I/O failures, analyzer
crashes) stay report-only per the amended §5. The oracle is the
parser's own error list — never invented, never resolved.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   void main() {
-    var greeting = ;
+    var greeting = 'hello';
     print(greeting);
   }
```

# 3. Edge Cases and Non-Compliance

- A file with one syntactic error: MUST be flagged at the error's
  line. [eval: TC-17.bad]
- A file with several syntactic errors: MUST flag each error once
  at its own offset (no cascading duplicates, no abort after the
  first). [eval: unit fixture]
- Clean files: MUST NOT be flagged. [eval: TC-17.good]
- Semantic-only diagnostics (unused import, non-overriding
  `@override`): MUST NOT be flagged — `parseString` reports
  syntactic errors only, so resolved warnings can never appear.
  [eval: unit fixture]
- Files flagged by other rules with zero parse errors: MUST NOT
  gain a syntax finding (verdicts are independent).
  [eval: TC-17.good]
- Unreadable files (I/O failure) and analyzer crashes: MUST stay
  report-only `errors`, never findings (SYS-CLI-001a §5).
  [unevaluated]

`repair_syntax` is model-owned per the SYS-HEAL-001 closed
fast-path list (repair needs judgment: complete, rebalance, or
revert); the harness never attempts it as a fast-path patch.
[unevaluated]
