---
spec_version: "openspec-1.0"
id: "FG-ARCH-003"
title: "Forbid persistence/network imports in widget files"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "ClassDeclaration[superclass='*Widget']"
  - "ImportDirective[uri='package:…']"
  - "ExportDirective[uri='package:…']"
invariant: "A file declaring a widget class (superclass in the Widget set or ending in 'Widget') MUST NOT import or export a persistence/network package from the v0 denylist; data access MUST live behind a repository or provider in the data layer."
fp_limits:
  - "denylisted imports in files without a widget class (data layer)"
  - "framework imports (flutter, flutter_riverpod, bloc) in widget files"
  - "relative imports of data files (not tracked in v0)"
golden_vectors:
  failing: "benchmark/vectors/TC-05_arch.bad.dart"
  passing: "benchmark/vectors/TC-05_arch.good.dart"
auto_heal_strategy: "move_to_data_layer"
---

# 1. Anti-Pattern Diagnosis

A view widget that imports a database (`drift`, `sqlite3`) or an HTTP client
(`dio`, `supabase`) directly couples the interface to infrastructure: the
screen cannot be unit-tested without a database, and every persistence change
ripples into UI code. AI-generated screens routinely inline the database call
in `onPressed` because the happy path saves once and never tests.
The UI layer MUST delegate to a notifier, provider, or repository instead.

Layer detection is content-based in v0: `grade` runs every golden vector
from `benchmark/vectors/`, so the layer cannot come from the file path —
a file that declares a widget class IS the UI layer for this rule.
A project-configurable directory→layer map is future work (noted per
PLAN-02 P1); until it exists, path segments are ignored.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   ElevatedButton(
-    onPressed: () async {
-      final db = AppDatabase();
-      await db.into(db.products).insert(Companion(...));
+    onPressed: () {
+      ref.read(productFormNotifierProvider.notifier).saveProduct();
     },
     child: const Text('Save'),
   )
```

# 3. Edge Cases and Non-Compliance

v0 denylisted packages (closed list; any `package:<name>/…` import or
export in a widget file is flagged at the directive line):

| Area | Packages |
|---|---|
| Persistence | `drift`, `sqlite3`, `sqflite`, `floor` |
| Network | `supabase`, `supabase_flutter`, `dio`, `http` |

- `drift` / `dio` imports in a widget file: MUST be flagged.
  [eval: TC-05.bad]
- Remaining denylisted packages: same code path, not in the pair.
  [partial: 2/8 packages in TC-05.bad]
- `export` of a denylisted package in a widget file: MUST be flagged.
  [eval: unit fixture]
- Superclass matched by suffix (`extends BaseWidget`): counts as a
  widget file. [eval: unit fixture]
- Exact widget set: `StatelessWidget`, `StatefulWidget`, `ConsumerWidget`,
  `ConsumerStatefulWidget`, `HookWidget`, `HookConsumerWidget`.
  [partial: StatefulWidget/ConsumerWidget in TC-05 pair]
- Denylisted imports in a file with no widget class (data layer):
  MUST NOT be flagged. [eval: unit fixture]
- Framework imports (`flutter`, `flutter_riverpod`, `bloc`) in a widget
  file: MUST NOT be flagged. [eval: TC-05.good]
- `ref.read` delegation inside callbacks: MUST NOT be flagged.
  [eval: TC-05.good]
- Relative imports of data files (`../data/app_db.dart`): NOT tracked
  in v0. [unevaluated]
- Split files declaring only `State` (no widget class in the file):
  NOT detected in v0. [unevaluated]
- Deferred imports and `show`/`hide` combinators on denylisted
  packages: flagged like any import (no combinator analysis).
  [unevaluated]

`move_to_data_layer` is model-owned per the SYS-HEAL-001 closed fast-path
list (multi-hunk: remove the import plus rewrite every call site); the
harness never attempts it as a fast-path patch.
