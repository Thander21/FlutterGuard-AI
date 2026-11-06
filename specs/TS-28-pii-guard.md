---
spec_version: "openspec-1.0"
id: "FG-PII-028"
title: "PII in log calls must be masked"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "MethodInvocation[sink-shaped]"
  - "SimpleStringLiteral / AdjacentStrings / StringInterpolation"
  - "SimpleIdentifier / PropertyAccess (name sites)"
invariant: "Every call to a log sink (print/debugPrint plus configured sinks) MUST NOT carry unmasked PII — a literal span matching the email shape or a configured pattern, or an expression naming a PII name (defaults plus configured names) — outside except files; a PII site enclosed in a mask call (defaults plus configured masks) is masked."
fp_limits:
  - "log calls without PII (plain copy, counters, errors)"
  - "PII enclosed in a mask call (any depth, any target)"
  - "redacted literals ('***' — no pattern matches)"
  - "PII outside sink calls (assignments, UI text, comments)"
  - "method-call results (getEmail() — not traced)"
  - "uses inside except files"
golden_vectors:
  failing: "benchmark/vectors/tc28/TC-28_pii.bad.dart"
  passing: "benchmark/vectors/tc28/TC-28_pii.good.dart"
auto_heal_strategy: "mask_pii_at_log"
---

# 1. Anti-Pattern Diagnosis

AI-generated handlers log user objects wholesale — `print(user)`
today, the full e-mail, document number, and password hash in
the log aggregator tomorrow. Under LGPD/GDPR that aggregator
is a breach report waiting to happen. The campodeforca
`PiiLogging` gate (SYS-CAL-003 R2-5 tail T5) requires
document/e-mail/password PII in logs to be masked, with
configurable patterns; this rule is that gate. Defaults are
universal-only (the e-mail shape, the `email`/`password`
names, masking verbs) — document shapes and local names
(`cpf`, `senha`) vary by project and ship as config (SYS-07).
Default-ON is probe-justified: no e-mail-shaped literal
exists anywhere in the repo, and no settled vector or
dogfood root passes a PII name to a sink. Findings never echo
literal spans (the span IS the PII — kind only, plus the
line); identifiers echo (names are not values).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
-  print('contact ${user.email}');
+  print('contact ${mask(user.email)}');
```

# 3. Edge Cases and Non-Compliance

Sinks match by method simple name on any target (`print`,
`debugPrint`, configured `sinks`). Every argument of a sink
call is scanned: literal runs (each maximal literal span —
interpolation-split, adjacency-split) against the e-mail
shape plus configured `patterns`, and identifier sites
(simple names, property/prefix segments) against the PII
`names`. A site enclosed in a `masks` call at any depth is
masked. Findings land on the sink call line, one per site,
in document order. The e-mail shape is
`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`.

- `print` with an e-mail literal: MUST be flagged.
  [eval: TC-28.bad]
- `debugPrint` with a `${user.email}` interpolation: MUST be
  flagged. [eval: TC-28.bad]
- `print(password)` bare identifier: MUST be flagged.
  [eval: TC-28.bad]
- `print(user.cpf)` with configured `names: [cpf]`: MUST be
  flagged. [eval: TC-28.bad]
- Document-shaped literal with a configured `patterns`
  entry: MUST be flagged. [eval: TC-28.bad]
- Configured sink (`auditLog`) with PII: MUST be flagged.
  [eval: TC-28.bad]
- `print(mask(email))` default mask: MUST NOT be flagged.
  [eval: TC-28.good]
- Nested configured mask (`'${maskDoc(cpf)}'`): MUST NOT be
  flagged. [eval: TC-28.good]
- Redacted literals (`'***'`): MUST NOT be flagged.
  [eval: TC-28.good]
- Non-PII log content (`'hello $name'`, counters): MUST NOT
  be flagged. [eval: TC-28.good]
- E-mail literals outside sink calls (assignments, UI
  text): MUST NOT be flagged. [eval: TC-28.good]
- Findings never echo the literal span (kind + line only);
  identifiers echo. [eval: unit fixture]
- Malformed regex entries drop leniently (defaults still
  flag). [eval: unit fixture]
- Missing/non-map section: defaults still flag (default-ON).
  [eval: unit fixture]
- Uses inside `except` files: MUST NOT be flagged. [eval:
  unit fixture]
- Bare `log(...)`: NOT a default sink (dart:math
  ambiguity) — projects add it via `sinks`. [eval: unit
  fixture]
- Dotted sinks match by simple name (`logger.info` via
  `sinks: [info]`). [eval: unit fixture]
- Method-call results (`getEmail()`): NOT traced (exact
  identifier match only). [unevaluated]
- E-mails split across adjacent literals (`'a@b' '.com'`):
  missed (runs scan separately, never joined — no phantom
  matches across interpolation boundaries). [unevaluated]
- `stderr`/`stdout` writes: NOT default sinks (CLI surface,
  v0 out). [unevaluated]
- Shadowed sink names (a local named `print`): still
  scanned (no shadowing analysis, same as FG-BAN-018).
  [unevaluated]

`mask_pii_at_log` is model-owned per the SYS-HEAL-001 closed
fast-path list (placing the mask needs semantic judgment);
the harness never attempts it as a fast-path patch.
[unevaluated]
