---
spec_version: "openspec-1.0"
id: "FG-FMT-016"
title: "Sources must be dart-format clean"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(subprocess oracle: no AST node; `dart format` batch over the target files)"
invariant: "Every scanned file is byte-identical to DartFormatter output modulo line endings."
fp_limits:
  - "files the CLI reports unchanged are never flagged (the gate adds no verdict of its own)"
  - "unparseable files are never flagged (owned by FG-SYN-017)"
  - "formatter-stable files are never flagged (the oracle is exact)"
golden_vectors:
  failing: "benchmark/vectors/TC-16_fmt.bad.dart"
  passing: "benchmark/vectors/TC-16_fmt.good.dart"
auto_heal_strategy: "run_formatter"
---

# 1. Anti-Pattern Diagnosis

AI generators emit code with erratic spacing, indentation, and line
breaks. Unformatted code hides real defects in noisy diffs and
fails the human review gate of every serious Dart project (`dart
format` is the community standard). The check shells the ambient
SDK: one `dart format --output=none --set-exit-if-changed` batch
over the target files themselves, verdicts attributed from the
`Changed ` stdout lines (matched to inputs by normalized path;
an unmappable line throws — fail-loud). Running on the originals
preserves package context, so language-version resolution is
identical to a manual CLI run: skew is impossible by
construction, with one spawn per `check` run inside the
`validate-light` budget. Two designs were rejected: in-process
`dart_style` (3.x needs analyzer ^7+ vs the repo's ^6.0.0, 2.x
formats short style) and normalized temp copies (leaving the
package flips the language version and misjudges files). No
element model is involved and no dependency is added, so the rule
runs in `validate-light` per SYS-CLI-001a §2. It is not an AST
traversal — `analysis: parse-only` records the gate assignment
(no resolution), and the mechanism is stated here, not inferred.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   void main() {
-    print( 'hello'  );
+    print('hello');
   }
```

Run `dart format <file>` (or accept the formatter's output) to
heal; the gate compares against exactly that output.

# 3. Edge Cases and Non-Compliance

- Bad spacing/indentation that `dart format` would rewrite: MUST
  be flagged at line 1 (whole-file verdict). [eval: TC-16.bad]
- Formatter-stable files: MUST NOT be flagged. [eval: TC-16.good]
- Files differing only in line endings (CRLF vs LF): judged
  exactly as the CLI judges them (exit 0 today — verified); the
  gate adds no endings judgment of its own (originals only, no
  normalization). [eval: unit fixture]
- Unparseable files: MUST NOT be flagged (no `Changed` line is
  emitted for them; FG-SYN-017 owns the verdict, keeping `errors`
  empty per the `check` contract). [eval: unit fixture]
- Empty and whitespace-only files: flagged when the CLI reports
  `Changed` (CLI truth: the formatter rewrites them), never
  special-cased. [eval: unit fixture]
- Missing files: MUST throw from the read (`FileSystemException`),
  like every AST visitor — never silently clean.
  [eval: unit fixture]
- Formatter tool failure (exit outside {0, 1, 65}, missing SDK):
  MUST surface as a single report-only entry on the audited
  target — never findings (environmental failures are not code
  verdicts, SYS-CLI-001a §5), never per-file spam (one tool
  failure, one entry). Recorded decision. [unevaluated]
- Batch/per-file equivalence is guarded by a mapping test
  (batch findings equal the union of per-file CLI verdicts on
  mixed absolute-path fixtures, incl. an unparseable file and a
  CRLF file; relative-path attribution is pinned by the vectors
  run). No version skew is possible: the oracle is the ambient
  CLI on the original paths, and no formatter dependency is
  added. [eval: unit fixture]

`run_formatter` is model-owned per the SYS-HEAL-001 closed
fast-path list (the dispatcher has no whole-file patch shape; the
agent runs `dart format`); the harness never attempts it as a
fast-path patch. [unevaluated]
