---
spec_version: "openspec-1.0"
id: "FG-CTX-006"
title: "Forbid BuildContext outside Widget/State"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "FieldDeclaration[type]"
  - "TopLevelVariableDeclaration[type]"
  - "NamedType[name='BuildContext']"
  - "GenericFunctionType"
invariant: "BuildContext MUST NOT be stored: no BuildContext fields or globals in any scope, UI included. Signatures (parameters, returns), locals, casts, and type arguments are flow-through, never flagged; function-typed fields hold callbacks, not storage."
fp_limits:
  - "BuildContext parameters, returns, locals, casts in any class"
  - "BuildContext parameters of top-level functions"
  - "the identifier 'context' (only the type name is tracked)"
  - "function-typed fields (callbacks flow through)"
golden_vectors:
  failing: "benchmark/vectors/TC-09_ctx.bad.dart"
  passing: "benchmark/vectors/TC-09_ctx.good.dart"
auto_heal_strategy: "pass_data_not_context"
---

# 1. Anti-Pattern Diagnosis

A service, repository, or bloc that stores `BuildContext` in a
field or global couples business logic to the widget tree: it
cannot be unit-tested without a widget harness, and a stored
context leaks the whole `Element` subtree after navigation.
Parameters, returns, locals, and casts only flow the caller's
context through and are never flagged; only stored positions
are (SYS-CAL-003 R2-3). AI-generated code routinely threads
`context` into service constructors because the call site has
one at hand: binding it to a field is the violation, passing
it along is not.

Interplay with FG-ASYNC-002 (reconciliation, recorded here): the ASYNC
canonical recipe threads `context` through a top-level helper — that
shape is explicitly allowed (flow-through, nothing stored), and the
mounted guard still applies inside it. Binding the same parameter to a
service or notifier object is the CTX-006 violation.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   class CartService {
-    CartService(this.context);
-
-    final BuildContext context;
+    const CartService(this.api);

-    Future<void> checkout() async {
+    Future<Receipt> checkout(Cart cart) async {
       await _api.pay();
-      Navigator.of(context).pop();
     }
   }
```

The service returns data; the calling widget navigates with its own
context (guarded per FG-ASYNC-002 when asynchronous).

# 3. Edge Cases and Non-Compliance

Stored positions (fields, top-level variables) flag in every
scope, UI included. Signatures, locals, casts, and type
arguments never flag (flow-through).

- `BuildContext` field in a service: MUST be flagged.
  [eval: TC-09.bad]
- `BuildContext` parameter in a `Cubit` method: MUST NOT be
  flagged (flow-through). [eval: TC-09.good]
- `build(BuildContext context)` in a widget: MUST NOT be flagged.
  [eval: TC-09.good]
- Top-level helper taking `BuildContext`: MUST NOT be flagged.
  [eval: TC-09.good]
- `BuildContext` field in a `State` class: MUST be flagged (stored).
  [eval: unit fixture]
- Top-level `BuildContext` variable: MUST be flagged (stored).
  [eval: TC-09.bad]
- `BuildContext` return type in a service: MUST NOT be flagged.
  [eval: unit fixture]
- Extensions on `BuildContext` or `String`: MUST NOT be flagged
  (no stored positions). [eval: unit fixture]
- `ConsumerState` scope: MUST NOT be flagged. [eval: unit fixture]
- Field in a Bloc-state subclass (`extends CartState`): MUST be
  flagged (stored). [eval: unit fixture]
- Locals, casts, and type arguments mentioning `BuildContext`:
  MUST NOT be flagged (flow-through). [eval: unit fixture]
- Function-typed fields (`void Function(BuildContext)`):
  MUST NOT be flagged (callbacks flow through).
  [eval: unit fixture]
- Stored thunks returning `BuildContext` (closing over context):
  not distinguished from callbacks (known FN). [unevaluated]
- Inferred `var x = context` (no annotation): NOT tracked (known
  false negative). [unevaluated]
- Mixins: method signatures pass like any class; mixin fields
  flag as stored. [unevaluated]
- The identifier `context` (parameters named `context` of other
  types, `foo.context` properties): never flagged — only the
  `BuildContext` type name is tracked. [unevaluated]

`pass_data_not_context` is model-owned per the SYS-HEAL-001 closed
fast-path list (the service API must be redesigned per call site); the
harness never attempts it as a fast-path patch. [unevaluated]
