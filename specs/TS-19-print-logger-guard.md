---
spec_version: "openspec-1.0"
id: "FG-LOG-019"
title: "Print calls must route through the logger"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[target=null]"
invariant: "Every bare `print`/`debugPrint` call — plus configured extra symbols — MUST NOT appear outside the `print_logger` `except` files; without the section the rule is silent."
fp_limits:
  - "files with no print_logger section (silent default)"
  - "calls through the project logger (any non-print name)"
  - "dotted and prefixed calls (bare-only v1)"
  - "tear-offs and bare references (invocations only)"
  - "comments and string literals"
  - "uses inside except files"
golden_vectors:
  failing: "benchmark/vectors/tc19/TC-19_log.bad.dart"
  passing: "benchmark/vectors/tc19/TC-19_log.good.dart"
auto_heal_strategy: "route_through_logger"
---

# 1. Anti-Pattern Diagnosis

A stray `print` in shipped code is invisible in review and useless
in production: no level, no sink, no sampling — and on Flutter,
`debugPrint` throttling makes output lossy exactly when traffic
peaks. AI-generated code scatters prints because the preview
rewards them. The campodeforca `PrintLogger` gate (SYS-CAL-003
R2-5) bans `print`/`debugPrint` outside the project logger; this
rule is that mechanism, parse-only, with a configurable symbol
set and logger location.

The rule is opt-in by section presence: with no `print_logger`
section anywhere it is silent (stock `avoid_print` already
covers the universal case, and settled goldens such as TC-11
deliberately exercise print-plus-suppression interplay). A
present section — even an empty map — bans bare `print` and
`debugPrint` plus the configured extra `symbols`, everywhere
outside `except`. Discovery, merging (nearest wins), and
malformed-field behavior follow SYS-CLI-001a §2: additive
fields degrade leniently, never shrinking the gate.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   void submitOrder(Order order) {
-    print('submitting ${order.id}');
+    AppLogger.info('submitting ${order.id}');
   }
```

The logger implementation itself goes in `except`.

# 3. Edge Cases and Non-Compliance

A use is a bare call: `MethodInvocation` with `target == null`
whose name is `print`, `debugPrint`, or a configured extra
symbol — case-sensitive, invocation-only.

- Bare `print('x')`: MUST be flagged. [eval: TC-19.bad]
- Bare `debugPrint('x')`: MUST be flagged. [eval: TC-19.bad]
- Configured extra `tattle('x')`: MUST be flagged.
  [eval: TC-19.bad]
- `logger.info(...)` (project logger): MUST NOT be flagged.
  [eval: TC-19.good]
- `AppLogger.info(...)`: MUST NOT be flagged.
  [eval: TC-19.good]
- Tear-off `print`: MUST NOT be flagged. [eval: TC-19.good]
- `'print'` string: MUST NOT be flagged. [eval: TC-19.good]
- `// print` comment: MUST NOT be flagged (AST, not text).
  [eval: unit fixture]
- `stderr.writeln(...)`: MUST NOT be flagged (v1 bare-only).
  [eval: unit fixture]
- Bare `log('x')`: MUST NOT be flagged unless configured
  (default set is `print`/`debugPrint` only). [eval: unit
  fixture]
- Bare `log('x')` with `symbols: [log]`: MUST be flagged.
  [eval: unit fixture]
- File matching `except`: MUST NOT be flagged. [eval: unit
  fixture (temp project)]
- Empty-map section enables the default set. [eval: unit
  fixture (temp project)]
- Malformed `symbols`/`except` degrade leniently (defaults
  still flag). [eval: unit fixture (temp project)]
- Custom `message` surfaces in the violation. [eval: unit
  fixture]
- Unconfigured file using `print(...)`: MUST NOT be flagged
  (silent default). [eval: unit fixture]
- Shadowed locals (`final print = ...; print('x')`) flag
  (known FP — no shadowing tracking in v1).
  [unevaluated]
- Default-set removal (un-banning `print`): NOT supported
  in v1 (`except` or rule disable covers it).
  [unevaluated]
- Dotted bans (`stderr.writeln`): NOT supported in v1.
  [unevaluated]

`route_through_logger` is model-owned per the SYS-HEAL-001
closed fast-path list (the replacement needs project
knowledge — which logger, which level); the harness never
attempts it as a fast-path patch. [unevaluated]
