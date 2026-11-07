---
spec_version: "openspec-1.0"
id: "FG-ENC-022"
title: "Sources must be clean UTF-8"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(byte oracle: no AST node; strict UTF-8 decode plus a mojibake scan over the file bytes)"
invariant: "Every scanned file decodes as strict UTF-8 and contains no mojibake sequence: U+FFFD, a lead ghost (U+00C3 or U+00C2) followed by a continuation-byte ghost (U+0080-U+00BF or the CP1252 rendering of bytes 0x80-0x9F), or U+00E2 U+20AC followed by a continuation-byte ghost."
fp_limits:
  - "legitimate accented text (ã, õ, ç, é, Ê — never the marker codepoints)"
  - "a lone U+00C3/U+00C2 as a real letter (uppercase PT-BR/FR words such as N<U+00C3>O, <U+00C2>NGULO; character tables) — only a lead ghost followed by a continuation-byte ghost flags"
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
the decoded text must contain no mojibake
sequence. UTF-8 read as Latin-1/CP1252 turns every 2-byte
letter into a lead ghost (U+00C3 or U+00C2) followed by a
continuation-byte ghost: a codepoint in U+0080-U+00BF, or the
CP1252 rendering of bytes 0x80-0x9F (U+20AC, U+201A, U+0192,
U+201E, U+2026, U+2020, U+2021, U+02C6, U+2030, U+0160,
U+2039, U+0152, U+017D, U+2018, U+2019, U+201C, U+201D,
U+2022, U+2013, U+2014, U+02DC, U+2122, U+0161, U+203A,
U+0153, U+017E, U+0178). The 3-byte smart-punctuation family
(curly quotes, dashes) becomes U+00E2 U+20AC followed by one
more continuation-byte ghost. U+FFFD (replacement character)
flags alone. Only the pair is evidence: U+00C3 and U+00C2 are
also real uppercase letters (PT-BR N<U+00C3>O, A<U+00C7><U+00C3>O, French
<U+00C2>NE, character tables), and a letter is never followed by a
continuation-byte ghost in real text — the next letter of a
word, an ASCII char, or U+00C0 and above. Lowercase accented
text (ã is U+00E3, õ U+00F5, ç U+00E7) never contains a lead
ghost at all. Known limit: a ghost whose continuation byte
was normalized away (U+00C3 followed by a plain space, the
ghost of à after NBSP stripping) is not caught. Files that fail to decode also trip FG-SYN-017
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
message names the first offending sequence and its codepoints
(e.g. `U+00C3 U+00A9`). Decode failure reports
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
- U+00C2 U+00A0 (ghost of a no-break space): MUST be
  flagged. [eval: unit fixture]
- U+00C3 U+0161 (ghost of Ú) and U+00C3 U+008D (ghost of Í):
  MUST be flagged. [eval: unit fixture]
- Uppercase N<U+00C3>O, A<U+00C7><U+00C3>O, <U+00C2>NGULO, PERMISS<U+00C3>O, and the table
  U+00C0..U+00C5 U+00E0..U+00E5: MUST NOT be flagged. [eval:
  TC-22.good, unit fixture]
- A lone U+00C2 before a space: MUST NOT be flagged. [eval:
  unit fixture]
- Boundary: U+00C3 U+00C0 MUST NOT be flagged; U+00C3 U+00BF
  MUST be flagged. [eval: unit fixture]
- U+00E2 U+20AC U+2122 (ghost of a right single quote): MUST
  be flagged; U+00E2 U+20AC before a space MUST NOT. [eval:
  unit fixture]
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
