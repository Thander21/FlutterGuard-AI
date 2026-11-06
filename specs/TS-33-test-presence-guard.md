---
spec_version: "openspec-1.0"
id: "FG-TST-033"
title: "lib files need mirror tests"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(path oracle: lib/ file vs test/ mirror existence)"
invariant: "Every `.dart` file under a `lib/` directory MUST have its mirror test (`test/` + `_test.dart` suffix) — untested logic files are where regressions hide."
fp_limits:
  - "lib files with an existing mirror test"
  - "lib/main.dart (entrypoint wiring, not logic)"
  - "generated files and non-lib files"
  - "everything when the test_presence section is absent (opt-in)"
golden_vectors:
  failing: "benchmark/vectors/tc33/bad/lib/shop.dart"
  passing: "benchmark/vectors/tc33/good/lib/shop.dart"
auto_heal_strategy: "model-owned"
---

# 1. Anti-Pattern Diagnosis

AI-generated features land as brand-new `lib/` files with no
test: the suite stays green because nothing exercises the new
code, and the first regression arrives as a production incident.
The campodeforca `TestPresence` gate (SYS-CAL-003 R2-5 medium
list) requires a test for new logic files; this rule is that
gate, universal and layout-strict. One finding per uncovered
file, on line 1 (file-level — the ORP precedent). Newness comes
from the run, not the rule: `check --diff` (or the baseline on
legacy trees) scopes the gate to new files, while the rule
itself judges presence. Layouts vary by project (mirror, flat,
colocated), so a strict mirror would red-flag trees it was never
promised to — the rule is silent until a `test_presence:`
section opts in (the LOG-019 precedent).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
+  // test/shop_test.dart (new file mirroring the lib path)
+  import 'package:test/test.dart';
+  import '../lib/shop.dart';
+
+  void main() {
+    test('price formats', () {
+      expect(price(), isNotEmpty);
+    });
+  }
```

# 3. Edge Cases and Non-Compliance

The mirror maps the last `/lib/` segment to `/test/` and the
trailing `.dart` to `_test.dart` (shared `mirrorTestFor`, also
serving changed-tests selection). Only existence is checked —
never contents. The rule runs only when the nearest
`flutterguard.yaml` carries a `test_presence:` map (present and
empty still opts in, the LOG-019 presence rule).

- Uncovered lib file: MUST be flagged, on line 1.
  [eval: TC-33.bad]
- Covered lib file: MUST NOT be flagged. [eval: TC-33.good]
- Uncovered lib file without the section: MUST NOT be
  flagged (opt-in). [eval: unit fixture]
- `test_presence: {}` enables; bare `test_presence:` (null)
  and malformed configs stay silent. [eval: unit fixture]
- `lib/main.dart` uncovered: MUST NOT be flagged
  (entrypoint wiring). [eval: unit fixture]
- `lib/src/main.dart` uncovered: MUST be flagged (only the
  `lib/`-root entrypoint is exempt). [eval: unit fixture]
- Generated files (`lib/foo.g.dart`): MUST NOT be flagged.
  [eval: unit fixture]
- Non-lib files (`tool/`, `bin/`, `test/`): MUST NOT be
  flagged. [eval: unit fixture]
- Monorepo mirrors (`packages/a/lib/x.dart` →
  `packages/a/test/x_test.dart`): mapped, flagged when the
  mirror is missing. [eval: unit fixture]
- Flat/colocated layouts: flagged when the mirror is
  missing (v0 is mirror-only — projects on other layouts
  stay silent by omitting the section). [unevaluated]
- `except`/`message` keys: reserved v1 surface, ignored v0
  (the baseline already ratchets legacy trees).
  [unevaluated]

`write_mirror_test` is model-owned per the SYS-HEAL-001 closed
fast-path list (a meaningful test needs intent no patch owns);
the harness never attempts it as a fast-path patch.
[unevaluated]
