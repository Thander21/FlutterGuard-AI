---
spec_version: "openspec-1.0"
id: "FG-ENC-022"
title: "Sources must be clean UTF-8"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(byte oracle: no AST node; strict UTF-8 decode plus a mojibake scan over the file bytes)"
invariant: "Every scanned file decodes as strict UTF-8 and contains no mojibake markers (U+FFFD, U+00C3, U+00C2)."
fp_limits:
  - "legitimate accented text (ã, õ, ç, é, Ê — never the marker codepoints)"
  - "pure-ASCII files"
golden_vectors:
  failing: "benchmark/vectors/TC-22_enc.bad.dart"
  passing: "benchmark/vectors/TC-22_enc.good.dart"
auto_heal_strategy: "reencode_utf8"
---

# 1. Anti-Pattern Diagnosis

A file saved as Latin-1 (or pasted through a mis-decoding
editor) compiles fine and corrupts silently: `cafÃ©` renders
where `café` should, string comparisons fail, and on Windows
the default code page makes this a recurring incident — in
PT-BR codebases most of all. The campodeforca `Encoding` gate
(SYS-CAL-003 R2-5) requires valid UTF-8 and flags mojibake;
this rule is that mechanism, byte-level.

The check is twofold and universal (no config — bytes are
never project-varying): strict UTF-8 decode must succeed, and
the decoded text must contain none of the three marker
codepoints — U+FFFD (replacement character), U+00C3 (Ã), and
U+00C2 (Â). Legitimate accented text never trips it: ã is
U+00E3, õ is U+00F5, ç is U+00E7 — the markers are the
Latin-1 ghosts of multi-byte sequences, not the letters
themselves. Files that fail to decode also trip FG-SYN-017
(the verdicts are distinct — re-encode vs fix syntax — and
both stay actionable).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
-  // Relat<U+00C3><U+00B3>rio de vendas
+  // Relatório de vendas
```

Re-save the file as UTF-8 (the mojibake above is Latin-1-read
UTF-8: U+00C3 U+00B3 is the ghost of `ó`). Markers are spelled
as codepoints here: a literal marker in this section would ride
the recipe embed into `lib/` and flag the repo itself.

# 3. Edge Cases and Non-Compliance

One violation per affected line (same-line hits dedupe); the
message names the first marker found. Decode failure reports
line 1 (byte offsets are unmappable).

- `cafÃ©` in a comment: MUST be flagged. [eval: TC-22.bad]
- `'cafÃ©'` in a string: MUST be flagged. [eval: TC-22.bad]
- `coração`, `avião`, `maçã`: MUST NOT be flagged.
  [eval: TC-22.good]
- `Êxodo` (U+00CA, not Â): MUST NOT be flagged.
  [eval: TC-22.good]
- Invalid UTF-8 bytes: MUST be flagged at line 1. [eval:
  unit fixture (raw bytes)]
- U+FFFD content: MUST be flagged. [eval: unit fixture]
- `Â ` (U+00C2 + space): MUST be flagged. [eval: unit
  fixture]
- Two markers on one line: MUST flag once (dedupe). [eval:
  unit fixture]
- Multi-line hits report each line. [eval: unit fixture]
- Pure-ASCII file: MUST NOT be flagged. [eval: unit
  fixture]
- A `part of` header with markers: still flagged (bytes
  don't care about directives). [unevaluated]
- `except` support: none in v1 (universal byte gate, like
  FG-SYN-017/FG-FMT-016). [unevaluated]

`reencode_utf8` is model-owned per the SYS-HEAL-001 closed
fast-path list (re-encoding needs judgment — the source
encoding is unknown, and guessing destroys text); the harness
never attempts it as a fast-path patch. [unevaluated]
