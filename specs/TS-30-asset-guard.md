---
spec_version: "openspec-1.0"
id: "FG-ASSET-030"
title: "pubspec assets must exist on disk"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(YAML loadYamlNode: flutter.assets entries vs the filesystem)"
invariant: "Every entry under `flutter: assets:` in a `pubspec.yaml` MUST resolve to an existing file or directory next to that pubspec — a declared asset that is missing crashes the app at runtime."
fp_limits:
  - "entries that resolve (files and trailing-slash directories)"
  - "pure-Dart pubspecs (no flutter: section) and missing assets: keys"
  - "unparseable pubspecs (fail-open) and non-string entries"
  - "files never declared (the vice-versa direction is v0-deferred)"
  - "the fonts: section and non-pubspec yaml files (out of scope v0)"
golden_vectors:
  failing: "benchmark/vectors/tc30/bad/pubspec.yaml"
  passing: "benchmark/vectors/tc30/good/pubspec.yaml"
auto_heal_strategy: "model-owned"
---

# 1. Anti-Pattern Diagnosis

AI-generated UI work adds `assets/images/logo.png` to the
`flutter: assets:` list and forgets to create the file — or
renames the file and forgets the declaration. The app compiles,
ships, and throws "Unable to load asset" on the exact screen the
demo opens. The campodeforca `Assets` gate (SYS-CAL-003 R2-5
medium list) requires declared assets to exist; this rule is
that gate, universal and config-free. One finding per missing
entry, on the entry's line.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   flutter:
     assets:
-      - assets/images/missing.png
+      - assets/images/logo.png
```

# 3. Edge Cases and Non-Compliance

Entries resolve relative to the analyzed pubspec's directory. A
trailing `/` entry MUST be an existing directory; any other
entry MUST be an existing file. Line numbers come from the YAML
node spans. Findings name the entry as written.

- Missing file entry: MUST be flagged, on the entry's line.
  [eval: TC-30.bad]
- Missing directory entry (trailing `/`): MUST be flagged, on
  the entry's line. [eval: TC-30.bad]
- Existing file and existing directory entries: MUST NOT be
  flagged. [eval: TC-30.good]
- Undeclared files sitting next to declared assets: MUST NOT
  be flagged (the vice-versa direction needs a project asset-root
  surface — deferred to v1, no literals in v0). [eval: TC-30.good]
- Missing `flutter:` section or missing `assets:` key: silent
  (pure-Dart packages declare no Flutter assets).
  [eval: unit fixture]
- Unparseable YAML: silent (fail-open — the breakage is not an
  asset verdict; `pub get` owns it). [eval: unit fixture]
- Non-string entries (numbers, maps, nulls): skipped.
  [eval: unit fixture]
- `flutter: fonts:` assets with missing files: MUST NOT be
  flagged (out of scope v0). [eval: unit fixture]
- CRLF line endings: tolerated. [eval: unit fixture]
- Absolute entries (`/x`, `C:\x`): skipped (meaningless to
  Flutter, and resolving them reads outside the package).
  [unevaluated]
- `~` and `$VAR` expansion: never performed (literal
  resolution only). [unevaluated]
- Non-pubspec yaml files: never evaluated (the exact-basename
  walk scope keeps them out of `check`; direct visitor calls are
  the grader's business). [eval: unit fixture]

`sync_pubspec_assets` is model-owned per the SYS-HEAL-001 closed
fast-path list (dropping a declaration the app needs breaks the
app, and inventing the missing file is a product decision — both
need a human); the harness never attempts it as a fast-path
patch. [unevaluated]
