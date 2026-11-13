---
spec_version: "openspec-1.0"
id: "FG-SYNC-034"
title: "No blocking sync I/O in frame-critical scopes"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[name='*Sync']"
  - "MethodInvocation[name='sleep',target=null]"
  - "MethodDeclaration[name='build']"
  - "FunctionDeclaration[returns='Widget']"
  - "NamedArgument[name='on[A-Z]*']"
  - "FunctionExpression[handler]"
invariant: "No blocking sync invocation (a call whose lowercase-led method name ends in `Sync`, or a bare `sleep(` call) may execute directly in a measured build scope (TS-14 doctrine) or lexically inside an `on[A-Z]*` handler closure passed as a named argument to a constructor-shaped invocation; sync work in any other scope is unmeasured."
fp_limits:
  - "async I/O variants (`readAsString`, `writeAsString`, ...) anywhere"
  - "sync calls in `initState`, tests, CLI code, top-level functions, isolate callbacks (`compute`)"
  - "`compute()` itself (the fix, never a trigger)"
  - "`on*` closures passed to lowercase (non-constructor) calls"
  - "named arguments starting with lowercase-led `on` (`only:`, `once:`)"
  - "`x.onPressed = ...` assignments and torn-off or stored callbacks (argument shape only)"
  - "dotted or prefixed `.sleep` calls (bare-only v1)"
  - "capitalized `*Sync` constructions (`DataSync(...)` — constructor-shaped)"
  - "non-`Sync` blocking work: loops, `jsonDecode`, compute kernels (profiler questions)"
  - "`Notifier.build` and non-`Widget` `build` methods (TS-14 measured-build doctrine)"
golden_vectors:
  failing: "benchmark/vectors/TC-34_sync.bad.dart"
  passing: "benchmark/vectors/TC-34_sync.good.dart"
auto_heal_strategy: "model-owned"
---

# 1. Anti-Pattern Diagnosis

A frame budget is ~16ms. Blocking synchronous I/O
(`readAsStringSync`, `writeAsStringSync`, `sleep`, ...) on the UI
isolate freezes every pixel until the disk answers: dropped frames,
ANR-style stalls, dead taps. Two scopes run frame-critically:
`build()` (up to 60-120 executions per second) and widget
event-handler closures (`onPressed`, `onTap` — dispatched
synchronously on the tap). AI generators emit the sync shape
because the happy path runs once on a fast disk and looks fine;
the jank only appears on slow storage under real load. The
structural fixes are the async variant with `await`, hoisting out
of `build()` into `initState`, or precomputing off the frame.
This rule is the buildable subset of SPIKE-PERF-010 (general
"heavy work" detection needs a profiler, not a parser): a closed
name set (`*Sync` + bare `sleep`) crossed with frame-critical
scopes.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   onPressed: () async {
-    final text = File('note.txt').readAsStringSync();
+    final text = await File('note.txt').readAsString();
     setState(() => _note = text);
   },
```

In `build()` scope the same trigger hoists instead: load once in
`initState` (async) and read the cached value per frame.

# 3. Edge Cases and Non-Compliance

Trigger set: any `MethodInvocation` whose method name is
lowercase-led and ends in `Sync` (case-sensitive —
`resync`/`sync` do not match; capitalized names are
constructor-shaped unresolved spellings, never sync methods) on
any target, plus bare `sleep(` (no target, no prefix).

Measured scopes:

- Direct build flow: the TS-14 measured-build doctrine
  (`Widget`-typed or untyped `build()` methods,
  `Widget`-returning functions; `Notifier.build` and non-`Widget`
  `build` excluded), at function depth 1 — nested closures are
  handlers, not direct flow.
- Handler flow: a `FunctionExpression` passed directly as a named
  argument matching `on[A-Z]\w*` to a constructor-shaped
  invocation (`InstanceCreationExpression`, or a
  `MethodInvocation` whose name starts uppercase — the
  unresolved-constructor spelling). Triggers fire at any nesting
  depth inside the handler: nested closures there still run
  synchronously on the tap.

- `readAsStringSync` directly in `build()`: MUST be flagged.
  [eval: TC-34.bad]
- `writeAsStringSync` directly in `build()`: MUST be flagged.
  [eval: TC-34.bad]
- bare `sleep()` directly in `build()`: MUST be flagged.
  [eval: TC-34.bad]
- `existsSync` in an `onPressed` handler: MUST be flagged.
  [eval: TC-34.bad]
- `listSync` in an `onTap` handler: MUST be flagged.
  [eval: TC-34.bad]
- `deleteSync` in a nested `forEach` closure inside `onPressed`:
  MUST be flagged (nested handler closures still block the tap).
  [eval: unit fixture]
- `statSync` directly in a `Widget`-returning function: MUST be
  flagged. [eval: unit fixture]
- triggers in untyped `build()`: MUST be flagged (fail-closed,
  TS-14 doctrine). [eval: TC-34.bad]
- async variants (`readAsString`, `writeAsString`) in
  build/handlers: MUST NOT be flagged. [eval: TC-34.good]
- triggers in `initState()`: MUST NOT be flagged (runs once,
  spike scope). [eval: TC-34.good]
- triggers in top-level functions, tests, CLI code: MUST NOT be
  flagged. [eval: TC-34.good]
- triggers in a `compute()` closure: MUST NOT be flagged (isolate
  scope). [eval: TC-34.good]
- `compute()` in `build()`: MUST NOT be flagged (the fix).
  [eval: unit fixture]
- `onDone:` closure on a lowercase call: MUST NOT be flagged
  (constructor-shaped proxy). [eval: TC-34.good]
- `only:`/`once:` closures: MUST NOT be flagged (lowercase-led,
  not handlers). [eval: unit fixture]
- `x.onPressed = () {...}` assignments: MUST NOT be flagged
  (argument shape only). [eval: unit fixture]
- `io.sleep(...)` / `alarm.sleep()`: MUST NOT be flagged
  (bare-only v1; known gap). [eval: unit fixture]
- loops, `jsonDecode`, hashing in build/handlers: MUST NOT be
  flagged (profiler questions per spike). [eval: TC-34.good]
- triggers in `Notifier.build`: MUST NOT be flagged (provider
  initialization, TS-14 doctrine). [eval: TC-34.good]
- triggers in `void`/`Future` `build()`: MUST NOT be flagged
  (TS-14 doctrine). [eval: TC-34.good]
- triggers in a `setState` closure: MUST NOT be flagged (not
  widened per spike). [eval: unit fixture]
- `DataSync(...)` construction in `build()`: MUST NOT be flagged
  (capitalized names are constructor-shaped). [eval: unit fixture]
- sync calls wrapped in `Future.microtask`/`Timer` inside a
  handler: flagged (async-escape untracked parse-only; accepted
  over-approximation). [unevaluated]
- custom `*Sync`-suffixed methods (`forceSync`): flagged
  (name-based matching; dart:io owns the suffix in practice).
  [unevaluated]
- indirect notifier subclasses: measured (direct-superclass
  ceiling, TS-14). [unevaluated]
- `on*` handler on a lowercase factory wrapper: unmeasured
  (constructor-shaped proxy gap). [unevaluated]

Healing is model-owned: asyncify (`Sync` to `await` async),
hoist to `initState`, or precompute — the choice needs judgment,
outside the SYS-HEAL-001 closed fast-path list. [unevaluated]
