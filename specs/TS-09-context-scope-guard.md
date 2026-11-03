---
spec_version: "openspec-1.0"
id: "FG-CTX-006"
title: "Forbid BuildContext outside Widget/State"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "ClassDeclaration[superclass]"
  - "ExtensionDeclaration[extendedType]"
  - "FieldDeclaration[type]"
  - "TopLevelVariableDeclaration[type]"
  - "NamedType[name='BuildContext']"
invariant: "BuildContext MUST NOT be bound to an object outside the widget tree: no BuildContext fields or globals anywhere, and no BuildContext type reference inside a class that is not a Widget/State/UI-extension. Top-level functions may take BuildContext (explicit flow-through)."
fp_limits:
  - "BuildContext in Widget/State signatures and bodies"
  - "BuildContext parameters of top-level functions"
  - "the identifier 'context' (only the type name is tracked)"
golden_vectors:
  failing: "benchmark/vectors/TC-09_ctx.bad.dart"
  passing: "benchmark/vectors/TC-09_ctx.good.dart"
auto_heal_strategy: "pass_data_not_context"
---

# 1. Anti-Pattern Diagnosis

A service, repository, or bloc that takes or stores `BuildContext`
couples business logic to the widget tree: it cannot be unit-tested
without a widget harness, and a stored context leaks the whole
`Element` subtree after navigation. AI-generated code routinely threads
`context` into service constructors because the call site has one at
hand. Services MUST receive data, never context; only widgets, `State`
objects, and free helper functions may touch the type.

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

UI scope (allowed): classes extending a widget (`StatelessWidget`,
`StatefulWidget`, `ConsumerWidget`, `ConsumerStatefulWidget`,
`HookWidget`, `HookConsumerWidget`, or any `*Widget` suffix) or exactly
`State`/`ConsumerState`; extensions on `BuildContext`, `State`,
`ConsumerState`, or a widget. Stored positions (fields, top-level
variables) are flagged in every scope, UI included.

- `BuildContext` field in a service: MUST be flagged.
  [eval: TC-09.bad]
- `BuildContext` parameter in a `Cubit` method: MUST be flagged.
  [eval: TC-09.bad]
- `build(BuildContext context)` in a widget: MUST NOT be flagged.
  [eval: TC-09.good]
- Top-level helper taking `BuildContext`: MUST NOT be flagged.
  [eval: TC-09.good]
- `BuildContext` field in a `State` class: MUST be flagged (stored).
  [eval: unit fixture]
- Top-level `BuildContext` variable: MUST be flagged (stored).
  [eval: unit fixture]
- `BuildContext` return type in a service: MUST be flagged.
  [eval: unit fixture]
- Extension on `BuildContext`: MUST NOT be flagged. [eval: unit fixture]
- Extension on `String` with a context parameter: MUST be flagged.
  [eval: unit fixture]
- `ConsumerState` scope: MUST NOT be flagged. [eval: unit fixture]
- Bloc-state subclass (`extends CartState`): MUST be flagged (not UI).
  [eval: unit fixture]
- Locals, casts, and type arguments mentioning `BuildContext` in a
  non-UI class: same `NamedType` path.
  [partial: params/returns/fields eval'd]
- Inferred `var x = context` (no annotation): NOT tracked (known
  false negative). [unevaluated]
- Mixins: treated as non-UI scope. [unevaluated]
- Custom `State` bases (`extends MyState`): may false-positive
  (exact-name match only, so Bloc states stay flagged). [unevaluated]
- `extension type` bodies: scope untracked (analyzer 6.4.1 has no
  `ExtensionTypeDeclaration` node). [unevaluated]
- The identifier `context` (parameters named `context` of other
  types, `foo.context` properties): never flagged — only the
  `BuildContext` type name is tracked. [unevaluated]

`pass_data_not_context` is model-owned per the SYS-HEAL-001 closed
fast-path list (the service API must be redesigned per call site); the
harness never attempts it as a fast-path patch. [unevaluated]
