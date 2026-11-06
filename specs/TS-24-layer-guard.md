---
spec_version: "openspec-1.0"
id: "FG-LYR-024"
title: "Layer direction rules"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "ImportDirective[uri]"
  - "ExportDirective[uri]"
invariant: "Every import/export whose URI matches a deny_imports glob in a file matching that rule's files MUST NOT appear outside the rule's except files; without a layer_rules section the rule is silent."
fp_limits:
  - "files with no layer_rules section (silent default)"
  - "files outside every files scope"
  - "imports matching no deny glob"
  - "uses inside except files"
golden_vectors:
  failing: "benchmark/vectors/tc24/ui/TC-24_layer.bad.dart"
  passing: "benchmark/vectors/tc24/data/TC-24_layer.good.dart"
auto_heal_strategy: "route_through_layer"
---

# 1. Anti-Pattern Diagnosis

Layer erosion starts with one convenient import: a widget
pulls `package:drift` directly instead of going through the
repository, and the architecture leaks one file at a time.
AI-generated code accelerates it — the model imports whatever
completes the snippet. The campodeforca layer gates
(SYS-CAL-003 R2-5) make direction configurable; this rule is
the v1 mechanism: file-scoped import/export denylists
(`files` globs select the capped files, `deny_imports` globs
match URI strings as written — no resolution, no
normalization).

The full allow-graph (named layers plus edge allowlists) is
the designed v2, deferred with open identity questions: which
imports are "layered" (relative? own-package — unknowable
parse-only? `dart:`/`flutter:` auto-allowed by magic?),
what unlayered files mean, and how overlapping layers rank.
Deny-rules answer the same user need with none of the magic.
Discovery (nearest wins), malformed-rule skipping, and the
empty-scope rule follow SYS-CLI-001a §2.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   // lib/ui/users_page.dart
-  import 'package:drift/drift.dart';
+  import 'package:app/domain/users.dart';
```

# 3. Edge Cases and Non-Compliance

A use is an `ImportDirective` or `ExportDirective` whose URI
string matches a `deny_imports` glob of a rule whose `files`
globs match the analyzed file (config-relative) and whose
`except` globs do not. Rules with empty `files` or
`deny_imports` are skipped as malformed.

- Drift import in `ui/`: MUST be flagged.
  [eval: TC-24.bad]
- Drift import in `data/`: MUST NOT be flagged (out of
  scope). [eval: TC-24.good]
- File matching `except`: MUST NOT be flagged. [eval: unit
  fixture (temp project)]
- `export 'package:drift/...'` in scope: MUST be flagged.
  [eval: unit fixture]
- Relative `'../data/db.dart'` denied: MUST be flagged.
  [eval: unit fixture]
- `part 'x.dart'`: MUST NOT be flagged (same-library).
  [eval: unit fixture]
- `show` combinators don't matter (URI-level match).
  [eval: unit fixture]
- `dart:io` denied: MUST be flagged. [eval: unit fixture]
- Two rules matching one import: MUST flag twice (union).
  [eval: unit fixture]
- Malformed rules (non-map, missing/empty globs,
  non-string entries, bad `except`) are skipped.
  [eval: unit fixture]
- Custom `message` surfaces in the violation.
  [eval: TC-24.bad]
- Unconfigured file: MUST NOT be flagged (silent
  default). [eval: unit fixture]
- URI resolution/normalization: none in v1 (`./x.dart`
  vs `x.dart` differ). [unevaluated]
- Allow-graph (`layers` + edge allowlists): designed v2,
  deferred (see §1). [unevaluated]

`route_through_layer` is model-owned per the SYS-HEAL-001
closed fast-path list (the replacement needs project
knowledge — which layer owns the dependency); the harness
never attempts it as a fast-path patch. [unevaluated]
