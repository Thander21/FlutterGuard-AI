---
spec_version: "openspec-1.0"
id: "FG-ST-001"
title: "Forbid controller instantiation inside build()"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodDeclaration[name='build']"
  - "InstanceCreationExpression"
  - "MethodInvocation[target=null]"
invariant: "No instance creation of a stateful controller type (AnimationController, FocusNode, PageController, ScrollController, TabController, TextEditingController) MUST appear lexically inside a method named 'build'; controllers MUST be created once in initState (or as state fields) and released in dispose()."
fp_limits:
  - "mere uses of a controller in build() (reads, arguments, method calls)"
  - "creations in initState, field initializers, helper methods, or dispose"
golden_vectors:
  failing: "benchmark/vectors/TC-03_controller.bad.dart"
  passing: "benchmark/vectors/TC-03_controller.good.dart"
auto_heal_strategy: "hoist_to_init_state"
---

# 1. Anti-Pattern Diagnosis

A controller built inside `build()` is reconstructed on every frame and never
disposed: the old instance leaks (listeners, tickers, focus attachments) while
the widget loses its state (scroll offset, text selection, animation value) on
each rebuild. AI-generated widgets routinely inline `TextEditingController()`
or `ScrollController()` in the widget tree because the happy path renders once
and never rebuilds.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
 class _SearchScreenState extends State<SearchScreen> {
+  late final TextEditingController _searchController;
+
+  @override
+  void initState() {
+    super.initState();
+    _searchController = TextEditingController();
+  }
+
+  @override
+  void dispose() {
+    _searchController.dispose();
+    super.dispose();
+  }
+
   @override
   Widget build(BuildContext context) {
-    final searchController = TextEditingController();
     return Column(
       children: [
-        TextField(controller: searchController),
+        TextField(controller: _searchController),
       ],
     );
   }
 }
```

# 3. Edge Cases and Non-Compliance

- Any method literally named `build` is scanned (no Widget check, no type
  resolution; parse-only like every v0 rule).
  [partial: only Widget build exercised in TC-03 pair]
- Containment is lexical: creations in direct statements of `build()` AND
  creations nested in the returned widget tree (e.g.
  `ListView(controller: ScrollController())`) are flagged, including creations
  inside closures nested in `build()` (hoisting to state remains the fix).
  [partial: creations inside closures unevaluated]
- Two syntactic forms count as constructions: explicit `new`/`const`
  (`InstanceCreationExpression`) and the modern bare call
  (`TextEditingController(...)`), which the parser leaves as a target-less
  `MethodInvocation` without type resolution.
  [partial: explicit new/const unevaluated]
- Matching is by name only (parse-only, no resolution): an unqualified call of
  a denylisted name in `build()` is treated as a construction. Prefixed
  (`ui.TextEditingController()`) or otherwise qualified forms: out of scope
  for v0, NOT flagged. [partial: prefixed forms unevaluated]
- Mere uses of a controller in `build()` (reads, passing it as an argument,
  method calls on it): MUST NOT be flagged. [eval: TC-03.good]
- Creations in `initState`, field initializers, helper methods, or `dispose`:
  MUST NOT be flagged. [partial: only initState exercised in TC-03.good]
- Closed v0 type list: `AnimationController`, `FocusNode`, `PageController`,
  `ScrollController`, `TabController`, `TextEditingController`.
  [partial: 2/6 types in TC-03 pair]
- Other disposables (`SearchController`, `TransformationController`,
  `StreamSubscription`, ...): out of scope for v0, NOT flagged. [unevaluated]

`hoist_to_init_state` is model-owned per the SYS-HEAL-001 closed
fast-path list (multi-hunk: field + initState + dispose + use); recipe
lookup by rule id per SYS-RECIPE-001.
