---
spec_version: "openspec-1.0"
id: "FG-TOK-020"
title: "Hardcoded design tokens"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "InstanceCreationExpression"
  - "MethodInvocation[constructor-shaped]"
invariant: "Every `Color` construction — unnamed or channel ctors by default, plus configured extra_ctors — MUST NOT appear outside the `theme_tokens` `except` files."
fp_limits:
  - "theme tokens (properties, scheme lookups — never constructions)"
  - "Colors.* swatches (property access)"
  - "non-channel named ctors (Color.lerp, ...)"
  - "geometry literals by default (BorderRadius/EdgeInsets — extras-only)"
  - "uses inside except files"
golden_vectors:
  failing: "benchmark/vectors/TC-20_tok.bad.dart"
  passing: "benchmark/vectors/TC-20_tok.good.dart"
auto_heal_strategy: "route_through_theme"
---

# 1. Anti-Pattern Diagnosis

A literal `Color(0xFF0000)` in a widget bypasses the theme: dark
mode, branding, and contrast fixes all live in the color scheme,
and every hardcoded channel re-forks them. AI-generated UI emits
literal colors because the preview looks right in exactly one
configuration. The campodeforca `HardcodedColors`/`DesignTokens`
gates (SYS-CAL-003 R2-5) forbid raw colors, radii, and spacing
outside the theme; this rule is that mechanism, parse-only.

Unlike FG-BAN-018/FG-LOG-019, this rule defaults ON: a `Color`
construction is never valid outside a theme file, and pure-Dart
code never constructs one — so the default needs no opt-in.
Unnamed `Color(...)` (any argument, fail-closed) and the channel
ctors `fromARGB`/`fromRGBO` flag; anything else named
(`Color.lerp`, ...) passes. Radius and spacing stay extras-only
(`EdgeInsets.all(8)` is idiomatic enough to sit in settled
goldens): projects add `Type` or `Type.ctor` entries under
`extra_ctors`, and hang their theme location on `except`.
Discovery, merging (nearest wins), and lenient degrade follow
SYS-CLI-001a §2.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   Tile(
-    color: Color(0xFF0000),
+    color: Theme.of(context).colorScheme.error,
   )
```

# 3. Edge Cases and Non-Compliance

A use is an `InstanceCreationExpression` or a
constructor-shaped call whose simple type is `Color` with an
unnamed, `fromARGB`, or `fromRGBO` constructor — or whose
`Type`/(`Type`, `ctor`) matches an `extra_ctors` entry.
Prefixed `p.Color(...)` flags prefix-agnostic (whole-type
only — prefixed calls carry no ctor name).

- `Color(0xFF0000)`: MUST be flagged. [eval: TC-20.bad]
- `const Color.fromARGB(...)`: MUST be flagged.
  [eval: TC-20.bad]
- `Color.fromRGBO(...)`: MUST be flagged. [eval: TC-20.bad]
- `theme.primary`: MUST NOT be flagged. [eval: TC-20.good]
- `Colors.red`: MUST NOT be flagged (property access).
  [eval: TC-20.good]
- `Color.lerp(...)`: MUST NOT be flagged (not a channel
  ctor). [eval: TC-20.good]
- `BorderRadius.circular(8)`: MUST NOT be flagged by
  default. [eval: TC-20.good]
- `EdgeInsets.all(8)`: MUST NOT be flagged by default.
  [eval: TC-20.good]
- `Color(value)` (variable): MUST be flagged (fail-closed).
  [eval: unit fixture]
- `ui.Color(0xFF0000)` (prefixed): MUST be flagged.
  [eval: unit fixture]
- `ColorScheme.fromSeed(...)`: MUST NOT be flagged (not
  `Color`). [eval: unit fixture]
- `'Color(0xFF0000)'` string / comment: MUST NOT be
  flagged (AST, not text). [eval: unit fixture]
- File matching `except`: MUST NOT be flagged. [eval: unit
  fixture (temp project)]
- `extra_ctors: [BorderRadius.circular]`: MUST flag
  `BorderRadius.circular(8)` but NOT `BorderRadius.only`.
  [eval: unit fixture (temp project)]
- `extra_ctors: [EdgeInsets]` (whole-type): MUST flag
  `EdgeInsets.all(8)`. [eval: unit fixture (temp
  project)]
- Malformed extras (`bad..entry`, `""`, non-strings,
  lowercase types) are ignored. [eval: unit fixture]
- Custom `message` surfaces in the violation. [eval: unit
  fixture]
- Same-file `class Color` carve-out: none in v1 (a
  project-defined `Color` still flags; `except` covers
  it). [unevaluated]
- `Colors.red` swatch matching: NOT in v1 (properties
  never match). [unevaluated]

`route_through_theme` is model-owned per the SYS-HEAL-001
closed fast-path list (the replacement needs project
knowledge — which token, which scheme); the harness never
attempts it as a fast-path patch. [unevaluated]
