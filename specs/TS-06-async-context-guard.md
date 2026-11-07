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
  - "FunctionExpression"
  - "FormalParameter"
invariant: "Every read of an unshadowed 'context' (no nearer binding unless typed 'BuildContext'; 'x.context' only for 'this'/'super' receivers) and every 'setState' call that follows an 'await' in the same async body MUST sit behind a 'mounted'/'context.mounted' guard (early return taken when unmounted, including '||' chains, or a block whose condition requires mounted, including '&&' chains; honored inside closures and nested 'if'/'try'/loop bodies)."
fp_limits:
  - "context used before any await, or in the same statement as the await (arguments and builder closures of the awaited call)"
  - "uses behind an inner guard of a compound statement's body (only headers are scanned flat)"
  - "'&&'-chained mounted checks and '||'-chained mounted early returns"
  - "'mounted'/'context.mounted' guard reads themselves"
  - "awaits nested in closures (never arm the outer body)"
  - "named-argument and statement labels (tokens, never reads)"
  - "context redeclared by a nearer binding (locals, params, loop/catch vars)"
  - "foreign 'x.context' properties (receiver is not this/super)"
  - "uses behind an inner 'mounted' block inside closures or try bodies"
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

Scope (SYS-CAL-003 R2-1): `context` counts only when it can
still resolve to the widget's `BuildContext`. A nearer local,
loop-variable, catch-variable, or non-`BuildContext` parameter
binding passes (a `BuildContext`-typed parameter — `build` or
helper — still counts), as does a foreign `x.context` property
(`this`/`super` receivers still count). Closure bodies inherit
the enclosing armed state, so an inner `if (mounted)` guard
disarms only the closure while unguarded deferred uses still
flag; `try`/`catch`/`finally` bodies thread the scan, so
mounted blocks inside them are honored.

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
- `&&`-chained guards (`if (x != null && context.mounted) { … }`,
  `if (cond && mounted) { … }`): any mounted conjunct makes the block
  a guarded block. [eval: TC-06.good]
- `||`-chained early returns (`if (ok != true || !context.mounted)
  return;`): any negated mounted disjunct disarms the rest.
  [eval: TC-06.good]
- `if (!quiet || mounted) { use }` does not require mounted: the use
  MUST be flagged. [eval: unit fixture]
- Compound statements (`if`/`for`/`while`/`switch`/`try`/blocks) flag
  only their header expressions flat; bodies are scanned statement
  by statement, so a guard inside a nested `try`/`if` body clears
  the rest of that body. [eval: TC-06.good]
- `context` / `setState` before the first `await`, including inside
  a `try` body that awaits later: MUST NOT be flagged.
  [eval: TC-06.good]
- A nested `try` body that awaits again and then uses context with
  no inner guard: MUST be flagged. [eval: TC-06.bad]
- A later `await` after a guard re-arms the body. [eval: unit fixture]
- Top-level and helper functions are scanned, not just `State` methods.
  [eval: unit fixture]
- `await` and use in one statement (`await showDialog(context: …)`):
  the context is consumed before the gap, MUST NOT be flagged.
  [eval: unit fixture]
- Closures in the awaited statement itself (`builder: (ctx) =>
  Text(S.of(context)!.x)`) inherit the state the statement was
  entered with: they run while the dialog builds, MUST NOT be
  flagged. [eval: TC-06.good]
- A use in a later statement after that awaited dialog, with no
  guard: MUST be flagged. [eval: TC-06.bad]
- An `if` branch that awaits and always exits (trailing `return`,
  `throw` or `rethrow`) does not arm the code after the `if`: a later
  use MUST NOT be flagged; the same branch without the exit MUST
  arm it. [eval: unit fixture]
- A closure in the awaited statement that runs after the gap
  (`await Future.delayed(d, () => Navigator.of(context))`): NOT
  flagged (accepted false negative). [unevaluated]
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
- `context` redeclared by a nearer local, loop-variable,
  catch-variable, or non-`BuildContext` parameter binding:
  MUST NOT be flagged. [eval: TC-06.good]
- `BuildContext`-typed parameters (`build`, helpers, top-level
  functions): unguarded post-gap reads MUST be flagged — no
  file gate. [eval: TC-06.bad]
- `if (mounted)` / `if (context.mounted)` blocks inside `try` /
  `catch` / `finally` bodies are honored. [eval: TC-06.good]
- `if (mounted) { await …; use }`: the inner `await` re-arms,
  so the use MUST be flagged (stale check). [eval: unit fixture]
- Initializer scope is approximate: in
  `final context = f(context)` the right-hand `context`
  resolves outward but passes. [unevaluated]
- Pattern variables and switch-case locals named `context`
  are not modeled: still flag (fail-closed). [unevaluated]
- Multi-statement guard blocks (`if (!mounted) { log(); return; }`):
  leading statements run unmounted and are scanned armed.
  [unevaluated]
- Branches that may suspend arm the code after them (fail-closed):
  after an `if`, the state is armed when either branch leaves it
  armed. [unevaluated]
- A loop body that awaits is scanned armed from its first statement
  (the next iteration runs after the gap). [unevaluated]
- `.then(…)` chains after an `await`: NOT traced. [unevaluated]
- A closure inside an armed statement inherits the armed state:
  an inner `if (mounted)` / `if (context.mounted)` guard
  disarms the closure body. [eval: TC-06.good]
- A closure with no inner guard still flags its deferred uses.
  [eval: unit fixture]
- `async*` generators: out of scope for v0. [unevaluated]
- A method literally named `context`: never a sink. [unevaluated]
- `foo.mounted` on any receiver counts as a guard (possible false
  negative when `foo` is not the widget). [unevaluated]
- `x.context` where `x` is not `this`/`super`: MUST NOT be
  flagged (foreign property). [eval: TC-06.good]
- `this.context` after a gap: MUST be flagged.
  [eval: unit fixture]
- Ternary guards, `mounted == false`, and guards stored in locals:
  out of scope for v0 (still flag, fail-closed). [unevaluated]

`insert_before_invocation` injects `if (!context.mounted) return;` above
the violation line: a single-line guard insert, fast-path mechanical per
the SYS-HEAL-001 closed list. [unevaluated]
