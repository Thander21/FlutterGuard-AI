---
spec_version: "openspec-1.0"
id: "FG-LAY-004"
title: "Forbid unbounded ListView directly inside Column"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "InstanceCreationExpression[type='Column']"
  - "MethodInvocation[name='Column',target=null]"
  - "NamedExpression[name='children']"
  - "ListLiteral / IfElement / ForElement / SpreadElement"
  - "InstanceCreationExpression[type='ListView']"
invariant: "A ListView creation MUST NOT appear as a direct child in a Column's 'children' list unless it sets 'shrinkWrap: true'; an unbounded list MUST be wrapped in Expanded/Flexible or given a bounded height."
fp_limits:
  - "ListViews wrapped in Expanded/Flexible/SizedBox (never descended into)"
  - "ListView(shrinkWrap: true)"
  - "ListViews outside any Column children list"
golden_vectors:
  failing: "benchmark/vectors/TC-07_lay.bad.dart"
  passing: "benchmark/vectors/TC-07_lay.good.dart"
auto_heal_strategy: "wrap_with_expanded"
---

# 1. Anti-Pattern Diagnosis

A `Column` passes unbounded height to its children. A `ListView` placed
directly in `children` therefore throws the classic
`Vertical viewport was given unbounded height` at runtime. AI-generated
screens routinely stack a header over a bare `ListView.builder` because
the preview renders once with few items and never overflows. The list
MUST be wrapped in `Expanded` (taking the remaining space) or declare
`shrinkWrap: true` (sizing to its content).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   Column(
     children: [
       const HeaderWidget(),
+      Expanded(
+        child: ListView.builder(
+          itemCount: 10,
+          itemBuilder: (context, index) => Text('Item $index'),
+        ),
-      ListView.builder(
-        itemCount: 10,
-        itemBuilder: (context, index) => Text('Item $index'),
       ),
+      ),
     ],
   )
```

# 3. Edge Cases and Non-Compliance

Detection is per-`Column`: the visitor finds every `Column` creation
(explicit or bare call) and walks its `children` argument, descending
through collection literals, `if`/`for` elements, spreads, and
conditionals — but never into other widget creations, so wrapped lists
stay clean and nested `Column`s are judged independently.

- `ListView.builder` as a direct child: MUST be flagged.
  [eval: TC-07.bad]
- Default `ListView` as a direct child: MUST be flagged.
  [eval: TC-07.bad]
- `Expanded`-wrapped list: MUST NOT be flagged. [eval: TC-07.good]
- `ListView(shrinkWrap: true)`: MUST NOT be flagged. [eval: TC-07.good]
- `ListView(shrinkWrap: false)`: MUST be flagged.
  [eval: unit fixture]
- `physics`-only lists (no `shrinkWrap`): MUST be flagged.
  [eval: unit fixture]
- Collection-`if` / spread / `for` elements hiding a list: MUST be
  flagged. [eval: unit fixture]
- Nested `Column`: the inner list is flagged once, the outer `Column`
  is clean. [eval: unit fixture]
- `ListView.separated` / `.custom`: same named-constructor path.
  [partial: builder/default in TC-07.bad]
- Prefixed forms (`widgets.Column`, `widgets.ListView.builder`):
  matched by simple name. [unevaluated]
- Transparent wrappers (`Padding(child: ListView(…))`): still broken
  at runtime but NOT traced in v0 (known false negative).
  [unevaluated]
- `Row` + `ListView` (unbounded width): out of scope for v0.
  [unevaluated]
- `GridView` / `CustomScrollView` in `Column`: out of scope for v0.
  [unevaluated]
- `mainAxisSize: min` does not exempt (still unbounded).
  [unevaluated]

`wrap_with_expanded` is model-owned per the SYS-HEAL-001 closed
fast-path list (two-sided edit: insert the wrapper above plus close it
below); the harness never attempts it as a fast-path patch.
[unevaluated]
