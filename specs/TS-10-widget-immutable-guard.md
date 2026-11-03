---
spec_version: "openspec-1.0"
id: "FG-WID-008"
title: "Forbid mutable fields in StatelessWidget"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "ClassDeclaration[superclass='StatelessWidget'|'ConsumerWidget']"
  - "FieldDeclaration[isFinal=false]"
invariant: "Every instance field of a class extending StatelessWidget or ConsumerWidget MUST be final."
fp_limits:
  - "final and late-final fields"
  - "static fields (not part of the widget instance)"
  - "fields in any other class, including StatefulWidget and State"
golden_vectors:
  failing: "benchmark/vectors/TC-10_wid.bad.dart"
  passing: "benchmark/vectors/TC-10_wid.good.dart"
auto_heal_strategy: "add_final_modifier"
---

# 1. Anti-Pattern Diagnosis

Flutter rebuilds stateless widgets by discarding and recreating them: a
mutable instance field (`int count`) silently resets on every rebuild
while the framework assumes the configuration is immutable, producing
UI state that flickers or never updates. AI-generated widgets routinely
declare `var` fields because a single-frame preview never rebuilds.
Stateless configuration MUST be `final` (`ConsumerWidget` carries the
same contract); anything mutable belongs in a `State` object.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   class CounterLabel extends StatelessWidget {
-    CounterLabel({super.key, required this.count});
+    const CounterLabel({super.key, required this.count});

-    int count;
+    final int count;

     @override
     Widget build(BuildContext context) {
       return Text('count: $count');
     }
   }
```

# 3. Edge Cases and Non-Compliance

Scope is the direct superclass name (`StatelessWidget`,
`ConsumerWidget`), matched unqualified or prefixed; each non-final
instance variable is flagged at its own name.

- Non-final typed field: MUST be flagged. [eval: TC-10.bad]
- `var` field: MUST be flagged. [eval: TC-10.bad]
- `final` field: MUST NOT be flagged. [eval: TC-10.good]
- `static` mutable field: MUST NOT be flagged (not an instance field).
  [eval: TC-10.good]
- `var` field in a `ConsumerWidget`: MUST be flagged.
  [eval: unit fixture]
- `var` field in a `StatefulWidget`: MUST NOT be flagged (the rule is
  stateless-scoped). [eval: unit fixture]
- `late final`: MUST NOT be flagged; `late` non-final: MUST be
  flagged. [eval: unit fixture]
- `var` field in a plain class: MUST NOT be flagged. [eval: unit fixture]
- Several variables in one declaration: each non-final one flagged.
  [unevaluated]
- Setters (`set count(v)`): NOT tracked. [unevaluated]
- Abstract/external fields: flagged like any non-final field.
  [unevaluated]
- `HookWidget` / `HookConsumerWidget`: out of scope for v0.
  [unevaluated]
- Mixins on `StatelessWidget`: NOT tracked. [unevaluated]

`add_final_modifier` is model-owned per the SYS-HEAL-001 closed
fast-path list (adding `final` can break constructor-body
initialization patterns the harness cannot verify); the harness never
attempts it as a fast-path patch. [unevaluated]
