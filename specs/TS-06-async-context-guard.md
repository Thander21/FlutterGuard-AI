---
spec_version: "openspec-1.0"
id: "FG-ASYNC-002"
title: "Forbid BuildContext use after await without a mounted guard"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "BlockFunctionBody[keyword='async']"
  - "AwaitExpression"
  - "SimpleIdentifier[name='context']"
  - "MethodInvocation[name='setState']"
invariant: "Every read of 'context' and every 'setState' call that follows an 'await' in the same async body MUST sit behind a 'mounted'/'context.mounted' guard (early return or guarded block)."
fp_limits:
  - "context used before any await, or in the same statement as the await"
  - "'mounted'/'context.mounted' guard reads themselves"
  - "awaits nested in closures (never arm the outer body)"
  - "named-argument and statement labels (tokens, never reads)"
golden_vectors:
  failing: "benchmark/vectors/TC-06_async.bad.dart"
  passing: "benchmark/vectors/TC-06_async.good.dart"
auto_heal_strategy: "insert_before_invocation"
---

# 1. Anti-Pattern Diagnosis

When the user pops the route while an `await` is in flight, the widget
unmounts. Any `BuildContext` use after the gap (`Navigator.of(context)`,
`showDialog`, `Theme.of(context)`) throws on the orphaned context, and
`setState` throws on the dead `State`. AI-generated handlers routinely
sequence `await` then UI work because the happy path never navigates away
mid-request. Every post-await context use MUST sit behind a mounted guard.
Labels named `context` (`log(context: '...')`) are tokens, not
reads: the analyzer-14 AST exposes no identifier for them, so
they can never be sinks (SYS-CAL-002 P1-4).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   Future<void> submitOrder(BuildContext context, WidgetRef ref) async {
     await ref.read(orderServiceProvider).process();
+    if (!context.mounted) return;
     Navigator.of(context).pop();
   }
```

The injected form is always `if (!context.mounted) return;`: it is valid
in `State` methods (via the `State.context` getter) and in helpers that
take `context` as a parameter, where bare `mounted` does not resolve.
Bare `if (!mounted) return;` is accepted as a guard but never injected.

# 3. Edge Cases and Non-Compliance

Guard-form allowlist (each tracked per async body, re-armed by later
awaits; branch bodies are scanned by threading the armed state through
`if`/`for`/`while`/`try`/`switch`, so `try { await …; use }` is caught):

- `Navigator.of(context)` after `await`: MUST be flagged.
  [eval: TC-06.bad]
- `setState(…)` after `await` (unmount sub-case): MUST be flagged.
  [eval: TC-06.bad]
- `context` used before any `await` (e.g. captured then used later):
  MUST NOT be flagged. [eval: TC-06.good]
- `if (!context.mounted) return;` disarms the rest of the body.
  [eval: TC-06.good]
- `if (!mounted) return;` (bare or brace-wrapped) disarms the rest.
  [eval: TC-06.good]
- `if (mounted) { … }` / `if (context.mounted) { … }`: the block is
  scanned fresh (disarmed start), so `await` inside re-arms.
  [eval: TC-06.good]
- A later `await` after a guard re-arms the body. [eval: unit fixture]
- Top-level and helper functions are scanned, not just `State` methods.
  [eval: unit fixture]
- `await` and use in one statement (`await showDialog(context: …)`):
  the context is consumed before the gap, MUST NOT be flagged.
  [eval: unit fixture]
- Post-await named-argument labels (`log(context: '...')`):
  MUST NOT be flagged (no identifier exists for a label).
  [eval: TC-06.good]
- Statement labels named `context`: MUST NOT be flagged.
  [eval: unit fixture]
- `await` nested in a closure never arms the outer body.
  [eval: unit fixture]
- `try { await …; use }` is flagged (threaded scan). [eval: unit fixture]
- An unarmed `if` whose branch suspends then uses context is flagged.
  [eval: unit fixture]
- `.mounted` reads are never flagged, guard or not. [eval: TC-06.good]
- Multi-statement guard blocks (`if (!mounted) { log(); return; }`):
  leading statements run unmounted and are scanned armed.
  [unevaluated]
- Branches that may suspend arm the code after them (fail-closed).
  [unevaluated]
- `.then(…)` chains after an `await`: NOT traced. [unevaluated]
- A closure carrying its own inner guard inside an armed statement:
  may false-positive (sinks descend into closures). [unevaluated]
- `async*` generators: out of scope for v0. [unevaluated]
- A method literally named `context`: never a sink. [unevaluated]
- `foo.mounted` on any receiver counts as a guard (possible false
  negative when `foo` is not the widget). [unevaluated]
- `foo.context` property reads count as context uses. [unevaluated]
- Ternary or `&&`-chained guards: out of scope for v0. [unevaluated]

`insert_before_invocation` injects `if (!context.mounted) return;` above
the violation line: a single-line guard insert, fast-path mechanical per
the SYS-HEAL-001 closed list. [unevaluated]
