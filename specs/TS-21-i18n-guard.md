---
spec_version: "openspec-1.0"
id: "FG-I18N-021"
title: "Hardcoded strings in text widgets"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "InstanceCreationExpression"
  - "MethodInvocation[constructor-shaped]"
invariant: "Every Text construction (plus configured widgets) with literal text MUST NOT appear outside the `i18n` `except` files; without the section the rule is silent."
fp_limits:
  - "files with no i18n section (silent default)"
  - "Text with non-literal data (variables, lookups)"
  - "empty, blank, and pure-interpolation literals"
  - "non-text widgets with literals"
  - "uses inside except files"
golden_vectors:
  failing: "benchmark/vectors/tc21/TC-21_i18n.bad.dart"
  passing: "benchmark/vectors/tc21/TC-21_i18n.good.dart"
auto_heal_strategy: "move_to_l10n"
---

# 1. Anti-Pattern Diagnosis

A `Text('Hello')` ships untranslatable: every locale the app
later adds must hunt string literals scattered through widget
trees, and AI-generated UI emits them by default. The
campodeforca `i18n` gate (SYS-CAL-003 R2-5) requires widget
strings to come from the l10n catalog; this rule is that
mechanism, parse-only.

The rule is opt-in by section presence (like FG-LOG-019): a
present `i18n` map — even empty — bans literal text in `Text`
plus the configured extra `widgets`, everywhere outside
`except`. Literal text is a non-blank simple, interpolated
(with literal chunks), or adjacent literal in the first
positional argument. Discovery, merging (nearest wins), and
lenient degrade follow SYS-CLI-001a §2.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   Widget build(BuildContext context) {
-    return Text('Hello');
+    return Text(AppLocalizations.of(context).hello);
   }
```

# 3. Edge Cases and Non-Compliance

A use is a construction (bare, `const`, or prefixed —
prefix-agnostic) of `Text` or a configured widget whose first
positional argument carries non-blank literal text: a
`SimpleStringLiteral` with non-blank value, a
`StringInterpolation` with a non-blank literal chunk, or
adjacent literals with non-blank combined text.

- `Text('Hello')`: MUST be flagged. [eval: TC-21.bad]
- `Text('Hi $name')`: MUST be flagged (literal chunk).
  [eval: TC-21.bad]
- `SelectableText('Copy me')` (configured): MUST be flagged.
  [eval: TC-21.bad]
- `Text(t.greeting)`: MUST NOT be flagged. [eval: TC-21.good]
- `Text('')`: MUST NOT be flagged (empty). [eval: TC-21.good]
- `Text('  ')`: MUST NOT be flagged (blank spacer).
  [eval: TC-21.good]
- `Text('$name')`: MUST NOT be flagged (pure interpolation,
  no literal text). [eval: TC-21.good]
- `Label('x')` (unconfigured): MUST NOT be flagged.
  [eval: TC-21.good]
- `const Text('x')`: MUST be flagged. [eval: unit fixture]
- `ui.Text('x')` (prefixed): MUST be flagged.
  [eval: unit fixture]
- `Text('a' 'b')` (adjacent): MUST be flagged. [eval: unit
  fixture]
- File matching `except`: MUST NOT be flagged. [eval: unit
  fixture (temp project)]
- Empty-map section enables the default set. [eval: unit
  fixture (temp project)]
- Malformed `widgets` degrade leniently (Text still
  flags). [eval: unit fixture (temp project)]
- Custom `message` surfaces in the violation. [eval: unit
  fixture]
- Unconfigured file using `Text('x')`: MUST NOT be flagged
  (silent default). [eval: unit fixture]
- Parenthesized/cast/transformed literals (`('x')`, `'x'
  as String`, `'x'.toUpperCase()`) are not unwrapped in v1.
  [unevaluated]
- Named-arg spans (`TextSpan(text: 'x')`): NOT tracked in
  v1 (first positional only). [unevaluated]
- `Text.rich(...)`: NOT tracked in v1. [unevaluated]

`move_to_l10n` is model-owned per the SYS-HEAL-001 closed
fast-path list (the replacement needs project knowledge —
which catalog key, which placeholders); the harness never
attempts it as a fast-path patch. [unevaluated]
