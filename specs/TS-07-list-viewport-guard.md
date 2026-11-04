---
spec_version: "openspec-1.0"
id: "FG-LAY-004"
title: "Forbid unbounded scrollables directly inside Column/Row"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "InstanceCreationExpression[type='Column|Row']"
  - "MethodInvocation[name='Column|Row',target=null]"
  - "NamedExpression[name='children']"
  - "ListLiteral / IfElement / ForElement / SpreadElement"
  - "InstanceCreationExpression[type='ListView|GridView|CustomScrollView']"
invariant: "A ListView, GridView, or CustomScrollView creation MUST NOT appear as a direct child in a Column's or Row's 'children' list; in Column, 'shrinkWrap: true' exempts (Row-axis ignores shrinkWrap — probed). An unbounded scrollable MUST be wrapped in Expanded/Flexible or given a bounded height/width."
fp_limits:
  - "Scrollables wrapped in Expanded/Flexible/SizedBox (never descended into)"
  - "Scrollable(shrinkWrap: true) in Column"
  - "Scrollables outside any Column/Row children list"
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

v2 (FORMAL-002 axes backlog) extends the same theorem to the Row
axis and the GridView/CustomScrollView widgets: a `Row` passes
unbounded width, so any scrollable directly in its `children`
throws the horizontal unbounded error; `GridView` and
`CustomScrollView` are viewports like `ListView` and throw
unbounded in `Column`. Runtime truth was probed on Flutter 3.47.9
(throwaway `viewport/test/zz_truth_probe_tmp.dart`, removed after
the probe): all six
flex×scrollable cells throw bare; `shrinkWrap: true` exempts only
in `Column` (all three Row+shrinkWrap shapes still throw);
`scrollDirection` is irrelevant (a horizontal list in `Column`
throws); `Expanded` fixes both axes.

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

Row axis — same fix, horizontal (v2):

```diff
   Row(
     children: [
-      ListView(
-        children: [Text('a')],
-      ),
+      Expanded(
+        child: ListView(
+          children: [Text('a')],
+        ),
+      ),
     ],
   )
```

# 3. Edge Cases and Non-Compliance

Detection is per-flex (`Column`/`Row`): the visitor finds every flex
creation (explicit or bare call) and walks its `children` argument,
descending through collection literals, `if`/`for` elements,
spreads, and conditionals — but never into other widget creations,
so wrapped scrollables stay clean and nested flexes are judged
independently.

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
- `Row` + `ListView` (unbounded width): MUST be flagged.
  [eval: TC-07.bad]
- `Row` + `ListView(shrinkWrap: true)`: MUST be flagged
  (Row-axis ignores `shrinkWrap` — probed). [eval: TC-07.bad]
- `GridView` in `Column`: MUST be flagged. [eval: TC-07.bad]
- `GridView(shrinkWrap: true)` in `Column`: MUST NOT be flagged.
  [eval: TC-07.good]
- `GridView` in `Row` (bare or `shrinkWrap` — Row-axis ignores
  it): MUST be flagged. [eval: TC-07.bad, unit fixture]
- `CustomScrollView` in `Column`: MUST be flagged.
  [eval: TC-07.bad]
- `CustomScrollView(shrinkWrap: true)` in `Column`: MUST NOT be
  flagged. [eval: TC-07.good]
- `CustomScrollView` in `Row` (bare or `shrinkWrap`): MUST be
  flagged. [eval: TC-07.bad, unit fixture]
- `Row` + `Expanded`-wrapped scrollable: MUST NOT be flagged.
  [eval: TC-07.good]
- `Flexible` / `SizedBox`-wrapped scrollables: MUST NOT be flagged
  (never descended into). [eval: TC-07.good]
- `scrollDirection` is ignored (a horizontal `ListView` in
  `Column` still throws — probed): MUST be flagged.
  [eval: unit fixture]
- `ListView.separated` / `.custom`: same named-constructor path.
  [eval: unit fixture]
- `GridView.builder` / `.count` / `.extent` / `.custom`: same
  named-constructor path. [eval: TC-07.bad, unit fixture]
- Prefixed forms (`widgets.Column`, `widgets.ListView.builder`):
  matched by simple name. [eval: unit fixture]
- Transparent wrappers (`Padding(child: ListView(…))`): still broken
  at runtime but NOT traced (known false negative; descent-through
  is future work beyond v2). [unevaluated]
- `mainAxisSize: min` does not exempt (still unbounded).
  [unevaluated]

`wrap_with_expanded` is model-owned per the SYS-HEAL-001 closed
fast-path list (two-sided edit: insert the wrapper above plus close it
below); the harness never attempts it as a fast-path patch.
[unevaluated]
