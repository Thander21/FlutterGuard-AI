---
spec_version: "openspec-1.0"
id: "FG-KEY-001r"
title: "Require keys for widgets built in lists"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[name='map']"
  - "NamedExpression[name='itemBuilder']"
  - "InstanceCreationExpression[type='ReorderableListView']"
  - "NamedExpression[name='key']"
invariant: "Every widget creation returned as a list item — via a '.map()' callback feeding 'children:', via an 'itemBuilder' callback, or as a ReorderableListView child — MUST carry an explicit non-null 'key:' argument, except closed-set stateless leaves (never exempt in ReorderableListView)."
fp_limits:
  - "closed-set stateless leaves (Text, Icon, ListTile, …)"
  - "data objects built in .map() (Record, MapEntry, …)"
  - "tear-off and named callbacks (untraced)"
golden_vectors:
  failing: "benchmark/vectors/TC-12_key.bad.dart"
  passing: "benchmark/vectors/TC-12_key.good.dart"
auto_heal_strategy: "add_value_key"
---

# 1. Anti-Pattern Diagnosis

When rows are added, removed, or reordered, Flutter matches old and new
item `Element`s by type — and by `Key` when present. A stateful tile
without a key silently inherits its neighbor's `State` after a deletion
(text fields swap contents, checkboxes jump rows). AI-generated lists
routinely map items to bare tiles because the preview never deletes a
row. Every item root MUST carry `key: ValueKey(item.id)`.

Statefulness is not resolved parse-only (custom tiles usually live in
another file), so unknown types fail closed: every item root needs a
key except a closed set of stateless framework leaves. `.map()` is
judged only when its result flows into `children:` (directly or via
spread/`.toList()` chains) — data maps building `Record`/`MapEntry`
objects are not widgets and stay clean. `ReorderableListView` asserts
keys at runtime, so its children are strict: no leaf exemption.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   ListView.builder(
     itemCount: items.length,
-    itemBuilder: (context, index) => CartTile(items[index]),
+    itemBuilder: (context, index) =>
+        CartTile(items[index], key: ValueKey(items[index].id)),
   )
```

# 3. Edge Cases and Non-Compliance

Judged roots are top-level creations in the callback (never inside
another creation's arguments); lowercase factory calls are transparent.
`key: null` counts as missing. A 2-parameter `.map()` callback is
`Map.map` and is skipped.

Closed stateless-leaf set (23): `Text`, `RichText`, `Icon`, `Image`,
`Divider`, `VerticalDivider`, `Placeholder`, `Spacer`, `SizedBox`,
`Padding`, `Center`, `Align`, `Container`, `DecoratedBox`, `ColoredBox`,
`ListTile`, `CheckboxListTile`, `SwitchListTile`, `RadioListTile`,
`Card`, `Chip`, `CircleAvatar`, `Badge`.

- Custom tile via `.map()` into `children:`: MUST be flagged.
  [eval: TC-12.bad]
- Custom tile via `itemBuilder`: MUST be flagged. [eval: TC-12.bad]
- Keyless child of `ReorderableListView`: MUST be flagged.
  [eval: TC-12.bad]
- Keyless `Text` in `ReorderableListView`: MUST be flagged (strict —
  the runtime asserts). [eval: TC-12.bad]
- Keyed tiles: MUST NOT be flagged. [eval: TC-12.good]
- `Text` leaf via `.map()`: MUST NOT be flagged. [eval: TC-12.good]
- Keyed `ReorderableListView` child: MUST NOT be flagged.
  [eval: TC-12.good]
- Block body with `key: null`: MUST be flagged. [eval: unit fixture]
- Local-variable shape (`final t = Tile(x); return t;`): MUST be
  flagged (root scan). [eval: unit fixture]
- Creation nested in `Card`: skipped (single-child slot cannot
  transpose). [eval: unit fixture]
- `ListTile` via `itemBuilder`: MUST NOT be flagged. [eval: unit fixture]
- Tear-off `.map(Tile.new)`: MUST NOT be flagged (untraced).
  [eval: unit fixture]
- Single-child `builder:` callbacks: MUST NOT be flagged (no list).
  [eval: unit fixture]
- `itemBuilder` under `ReorderableListView.builder`: strict, no leaf
  exemption. [eval: unit fixture]
- `Map.map` (2 parameters): MUST NOT be flagged. [eval: unit fixture]
- Data `.map()` (`Record`) not feeding `children:`: MUST NOT be
  flagged. [eval: unit fixture]
- `GridView`/`PageView` builders: same `itemBuilder` path.
  [partial: ListView in TC-12.bad]
- `.map()` via a variable into `children:`: missed (no dataflow).
  [unevaluated]
- `separatorBuilder`: NOT tracked. [unevaluated]
- `SliverChildBuilderDelegate.builder`: NOT tracked. [unevaluated]
- Creations in nested closures count as roots (may false-positive).
  [unevaluated]
- Spread identifiers (`...myTiles`): NOT traced. [unevaluated]

`add_value_key` is model-owned per the SYS-HEAL-001 closed fast-path
list (the id expression must be invented per item type); the harness
never attempts it as a fast-path patch. [unevaluated]
