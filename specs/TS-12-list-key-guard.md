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
  - "NamedExpression[name='controller'|'focusNode']"
  - "ClassDeclaration[extends='StatefulWidget']"
  - "ImportDirective[uri|prefix]"
invariant: "Every item root built inside a ReorderableListView (children or itemBuilder — strict, the runtime asserts keys), or built via '.map()' feeding 'children:' or via 'itemBuilder' from a same-file StatefulWidget subclass or with a 'controller'/'focusNode' argument, MUST carry an explicit non-null 'key:' argument. Files without a Flutter import and foreign-prefixed creations are out of scope."
fp_limits:
  - "static lists of stateless tiles (keys not load-bearing)"
  - "cross-file custom tiles of unknown statefulness (fail-open)"
  - "foreign-package widgets (pw.*, other non-Flutter prefixes)"
  - "files without a Flutter import (pdf builders, pure Dart)"
  - "lowercase private method results (data, not creations)"
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
row. Every load-bearing item root MUST carry `key: ValueKey(item.id)`.

Keys are load-bearing only where a list reorders or an item holds
state: static lists of stateless tiles need no keys (the framework
docs ask for nothing there). v0 flagged every unknown-typed root
fail-closed; the round-2 field pilot (SYS-CAL-003 §2.3/§2.7) showed
that drowns the signal — 35 findings, sampled classes all false
positives (foreign `pdf` widgets, `String`-returning helpers,
static lists). v3 (SYS-CAL-003 R2-4, item-turn Q6) inverts the
doctrine to fail-open: cross-file custom tiles of unknown
statefulness pass, because parse-only analysis cannot resolve
whether they hold state. Only proven-stateful roots flag outside
reorderables: same-file `StatefulWidget` subclasses (exact
same-file supertype match) and controller-carrying creations
(`controller`/`focusNode` named arguments — closed v0 set).
`ReorderableListView` stays strict (children and `itemBuilder`):
the runtime asserts keys there, so every child needs one.

Foreign targets are out of scope. Files without a
`package:flutter/` import never flag (pdf builders, pure Dart).
A prefixed creation `p.X` is in scope only when `p` maps to a
Flutter or relative import; prefixes bound to another `package:`
or to no import are foreign and pass. Lowercase private method
calls (`_getName(...)`) are data expressions, never creations —
only names starting with an uppercase letter (after leading
underscores) count. The v0 23-leaf allowlist is RETIRED:
stateless leaves are never state-bearing, so the new scope
subsumes it.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   ListView.builder(
     itemCount: items.length,
-    itemBuilder: (context, index) => CartTile(items[index], controller: _ctrl),
+    itemBuilder: (context, index) => CartTile(
+        items[index], controller: _ctrl, key: ValueKey(items[index].id)),
   )
```

# 3. Edge Cases and Non-Compliance

Judged roots are top-level creations in the callback (never inside
another creation's arguments); lowercase factory calls are transparent.
`key: null` counts as missing. A 2-parameter `.map()` callback is
`Map.map` and is skipped. A creation counts only when its name starts
uppercase after stripping leading underscores.

- Same-file `StatefulWidget` tile via `.map()` into `children:`:
  MUST be flagged. [eval: TC-12.bad]
- Controller-carrying tile via `itemBuilder`: MUST be flagged.
  [eval: TC-12.bad]
- Keyless child of `ReorderableListView`: MUST be flagged.
  [eval: TC-12.bad]
- Keyless `Text` in `ReorderableListView`: MUST be flagged (strict —
  the runtime asserts). [eval: TC-12.bad]
- Keyed tiles: MUST NOT be flagged. [eval: TC-12.good]
- Unknown cross-file tile via `.map()`/`itemBuilder` (no
  controller): MUST NOT be flagged (fail-open). [eval: TC-12.good]
- Foreign `pw.Padding` via `.map()`: MUST NOT be flagged.
  [eval: TC-12.good]
- `Text` leaf via `.map()`: MUST NOT be flagged (not
  state-bearing — no allowlist anymore). [eval: TC-12.good]
- Keyed `ReorderableListView` child: MUST NOT be flagged.
  [eval: TC-12.good]
- Block body with `key: null` on a stateful tile: MUST be
  flagged. [eval: unit fixture]
- Local-variable shape (`final t = Tile(x); return t;`) with a
  controller: MUST be flagged (root scan). [eval: unit fixture]
- Creation nested in `Card`: skipped (single-child slot cannot
  transpose). [eval: unit fixture]
- `ListTile` via `itemBuilder`: MUST NOT be flagged (not
  state-bearing). [eval: unit fixture]
- Tear-off `.map(Tile.new)`: MUST NOT be flagged (untraced).
  [eval: unit fixture]
- Single-child `builder:` callbacks: MUST NOT be flagged (no list).
  [eval: unit fixture]
- `itemBuilder` under `ReorderableListView.builder`: strict, no
  exemption. [eval: unit fixture]
- `Map.map` (2 parameters): MUST NOT be flagged. [eval: unit fixture]
- Data `.map()` (`Record`) not feeding `children:`: MUST NOT be
  flagged. [eval: unit fixture]
- `_getName` (lowercase private, returns `String`): MUST NOT be
  flagged (not a creation). [eval: unit fixture]
- `_Tile` (uppercase private): still a creation; MUST be flagged
  when state-bearing and keyless. [eval: unit fixture]
- Prefixed same-project tile (`tiles.CartTile` via a relative
  import): in scope; MUST be flagged when state-bearing and
  keyless. [eval: unit fixture]
- Prefixed tile with an unmapped prefix: MUST NOT be flagged
  (foreign fail-open). [eval: unit fixture]
- Whole file without a Flutter import (pdf builder shape): MUST
  NOT be flagged (file gate). [eval: unit fixture]
- `focusNode`-carrying tile: MUST be flagged like `controller`.
  [eval: unit fixture]
- Plain named arguments (`title:`, `onTap:`): never state-bearing;
  MUST NOT be flagged. [eval: unit fixture]
- `GridView`/`PageView` builders: same `itemBuilder` path.
  [partial: ListView in TC-12.bad]
- `.map()` via a variable into `children:`: missed (no dataflow).
  [unevaluated]
- `separatorBuilder`: NOT tracked. [unevaluated]
- `SliverChildBuilderDelegate.builder`: NOT tracked. [unevaluated]
- Creations in nested closures count as roots (may false-positive).
  [unevaluated]
- Spread identifiers (`...myTiles`): NOT traced. [unevaluated]
- Cross-file `StatefulWidget` tiles: missed (fail-open by design —
  parse-only cannot resolve them). [unevaluated]

`add_value_key` is model-owned per the SYS-HEAL-001 closed fast-path
list (the id expression must be invented per item type); the harness
never attempts it as a fast-path patch. [unevaluated]
