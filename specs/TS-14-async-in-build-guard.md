---
spec_version: "openspec-1.0"
id: "FG-BUILD-014"
title: "No fire-and-forget async work directly in build()"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[Future.*]"
  - "MethodInvocation[Timer]"
  - "MethodInvocation[then/catchError/whenComplete]"
  - "MethodInvocation[unawaited]"
  - "InstanceCreationExpression[socket types]"
invariant: "No Future-creating, Timer-starting, socket-opening, or future-chaining invocation may execute directly in a build() method or Widget-returning function body (closures excluded: event handlers are legitimately async)."
fp_limits:
  - "async event handlers (closures): onPressed () async {} is correct"
  - "Future.value (pure constructor, no scheduled work)"
  - "FutureBuilder/StreamBuilder (declarative widgets, not invocations)"
  - "ref.* reactive reads (framework idiom)"
  - "compute/scheduleMicrotask (the fix, not the bug / borderline excluded)"
  - "trigger invocations outside build()/Widget-returning functions"
golden_vectors:
  failing: "benchmark/vectors/TC-14_build.bad.dart"
  passing: "benchmark/vectors/TC-14_build.good.dart"
auto_heal_strategy: "extract_async_init"
---

# 1. Anti-Pattern Diagnosis

`build()` runs up to 60–120 times per second during animations and
gestures. A `Future.delayed`, `Timer`, `.then(` chain, or socket
open placed directly in its body fires on EVERY rebuild: API
storms, timer leaks (each rebuild starts another), and stale
callbacks racing the frame the user sees. AI generators emit this
shape because the happy path rebuilds once and looks fine.
Hoisting the work to `initState`, an event handler, or a
`FutureBuilder` fixes it once, structurally.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   Widget build(BuildContext context) {
-    Future.delayed(const Duration(seconds: 1), _refresh);
+    // Moved to initState: runs once, not per frame.
     return const StatusView();
   }
+
+  @override
+  void initState() {
+    super.initState();
+    Future.delayed(const Duration(seconds: 1), _refresh);
+  }
```

# 3. Edge Cases and Non-Compliance

Trigger set (directly in build scope — any nesting inside a
closure/function-expression exempts): `Future.<anything>` except
`Future.value`; `Timer(` / `Timer.periodic(`; socket allowlist
(`HttpClient`, `Socket`, `WebSocket` creations); `.then(`,
`.catchError(`, `.whenComplete(` chains; `unawaited(`.

- `Future.delayed` directly in `build()`: MUST be flagged.
  [eval: TC-14.bad]
- `.then(` chain directly in `build()`: MUST be flagged.
  [eval: TC-14.bad]
- `Timer.periodic` directly in `build()`: MUST be flagged.
  [eval: TC-14.bad]
- `Socket.connect` in `build()`: MUST be flagged.
  [eval: TC-14.bad]
- `unawaited(api.load())` in `build()`: MUST be flagged.
  [eval: unit fixture]
- Async `onPressed` handler: MUST NOT be flagged (closure).
  [eval: TC-14.good]
- `FutureBuilder` in `build()`: MUST NOT be flagged (declarative).
  [eval: TC-14.good]
- `Future.value` in `build()`: MUST NOT be flagged.
  [eval: TC-14.good]
- `ref.watch` / `ref.read` in `build()`: MUST NOT be flagged.
  [eval: TC-14.good]
- `compute()` in `build()`: MUST NOT be flagged.
  [eval: unit fixture]
- Trigger invocations in `initState()`: MUST NOT be flagged
  (build-scope only). [eval: TC-14.good]
- Deep `build()` trees in vectors: out of scope (vectors stay
  MET-neutral by design). [unevaluated]

`extract_async_init` is model-owned per the SYS-HEAL-001 closed
fast-path list (hoist targets need judgment: `initState` vs
handler vs `FutureBuilder`); the harness never attempts it as a
fast-path patch. [unevaluated]
