---
spec_version: "openspec-1.0"
id: "FG-BAN-018"
title: "Banned project symbols"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "InstanceCreationExpression"
  - "MethodInvocation[target=null]"
  - "MethodInvocation[constructor-shaped]"
  - "NamedType"
invariant: "Every use of a configured banned symbol — a creation, a call, or a type reference naming it — MUST NOT appear outside the entry's `except` files; without a `banned_symbols` section the rule is silent."
fp_limits:
  - "files with no banned_symbols config (silent default)"
  - "uses inside except files"
  - "declarations of the banned name"
  - "import show/hide combinators"
  - "tear-offs and bare references (invocations only)"
  - "comments and string literals"
golden_vectors:
  failing: "benchmark/vectors/tc18/TC-18_ban.bad.dart"
  passing: "benchmark/vectors/tc18/TC-18_ban.good.dart"
auto_heal_strategy: "route_through_allowed_api"
---

# 1. Anti-Pattern Diagnosis

Every project has a service wrapper that AI code keeps bypassing:
notifications go through `NotificationService` (theming, testing,
analytics in one place), but generated code reaches for the
convenient global — a bare `SnackBar` here, a rogue `trace` there.
Each bypass compiles and previews fine, and each one silently
re-forks behavior the project centralized on purpose. The
campodeforca `BannedAPIs`/`BannedUIAPIs` gates (SYS-CAL-003 R2-5)
solve this with a configurable symbol denylist plus per-file
exceptions (`SnackBar` banned everywhere except the notification
service); this rule is that mechanism, parse-only.

Matching is name-based and opt-in. The rule self-loads the
`banned_symbols` section of the nearest `flutterguard.yaml`
(SYS-CLI-001a §2, shared walk-up discovery): a creation, call, or
type reference whose simple name equals a configured `symbol`
flags, unless the file matches the entry's `except` globs. With
no section anywhere the rule is silent — a project that never
opts in never hears from it. Nearest config wins entirely (no
merging); malformed entries are skipped silently per CLI-001a
§5 (config problems are never file verdicts).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   void submitOrder(BuildContext context) {
-    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved')));
+    NotificationService.showSuccess(context, 'Saved');
   }
```

The service file itself goes in the entry's `except` list.

# 3. Edge Cases and Non-Compliance

A use is an `InstanceCreationExpression`, a bare call
(`target == null`), a constructor-shaped call (`S(...)`,
`S.named(...)`, `p.S(...)`), or a `NamedType` — matched on the
simple name, prefix-agnostic, case-sensitive. Import show/hide
combinators are `SimpleIdentifier`s, declarations bind names
rather than using them, and tear-offs never invoke — none of
those are uses, structurally.

- Bare `SnackBar(...)` creation: MUST be flagged.
  [eval: TC-18.bad]
- `const SnackBar(...)`: MUST be flagged. [eval: TC-18.bad]
- Nested `showSnackBar(SnackBar(...))`: MUST be flagged (the
  inner creation). [eval: TC-18.bad]
- Prefixed `ui.SnackBar(...)`: MUST be flagged
  (prefix-agnostic). [eval: TC-18.bad]
- Bare `trace('x')` call: MUST be flagged. [eval: TC-18.bad]
- Dotted `logger.trace(...)`: MUST NOT be flagged (v1 matches
  bare calls only). [eval: unit fixture]
- Return-type `SnackBar makeBar()`: MUST be flagged (type
  reference is coupling). [eval: unit fixture]
- `class MyBar extends SnackBar`: MUST be flagged.
  [eval: unit fixture]
- `show SnackBar` combinator: MUST NOT be flagged.
  [eval: TC-18.good]
- `class SnackBar` declaration: MUST NOT be flagged.
  [eval: TC-18.good]
- `NotificationService.showSuccess(...)` (allowed API): MUST
  NOT be flagged. [eval: TC-18.good]
- Dotted `logger.trace(...)`: MUST NOT be flagged.
  [eval: TC-18.good]
- Tear-off `onTap: trace`: MUST NOT be flagged (no
  invocation). [eval: TC-18.good]
- `'SnackBar'` string literal: MUST NOT be flagged.
  [eval: TC-18.good]
- `// SnackBar` comment: MUST NOT be flagged (AST, not
  text). [eval: unit fixture]
- File matching `except`: MUST NOT be flagged. [eval: unit
  fixture (temp project)]
- Nested configs: nearest wins, no merging. [eval: unit
  fixture (temp project)]
- Unconfigured file using `SnackBar(...)`: MUST NOT be
  flagged (silent default). [eval: unit fixture]
- Malformed entries (missing/non-string `symbol`, non-list
  `except`) are skipped silently. [eval: unit fixture]
- Custom `message` surfaces in the violation. [eval: unit
  fixture]
- Shadowed locals (`final trace = ...; trace('x')`) flag
  (known FP — no shadowing tracking in v1).
  [unevaluated]
- Constructor tear-off `SnackBar.new`: NOT flagged (no
  invocation). [unevaluated]
- Dotted config entries (`Logger.trace`): NOT supported in
  v1. [unevaluated]
- Same-file declaration carve-out: none in v1 (a banned
  name that is also declared still flags its uses).
  [unevaluated]

`route_through_allowed_api` is model-owned per the
SYS-HEAL-001 closed fast-path list (the replacement needs
project knowledge — which service, which method); the
harness never attempts it as a fast-path patch.
[unevaluated]
