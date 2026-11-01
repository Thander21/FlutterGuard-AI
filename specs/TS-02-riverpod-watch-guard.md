---
spec_version: "openspec-1.0"
id: "FG-RIV-001"
title: "Forbid ref.watch inside Riverpod event callbacks"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[target='ref',name='watch']"
  - "FunctionExpression"
invariant: "Every 'ref.watch' call MUST appear outside an argument callback; inside a function expression passed directly as an argument the code MUST use 'ref.read' instead."
golden_vectors:
  failing: "benchmark/vectors/TC-02_riverpod.bad.dart"
  passing: "benchmark/vectors/TC-02_riverpod.good.dart"
auto_heal_strategy: "replace_invocation"
---

# 1. Anti-Pattern Diagnosis

Subscribing with `ref.watch` inside an event callback (`onPressed`, `onTap`,
or any anonymous handler) throws at runtime, because `watch` is only valid
during the synchronous widget build. AI-generated handlers routinely copy the
build-time read into the callback, where the correct call is `ref.read`.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
  onTap: () {
-   final current = ref.watch(counterProvider);
+   final current = ref.read(counterProvider);
    debugPrint('$current');
  },
```

# 3. Edge Cases and Non-Compliance

"Synchronous build path" means the body of `build()` outside any argument
callback.

- `ref.watch` directly in `build()`: MUST NOT be flagged. [eval: TC-02.good]
- `ref.read` anywhere, including callbacks: MUST NOT be flagged.
  [eval: TC-02.good]
- Nested closures inside a callback: still a callback, MUST be flagged.
  [unevaluated]
- Torn-off named handlers (`onTap: _handler`) and callbacks stored in
  variables: out of scope for v0, NOT flagged. [unevaluated]
- v0 limitation: any function expression passed directly as an argument
  counts as a callback, including non-event cases such as `.map(...)`
  (may false-positive). [unevaluated]

`auto_heal_strategy` is declarative in v0 (no code consumes it); its
semantics will be decided by a future heal-dispatcher spec.
