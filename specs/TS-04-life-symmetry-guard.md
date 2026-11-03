---
spec_version: "openspec-1.0"
id: "FG-LIFE-001"
title: "Resource symmetry: releasable fields released in dispose()"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "FieldDeclaration"
  - "AssignmentExpression"
  - "MethodInvocation[name='cancel'|'dispose'|'addListener'|'removeListener']"
invariant: "Every class field holding a releasable resource (subscription, timer, controller, focus node, or listener registration) MUST have its matching release call in a method named 'dispose' of the same class."
fp_limits:
  - "resources released only in deactivate() (dispose-only rule)"
  - "composite subscriptions (CompositeSubscription.add)"
  - "delegated ownership (released outside dispose() by an owner)"
  - "addListener/removeListener pairing is name-based; anonymous closures unevaluated"
golden_vectors:
  failing: "benchmark/vectors/TC-04_life.bad.dart"
  passing: "benchmark/vectors/TC-04_life.good.dart"
auto_heal_strategy: "insert_dispose_release"
---

# 1. Anti-Pattern Diagnosis

A `StreamSubscription` field that is never cancelled keeps its stream (HTTP
polling, sensors, WebSockets) alive after the widget is gone; a `Timer` that
is never cancelled fires into a dead `State` and crashes on `setState()`;
controllers and focus nodes leak tickers, listeners, and attachments.
AI-generated `State` classes routinely acquire these in `initState` (or at
declaration) and forget the symmetric release because the happy path never
pops the route.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
 class _SensorState extends State<Sensor> {
   late final StreamSubscription _sub;

   @override
   void initState() {
     super.initState();
     _sub = _sensor.stream.listen(_onData);
   }
+
+  @override
+  void dispose() {
+    _sub.cancel();
+    super.dispose();
+  }
 }
```

# 3. Edge Cases and Non-Compliance

Per-type release table (parse-only per-class field map; explicit field type
wins, initializer/assignment shape infers the rest):

| Field type | Acquire (declared or inferred) | Release in `dispose()` |
|---|---|---|
| `StreamSubscription` | declared, or `= …listen(` | `f.cancel()` / `f?.cancel()` |
| `Timer` | declared, or `= Timer…(` | `f.cancel()` / `f?.cancel()` |
| `AnimationController`, `TextEditingController`, `ScrollController`, `PageController`, `TabController` | declared, or `= Name(` | `f.dispose()` / `f?.dispose()` |
| `FocusNode` | declared, or `= FocusNode(` | `f.dispose()` / `f?.dispose()` |
| Listener | `field.addListener(named)` | `field.removeListener(named)` (same receiver + same argument source) |

- `listen()`-assigned fields without an explicit type are inferred
  `StreamSubscription` and flagged when uncancelled. [eval: TC-04.bad]
- `Timer`/`Timer.periodic`, including `initState` assignment, is flagged
  when uncancelled (Timer Leak Slicer). [eval: TC-04.bad]
- Controllers and `FocusNode` fields are flagged when undisposed.
  [eval: TC-04.bad]
- `addListener` with a named handler and no matching `removeListener` in
  `dispose()` is flagged at the `addListener` line. [eval: TC-04.bad]
- `removeListener` with a different argument source than `addListener`
  does NOT pair → still flagged. [eval: TC-04.bad]
- Releases only in `deactivate()` are still flagged (dispose-only rule).
  [eval: TC-04.bad]
- `?.`-conditional and `this.`-qualified release calls count as releases.
  [eval: TC-04.good]
- Fully released fields: MUST NOT be flagged. [eval: TC-04.good]
- Method-local acquisitions (not fields): out of scope here — MUST NOT be
  flagged (ST-001 owns locals-in-`build`). [eval: TC-04.good]
- `addListener` with an anonymous closure: NOT evaluated (skipped).
  [unevaluated]
- `CompositeSubscription.add`: NOT traced (skipped). [unevaluated]
- Delegated ownership (released in `close()` or by an owner widget):
  flagged — cross-file ownership is invisible parse-only (known FP).
  [unevaluated]

`insert_dispose_release` is model-owned per the SYS-HEAL-001 closed
fast-path list (the release call varies per resource type and `dispose()`
may need creating; the violation line is not the patch anchor); recipe
lookup by rule id per SYS-RECIPE-001.
