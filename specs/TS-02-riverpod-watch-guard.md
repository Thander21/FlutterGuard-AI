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
  - "NamedArgument"
invariant: "Every 'ref.watch' call MUST appear outside an argument callback; inside a function expression passed directly as an argument the code MUST use 'ref.read' instead. A function expression that is the builder argument of a Riverpod provider factory is a build, not a callback. A builder-like named argument ('builder', 'itemBuilder', any '*Builder' except 'optionsBuilder') and an AsyncValue 'when'/'maybeWhen'/'whenOrNull'/'map'/'maybeMap' branch ('data'/'loading'/'error'/'orElse') are builds, not callbacks. A closure declaring its own 'ref' parameter shadows the outer one: enclosing callbacks stop counting inside it."
fp_limits:
  - "ref.watch directly in build()"
  - "ref.read anywhere, including callbacks"
  - "ref.watch inside provider builders (Provider, Factory(.autoDispose|.family)*, overrideWith)"
  - "ref.watch inside builder-like closures (`builder`, `itemBuilder`, `*Builder`)"
  - "ref.watch inside AsyncValue when/map branches"
  - "ref.watch on a closure's own `ref` parameter (Consumer builder inside a handler)"
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
Provider builders (`Provider((ref) => ...)`) take the same syntactic
shape as callbacks but run as builds; the guard excludes the
factory set (SYS-CAL-002 P1-1). Modifier chains
(`FutureProvider.autoDispose.family`) and widget `builder:`
closures (`Consumer`, `BlocBuilder`) take the same callback
shape but run as builds; the guard excludes both
(SYS-CAL-003 R2-3).

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
  [eval: unit fixture]
- Torn-off named handlers (`onTap: _handler`) and callbacks stored in
  variables: out of scope for v0, NOT flagged. [unevaluated]
- `ref.watch` in a provider builder (`Provider((ref) => ...)`,
  `X.family((ref, arg) => ...)`, `x.overrideWith((ref) => ...)`,
  plus any `Factory(.autoDispose|.family)*` modifier chain):
  MUST NOT be flagged — builders run as builds. Factory set:
  `Provider`, `FutureProvider`, `StreamProvider`,
  `StateProvider`, `NotifierProvider`, `AsyncNotifierProvider`,
  `StateNotifierProvider`, `ChangeNotifierProvider`
  (bare, prefixed, and explicit `new`/`const` spellings).
  [eval: TC-02.good]
- `ref.watch` in a `Consumer(builder: ...)` closure: MUST NOT
  be flagged — builders run at build time. [eval: TC-02.good]
- `ref.watch` in a `BlocBuilder(builder: ...)` closure: MUST
  NOT be flagged — same build-time doctrine.
  [eval: unit fixture]
- `listener:` closures (`BlocListener`, `BlocConsumer`) stay
  callbacks: MUST be flagged. [eval: TC-02.bad]
- `ConsumerWidget.build()` bodies: MUST NOT be flagged.
  [eval: TC-02.good]
- `HookConsumerWidget.build()` bodies: MUST NOT be flagged.
  [eval: unit fixture]
- Builder-like named arguments of any callee (`builder`,
  `itemBuilder`, any `*Builder`) are builds: MUST NOT be
  flagged at build level (K3; covers `BlocConsumer`/
  `BlocSelector` `builder:`). [eval: unit fixture]
- `optionsBuilder` (Autocomplete, runs on input) stays a
  callback. [unevaluated]
- A builder-like closure does not reset an enclosing
  callback: `onTap: () { showDialog(builder: (_) =>
  ref.watch(x)); }` MUST be flagged. [eval: TC-02.bad]
- AsyncValue branches (`x.when(data: …, loading: …, error:
  …)`, also `maybeWhen`/`whenOrNull`/`map`/`maybeMap`,
  `orElse`) run inside the build: MUST NOT be flagged
  (K3: `child:` of a button inside `when(data:)`).
  [eval: TC-02.good, unit fixture]
- A closure declaring its own `ref` parameter (`Consumer(
  builder: (context, ref, _) {…})`) shadows the outer `ref`:
  enclosing callbacks (e.g. a handler method's `showDialog`)
  stop counting inside it; the closure itself still counts
  when it is an argument callback (`foo.family((ref, id) =>
  …)`). [eval: TC-02.good, unit fixture]
- `overrideWithValue` takes a value, not a builder: no exclusion
  applies (a closure there carries no `ref` in valid Riverpod).
  [unevaluated]
- v0 limitation: any other function expression passed directly as
  an argument counts as a callback, including non-event cases
  such as `.map(...)` (may false-positive). A non-Riverpod
  method literally named `Provider`/`overrideWith` would be
  missed (absurd; unevaluated). [unevaluated]

`replace_invocation` semantics live in SYS-HEAL-001 §2
(fast-path mechanical); the strategy value stays declarative until recipe
lookup wires it (SYS-RECIPE-001).
