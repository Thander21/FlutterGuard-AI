---
spec_version: "openspec-1.0"
id: "FG-IMP-015"
title: "No illegal imports or exports"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "ImportDirective[uri='dart:mirrors']"
  - "ExportDirective[uri='dart:mirrors']"
  - "ImportDirective[relative uri escaping lib/]"
  - "ExportDirective[relative uri escaping lib/]"
invariant: "No import or export directive may reference dart:mirrors or relatively escape the package lib/ directory."
fp_limits:
  - "package: and dart: (non-mirrors) URIs are never flagged"
  - "relative imports staying inside lib/ are never flagged"
  - "files outside any lib/ directory never flag for escape (unjudgeable parse-only)"
  - "part and part-of directives are out of scope (same-library mechanics)"
  - "'dart:mirrors' in strings or comments is never flagged (directives only)"
  - "absolute and file: URIs are never flagged (not relative; existence needs resolution)"
golden_vectors:
  failing: "benchmark/vectors/TC-15_imp.bad.dart"
  passing: "benchmark/vectors/TC-15_imp.good.dart"
auto_heal_strategy: "rewrite_import"
---

# 1. Anti-Pattern Diagnosis

AI generators trained on server-side Dart emit `dart:mirrors`
imports that compile nowhere near Flutter (reflection is banned on
mobile; the import breaks every Flutter build at compile time).
They also emit relative imports that climb out of `lib/` (e.g.
`lib/ui/page.dart` importing `../tool/debug.dart`), which silently
works on the author's machine but breaks package encapsulation:
consumers of the published package cannot resolve files outside
`lib/`, and `pub publish` rejects or strands the code. Both shapes
are parse-only decidable from the directive URI plus the file path,
so they belong in `validate-light` per SYS-CLI-001a §2.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
- import 'dart:mirrors';
+ // Reflection is unavailable on Flutter; use explicit
+ // serialization (json_serializable) or code generation instead.
```

```diff
   // lib/ui/page.dart
-  import '../tool/debug.dart';
+  import 'package:myapp/tool/debug.dart';
```

# 3. Edge Cases and Non-Compliance

- `import 'dart:mirrors'`: MUST be flagged. [eval: TC-15.bad]
- `export 'dart:mirrors'`: MUST be flagged (re-export exposes it
  to consumers). [eval: TC-15.bad]
- Relative import resolving outside the nearest ancestor `lib/`
  directory: MUST be flagged. [eval: unit fixture]
- Relative export resolving outside the nearest ancestor `lib/`
  directory: MUST be flagged. [eval: unit fixture]
- `package:` imports/exports (any package, incl. self): MUST NOT
  be flagged (layer policy belongs to FG-ARCH-003).
  [eval: TC-15.good]
- `dart:` imports other than mirrors (`dart:async`, `dart:io`,
  `dart:convert`): MUST NOT be flagged. [eval: TC-15.good]
- Relative imports staying inside `lib/`: MUST NOT be flagged.
  [eval: unit fixture]
- Files outside any `lib/` directory (tests, tools, vectors):
  MUST NOT be flagged for escape — package context is
  unjudgeable parse-only. [eval: TC-15.good]
- `part` / `part of` directives: MUST NOT be flagged (same-library
  mechanics, out of scope). [eval: TC-15.good]
- `data:` and other non-file schemes: MUST NOT be flagged.
  [eval: TC-15.good]
- `'dart:mirrors'` inside a string literal or comment: MUST NOT be
  flagged (directives only). [eval: TC-15.good]
- Conditional URIs (`import 'x' if (...) 'dart:mirrors'`): each
  configuration URI is judged like the main one, flagged at its
  own line. [eval: unit fixture]
- Absolute (`/x/y.dart`) and `file:` URIs: MUST NOT be flagged
  (not relative). [eval: unit fixture]
- Ancestor matching is the exact lowercase segment `lib`
  (`LIB/` never counts): MUST be exact. [eval: unit fixture]
- Nested `lib/` directories resolve against the nearest ancestor.
  [eval: unit fixture]
- Only the URI string is judged; whether the target exists is
  irrelevant (existence needs resolution). [unevaluated]

`rewrite_import` is model-owned per the SYS-HEAL-001 closed
fast-path list (the replacement needs judgment: delete the import,
retarget to a `package:` URI, or restructure); the harness never
attempts it as a fast-path patch. [unevaluated]
