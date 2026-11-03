---
spec_version: "openspec-1.0"
id: "FG-BLOC-001"
title: "Mandatory isClosed guard on async emissions in Cubit/Bloc"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[name='emit']"
  - "AwaitExpression"
invariant: "Every 'emit' preceded by 'await' inside a class extending 'Cubit' or 'Bloc' (matched by superclass name, no type resolution) MUST have the guard 'if (isClosed) return;' as a preceding top-level statement."
fp_limits:
  - "emit with no preceding await in the method"
  - "emit already guarded by a top-level isClosed check"
golden_vectors:
  failing: "benchmark/vectors/TC-01_bloc.bad.dart"
  passing: "benchmark/vectors/TC-01_bloc.good.dart"
auto_heal_strategy: "insert_before_invocation"
---

# 1. Anti-Pattern Diagnosis

Emitting state after the Cubit has been closed throws a silent `StateError`
in production when the screen is disposed while an async request (e.g. HTTP)
is still in flight. AI-generated handlers routinely omit the guard because
the happy path never closes the Cubit mid-await.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
  Future<void> checkout() async {
    emit(CartSaving());
    await _repository.save();
+   if (isClosed) return;
    emit(CartSaved());
  }
```

# 3. Edge Cases and Non-Compliance

- `await` inside `try` blocks: an unguarded `emit` after the `try` is still
  flagged. v0 limitation: only top-level statements are tracked, so a guard
  nested inside the `try` does not disarm the gate (may false-positive).
  [unevaluated]
- Private helper methods invoked from within the handler: out of scope for
  v0, call targets are NOT traced. [unevaluated]
- `emit` with no preceding `await` in the method: MUST NOT be flagged.
  [eval: TC-01.good]
- `emit` already guarded by a top-level `isClosed` check: MUST NOT be flagged.
  [eval: TC-01.good]
- Other `BlocBase` subclasses beyond `Cubit`/`Bloc`: out of scope for v0,
  NOT checked. [unevaluated]

`insert_before_invocation` semantics live in SYS-HEAL-001 §2
(fast-path mechanical); the strategy value stays declarative until recipe
lookup wires it (SYS-RECIPE-001).
