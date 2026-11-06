---
spec_version: "openspec-1.0"
id: "FG-CC-025"
title: "Cyclomatic complexity ceiling"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(shared oracle: SYS-COV-001 analyzeComplexity over the file source)"
invariant: "Every named declaration with a body MUST have cyclomatic complexity at or below 80 (SYS-COV-001 counting)."
fp_limits:
  - "declarations at CC 80 or below"
  - "bodiless declarations (abstract/external)"
  - "closures and local functions (folded into the enclosing entry)"
golden_vectors:
  failing: "benchmark/vectors/TC-25_cc.bad.dart"
  passing: "benchmark/vectors/TC-25_cc.good.dart"
auto_heal_strategy: "split_function"
---

# 1. Anti-Pattern Diagnosis

A god-function with eighty branches is where velocity goes to
die: untestable paths, review-proof diffs, and bugs hiding
behind branch seventy-three. AI-generated handlers pile
branches because each prompt appends one more case. The
campodeforca `Complexity` gate (SYS-CAL-003 R2-5) fails above
80 anywhere; this rule is that line, reusing the trusted
SYS-COV-001 counter (closures and local functions fold their
branches into the enclosing entry; bodiless declarations are
unscored). The warn-above-20 half stays out of v1:
violation-level severity is unsupported (severity is
per-rule), and MET-007 owns advisories — a metrics-amendment
follow-up, not this gate.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   int classify(Order order) {
-    if (order.a) return 1;
-    // ... eighty more branches ...
+    return _classifyType(order) + _classifyRegion(order);
   }
```

# 3. Edge Cases and Non-Compliance

Scored entries are named declarations with bodies
(functions, methods, constructors); the finding lands on the
declaration line and names it with its CC. The ceiling is
fixed at 80 (no config); unit fixtures pin the boundary
through an injectable test ceiling.

- CC-86 function: MUST be flagged. [eval: TC-25.bad]
- CC-3 function: MUST NOT be flagged. [eval: TC-25.good]
- Declaration at the ceiling: MUST NOT be flagged;
  ceiling+1: MUST be flagged. [eval: unit fixture]
- Closure branches fold into the enclosing entry (outer
  CC counts them). [eval: unit fixture]
- Bodiless (abstract) declarations: MUST NOT be scored.
  [eval: unit fixture]
- Methods score as `Class.method`. [eval: unit fixture]
- Constructors are scored entries. [eval: unit fixture]
- Threshold config: none in v1 (fixed 80; the injectable
  ceiling is tests-only). [unevaluated]
- Warn-above-20: NOT in v1 (see §1). [unevaluated]

`split_function` is model-owned per the SYS-HEAL-001 closed
fast-path list (splitting needs semantic judgment — where
the seams are); the harness never attempts it as a fast-path
patch. [unevaluated]
