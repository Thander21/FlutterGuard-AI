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
  - "MethodInvocation[name='cancel'|'dispose'|'close'|'addListener'|'removeListener'|'onDispose']"
  - "CascadeExpression"
  - "ConstructorDeclaration"
invariant: "Every self-instantiated class field holding a releasable resource (subscription, timer, controller, focus node, or listener registration) MUST have its matching release call in a release method of the same class. A 'ref.onDispose(...)' registration counts as a release: closures run with dispose semantics, and 'resource.dispose'/'.cancel'/'.close' tear-offs release the receiver. Constructor-received fields are borrowed, never checked. Release methods are 'dispose' always, plus 'close'/'stop'/'cancel' outside 'State'/'Notifier' subclasses."
fp_limits:
  - "Riverpod onDispose-registered cleanup (counts as released)"
  - "resources released only in deactivate() (dispose-only rule)"
  - "composite subscriptions (CompositeSubscription.add)"
  - "delegated ownership (released outside dispose() by an owner)"
  - "addListener/removeListener pairing is name-based; anonymous closures unevaluated"
  - "constructor-received fields (borrowed, never self-instantiated)"
  - "`close()` releases (joins cancel/dispose everywhere)"
  - "releases in close()/stop()/cancel() of non-State/Notifier classes"
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
pops the route. Riverpod Notifiers have no `dispose()`; they register
cleanup with `ref.onDispose(...)`, which the guard honors as a release
(SYS-CAL-002 P1-2). Cascade registrations (`ref..onDispose(...)`)
and `close()` releases count the same (SYS-CAL-003 R2-3). Only
self-instantiated fields are checked: a controller received
through the constructor is borrowed, and services or workers
release in `stop()`/`close()` instead of `dispose()`.

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

A `f.close()` call counts as a release for every row
(SYS-CAL-003 R2-3).

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
- `ref.onDispose(() => f.dispose()/f.cancel())` closures and
  `ref.onDispose(f.dispose)` / `f.cancel` tear-offs count as
  releases in any method. [eval: TC-04.good]
- `ref.onDispose(() => field.removeListener(named))` pairs an
  `addListener` like a `dispose()` body. [eval: TC-04.good]
- Cascade `ref..onDispose(...)` counts exactly like the call
  form (closures and tear-offs). [eval: TC-04.good]
- `f.close()` in a release method counts as a release.
  [eval: TC-04.good]
- Constructor-received fields (`C(this.c)`, `C(c) : _c = c`,
  body `_c = param`): MUST NOT be flagged (borrowed).
  [eval: TC-04.good]
- `late` fields with a construction assignment are owned:
  flagged when unreleased. [eval: TC-04.bad]
- Opaque acquires with a declared type (`_sub = makeSub()`)
  still flag: only proven constructor-received is borrowed
  (fail-closed). [eval: unit fixture]
- Outside `State`/`Notifier` subclasses, releases in methods
  named `close`/`stop`/`cancel` count like `dispose()`.
  [eval: TC-04.good]
- `State` subclasses keep the dispose-only rule: releases
  only in `close()` still flag. [eval: unit fixture]
- Indirect `State`/`Notifier` subclasses get the extended
  set (direct-superclass names only — parse-only ceiling).
  [unevaluated]
- Fully released fields: MUST NOT be flagged. [eval: TC-04.good]
- Method-local acquisitions (not fields): out of scope here — MUST NOT be
  flagged (ST-001 owns locals-in-`build`). [eval: TC-04.good]
- `addListener` with an anonymous closure: NOT evaluated (skipped).
  [unevaluated]
- `CompositeSubscription.add`: NOT traced (skipped). [unevaluated]
- Cross-file ownership (released by an owner widget): flagged —
  invisible parse-only (known FP). [unevaluated]

`insert_dispose_release` is model-owned per the SYS-HEAL-001 closed
fast-path list (the release call varies per resource type and `dispose()`
may need creating; the violation line is not the patch anchor); recipe
lookup by rule id per SYS-RECIPE-001.
