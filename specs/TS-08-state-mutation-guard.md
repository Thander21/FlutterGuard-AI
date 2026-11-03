---
spec_version: "openspec-1.0"
id: "FG-ST-005"
title: "Forbid in-place state mutation in Riverpod/Bloc"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "ClassDeclaration[superclass='Cubit'|'Bloc'|'*Notifier']"
  - "MethodInvocation[mutating collection call on state]"
  - "AssignmentExpression[leftHandSide rooted at state]"
  - "PrefixExpression|PostfixExpression[operand rooted at state]"
  - "CascadeExpression[target rooted at state]"
invariant: "Inside a class extending Cubit/Bloc or *Notifier, 'state' MUST never be mutated in place: no mutating collection call on a state-rooted receiver, no assignment to a state-rooted property or subscript, no ++/-- on one; state MUST be replaced by assigning 'state' itself."
fp_limits:
  - "assigning 'state' itself (state = state.copyWith(...))"
  - "reads of state (state.items.length)"
  - "mutations of non-state receivers (copy.add)"
  - "state-like code outside Cubit/Bloc/Notifier classes"
golden_vectors:
  failing: "benchmark/vectors/TC-08_st.bad.dart"
  passing: "benchmark/vectors/TC-08_st.good.dart"
auto_heal_strategy: "copy_with_rewrite"
---

# 1. Anti-Pattern Diagnosis

Riverpod and Bloc rebuild listeners by comparing state references. Mutating
in place (`state.items.add(item)`) keeps the same reference, so no widget
rebuilds — and a defensive `state = state` afterwards assigns the identical
object, changing nothing. AI-generated notifiers routinely mutate because
the happy path reads the list right after and sees the item. State MUST be
replaced (`state = state.copyWith(items: [...state.items, item])`).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   void addItem(Item item) {
-    state.items.add(item);
-    state = state;
+    state = state.copyWith(
+      items: [...state.items, item],
+    );
   }
```

# 3. Edge Cases and Non-Compliance

Tracking is receiver-based: a chain of pure property accesses rooted at
`state` (`state`, `state.items`, `this.state.items`). Any method call in
the receiver chain breaks tracking (the result may be a copy).

Mutating calls (closed v0 set): `add`, `addAll`, `addEntries`, `insert`,
`insertAll`, `remove`, `removeAt`, `removeLast`, `removeWhere`,
`removeRange`, `removeAll`, `retainWhere`, `retainAll`, `clear`, `sort`,
`shuffle`, `setAll`, `fillRange`, `replaceRange`, `setRange`,
`putIfAbsent`, `update`, `updateAll`.

Holder classes (closed v0 set): superclass `Cubit` or `Bloc`, or any
superclass ending in `Notifier` (`Notifier`, `AsyncNotifier`,
`StateNotifier`, `FamilyNotifier`, …).

- `state.add(…)` in a `Notifier`: MUST be flagged. [eval: TC-08.bad]
- `state.items.add(…)` in a `Cubit`: MUST be flagged. [eval: TC-08.bad]
- `state = state` (self-assignment): MUST NOT be flagged.
  [eval: TC-08.bad]
- `state = state.copyWith(…)` replacement: MUST NOT be flagged.
  [eval: TC-08.good]
- Reads (`state.items.length`): MUST NOT be flagged. [eval: TC-08.good]
- Property assignment, compound assignment, `++`, and `clear()` on
  state-rooted receivers: MUST be flagged. [eval: unit fixture]
- `state`-rooted mutations in a plain class: MUST NOT be flagged
  (holder scoping). [eval: unit fixture]
- Mutations of non-state receivers (`copy.add`): MUST NOT be flagged.
  [eval: unit fixture]
- `state.toList().add(…)` (copy mutation; call breaks the chain):
  MUST NOT be flagged. [eval: unit fixture]
- Cascade (`state..add(…)..clear()`): MUST be flagged once.
  [eval: unit fixture]
- `FamilyNotifier` (suffix match): MUST be flagged. [eval: unit fixture]
- Bare `state++` / `state += 1` (setter path, notifies): MUST NOT be
  flagged. [unevaluated]
- Custom mutating methods (`state.save()`): NOT tracked (known false
  negative). [unevaluated]
- `ref.read(p).state.add(…)` chains: NOT tracked (call in the chain).
  [unevaluated]
- Generated `_$` mixins (`extends _$Counter`): unresolvable
  parse-only, NOT tracked. [unevaluated]

`copy_with_rewrite` is model-owned per the SYS-HEAL-001 closed fast-path
list (the copyWith shape must be invented per state class); the harness
never attempts it as a fast-path patch. [unevaluated]
