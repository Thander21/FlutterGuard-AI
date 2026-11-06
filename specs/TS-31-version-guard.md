---
spec_version: "openspec-1.0"
id: "FG-VER-031"
title: "pubspec version must be semver"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(YAML loadYamlNode: top-level version scalar vs semver)"
invariant: "A `pubspec.yaml` that carries a `version:` key MUST spell it as `X.Y.Z` with an optional `-pre`/`+build` suffix — anything else breaks versioning, publishing, and release tooling."
fp_limits:
  - "valid X.Y.Z versions with -pre and +build suffixes"
  - "pubspecs without a version: key (fail-open)"
  - "unparseable pubspecs (fail-open)"
  - "non-pubspec yaml files (out of scope)"
golden_vectors:
  failing: "benchmark/vectors/TC-31_ver.bad.yaml"
  passing: "benchmark/vectors/TC-31_ver.good.yaml"
auto_heal_strategy: "model-owned"
---

# 1. Anti-Pattern Diagnosis

AI-generated scaffolds write `version: 1.2` (a YAML float, not a
version), `version: latest`, or `version: 1.2.3.4` — and `pub`
rejects the package at the worst moment: publish time, or when a
release workflow parses the tag. The campodeforca `VersionFormat`
gate (SYS-CAL-003 R2-5 medium list) pins the shape; this rule is
that gate, universal and config-free. One finding on the
`version:` line; a missing key stays silent (not every pubspec
ships a version).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   name: shop
-  version: 1.2
+  version: 1.2.0
```

# 3. Edge Cases and Non-Compliance

The `version` node MUST be a YAML string matching
`^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$`. Non-string scalars
(`version: 1.2` parses as a double) fail the string test before
the regex runs. Findings name the value as written.

- Two-part version (`version: 1.2`): MUST be flagged, on the
  version line. [eval: TC-31.bad]
- Free text (`version: latest`): MUST be flagged.
  [eval: unit fixture]
- Four-part version (`version: 1.2.3.4`): MUST be flagged.
  [eval: unit fixture]
- Integer version (`version: 2`): MUST be flagged.
  [eval: unit fixture]
- Empty version (`version:`): MUST be flagged (a present key
  with no value is not a version). [eval: unit fixture]
- `1.2.3`, `0.1.0`, `2.0.0-rc.1`, `1.0.0+42`: MUST NOT be
  flagged. [eval: TC-31.good, unit fixture]
- Missing `version:` key: MUST NOT be flagged (fail-open).
  [eval: unit fixture]
- Unparseable YAML: silent (fail-open — the breakage is not a
  version verdict; `pub get` owns it). [eval: unit fixture]
- CRLF line endings: tolerated. [eval: unit fixture]
- Non-pubspec yaml files: never evaluated (the exact-basename
  walk scope keeps them out of `check`; direct visitor calls are
  the grader's business). [eval: unit fixture]

`bump_pubspec_version` is model-owned per the SYS-HEAL-001
closed fast-path list (the next version number is a release
decision, never a mechanical patch); the harness never attempts
it as a fast-path patch. [unevaluated]
