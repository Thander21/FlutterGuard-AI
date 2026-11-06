---
spec_version: "openspec-1.0"
id: "FG-ORP-023"
title: "Orphaned generated files"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(path oracle: no AST node; generated-suffix match plus source-sibling existence)"
invariant: "Every generated-suffix file (.g/.freezed/.gr/.mocks) MUST have its source sibling (suffix stripped + .dart) present."
fp_limits:
  - "generated files with their source sibling"
  - "non-generated files (suffix rule only)"
golden_vectors:
  failing: "benchmark/vectors/tc23/stray_widget.g.dart"
  passing: "benchmark/vectors/tc23/paired_widget.g.dart"
auto_heal_strategy: "delete_orphan"
---

# 1. Anti-Pattern Diagnosis

A source file gets deleted; its `.g.dart` stays behind. The
orphan still compiles (nobody imports it), still confuses
searches, and — worst — still gets resurrected by a careless
`git checkout`. AI agents are prolific orphan-makers: they
delete and move sources without sweeping the generated
companions. Now that `check` skips generated files, the
campodeforca `OrphanGenFiles` gate (SYS-CAL-003 R2-5) is the
natural complement: every `.g.dart`/`.freezed.dart`/`.gr.dart`/
`.mocks.dart` must have its source sibling next to it.

The check is per-file and universal (no config — sibling
existence is never project-varying): strip the generated
suffix, append `.dart`, require the sibling. Generated files
stay skipped by default scans (that rule is unchanged); this
gate judges them when collected — directly (as `grade` does)
or under `--include-generated`.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
-  lib/user.g.dart          (orphan — lib/user.dart is gone)
+  (deleted; regenerate with build_runner after restoring the source)
```

Confirm the source is truly gone — not a `build.yaml`
redirect — then delete the orphan.

# 3. Edge Cases and Non-Compliance

- Orphan `.g.dart` (no sibling): MUST be flagged.
  [eval: TC-23.bad]
- Paired `.g.dart` (sibling present): MUST NOT be flagged.
  [eval: TC-23.good]
- The source file itself: MUST NOT be flagged. [eval: unit
  fixture]
- Orphan `.freezed.dart`: MUST be flagged. [eval: unit
  fixture]
- Orphan `.gr.dart`: MUST be flagged. [eval: unit fixture]
- Orphan `.mocks.dart`: MUST be flagged. [eval: unit
  fixture]
- Plain `.dart` (no generated suffix): MUST NOT be flagged.
  [eval: unit fixture]
- Default scans skip generated files (the orphan vectors
  are invisible to them); `--include-generated` judges the
  tc23 tree with exactly the orphan flagged. [eval: unit
  fixture (check_test)]
- `build.yaml`-redirected outputs may false-positive (no
  build awareness in v1 — the source lives elsewhere by
  design). [unevaluated]
- `except` support: none in v1 (universal gate, like
  FG-SYN-017/FG-FMT-016). [unevaluated]

`delete_orphan` is model-owned per the SYS-HEAL-001 closed
fast-path list (deletion needs provenance judgment — the
harness never deletes files on its own); the heal stays a
human-confirmed removal. [unevaluated]
