---
spec_version: "openspec-1.0"
id: "FG-MET-007"
title: "Advisory widget complexity budgets (depth, params)"
status: "approved"
severity: "warning"
analysis: "parse-only"
ast_nodes:
  - "MethodDeclaration[name='build']"
  - "InstanceCreationExpression"
  - "MethodInvocation[constructor-shaped]"
  - "ConstructorDeclaration"
invariant: "Widget trees SHOULD nest at most 5 creation levels deep and constructors SHOULD declare at most 7 parameters; over-budget findings are advisory warnings until SYS-CAL-001 calibrates the thresholds."
fp_limits:
  - "trees nested 5 deep or less"
  - "constructors with 7 parameters or fewer"
  - "deep trees outside build()/Widget-returning methods"
golden_vectors:
  failing: "benchmark/vectors/TC-13_met.bad.dart"
  passing: "benchmark/vectors/TC-13_met.good.dart"
auto_heal_strategy: "decompose_god_widget"
---

# 1. Anti-Pattern Diagnosis

A 9-level widget tree in one `build()` cannot be reviewed, tested, or
reused — and a 12-parameter constructor cannot be called correctly.
Both are god-widget symptoms: the fix is extraction (sub-widgets,
config objects). But 5 and 7 are uncalibrated guesses, so per
REVIEW-01 §3.9 blocking on them is barred: this rule ships ADVISORY.
`check` reports its findings with `severity: warning` and never fails
the gate on them; `grade` still evals the golden pair (a `FAILED` gate
status there means "advisory fired", not "blocked"). SYS-CAL-001 owns
the corpus that flips severity to `error`.

Scope is deliberately narrow: depth is measured only inside `build()`
methods and `Widget`-returning functions (where widget trees live);
every creation level counts (framework and custom alike); every
declared constructor parameter counts (including `super.key`, whatever
its type). Calibration may narrow both (key exclusion, primitive-only
params); until then the rule stays strict-but-advisory.

Spike record (Semantic Ratio 15%, PLAN-02 P1): DROPPED. No parse-only
node classifier separates business-rule nodes from UI-plumbing nodes —
formatting, mapping, navigation, and keys are all invocations by
shape, so any syntactic proxy flags idiomatic screens. Defining the
classifier needs resolved types plus a domain model at minimum.

# 2. Canonical Auto-Heal Recipe (Before / After)

Depth — extract the subtree:

```diff
   Widget build(BuildContext context) {
     return Column(
       children: [
-        Padding(
-          padding: const EdgeInsets.all(8),
-          child: CartSummary(cart),
-        ),
+        const CartSummaryCard(),
       ],
     );
   }
+
+class CartSummaryCard extends StatelessWidget {
+  const CartSummaryCard({super.key});
+  // …the extracted subtree, now shallow, tested, and reused…
+}
```

Params — group into a config object:

```diff
   const BigForm({
     super.key,
-    required this.name,
-    required this.email,
-    required this.street,
-    required this.city,
-    required this.zip,
-    required this.country,
+    required this.customer,
+    required this.address,
   });
```

# 3. Edge Cases and Non-Compliance

Depth counts creation ancestors (explicit or constructor-shaped calls;
method calls, properties, and closures are transparent) from each
creation up through its enclosing function; every creation deeper than
5 is flagged with its depth. Parameters count every declared formal
(including `super.key`); constructors past 7 are flagged at the name.

- 6-deep nesting: MUST be flagged (advisory). [eval: TC-13.bad]
- 9-parameter constructor: MUST be flagged (advisory). [eval: TC-13.bad]
- 5-deep nesting: MUST NOT be flagged. [eval: TC-13.good]
- 7-parameter constructor: MUST NOT be flagged. [eval: TC-13.good]
- Exactly-5 boundary with interleaved method calls: MUST NOT be
  flagged (calls are transparent). [eval: unit fixture]
- 7-parameter boundary: MUST NOT be flagged. [eval: unit fixture]
- 8-parameter constructor: MUST be flagged (advisory).
  [eval: unit fixture]
- Deep tree in a `List<Widget>` helper: MUST NOT be flagged
  (exact-`Widget` rule). [eval: unit fixture]
- Deep tree in a top-level `Widget` function: MUST be flagged
  (advisory). [eval: unit fixture]
- `super.key` counts as a parameter (calibration note).
  [eval: TC-13.bad]
- Non-primitive parameters count (origin said primitives;
  calibration may narrow). [eval: TC-13.bad]
- Deep trees in field initializers or constructors: skipped
  (build-scope). [unevaluated]
- Closures accumulate outer depth (the runtime tree is one tree).
  [unevaluated]
- Semantic Ratio 15%: DROPPED, no parse-only classifier (see §1).
  [unevaluated]

`decompose_god_widget` is model-owned per the SYS-HEAL-001 closed
fast-path list (extraction points and config shapes need judgment);
the harness never attempts it as a fast-path patch. [unevaluated]
