---
spec_version: "openspec-1.0"
id: "FG-ENV-029"
title: ".env keys must match .env.example"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(KEY= line scan: keys only, values never read)"
invariant: "Every `.env*` file MUST set exactly the keys its sibling `.env.example` documents — no undocumented extras, no missing keys — while values are never read and never echoed."
fp_limits:
  - "keys present on both sides (values may differ freely)"
  - "comment, blank, and non-binding lines"
  - ".env files without a sibling .env.example (fail-open)"
  - "the .env.example oracle itself (never judged)"
golden_vectors:
  failing: "benchmark/vectors/tc29/bad/.env"
  passing: "benchmark/vectors/tc29/good/.env"
auto_heal_strategy: "sync_env_keys"
---

# 1. Anti-Pattern Diagnosis

AI-generated setup flows add `STRIPE_KEY=...` to `.env` and
forget `.env.example`: the next clone boots with a hole, or
the deploy ships a key nobody documented. Worse, the drift
runs the other way — the example gains `API_URL` while the
developer's `.env` silently lacks it, and the app crashes on
a null lookup in production. The campodeforca `EnvKeys` /
`EnvParity` gates (SYS-CAL-003 R2-5 tail T6) require key
parity, never reading values; this rule is that gate,
universal and config-free. One finding per gap: extras land
on the key's line, missing keys on line 1 (file-level, the
ORP precedent — the key has no line to land on).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   # .env (sibling .env.example documents API_URL + API_KEY)
   API_URL=https://staging.example
-EXTRA_KEY=oops
+API_KEY=changeme
```

# 3. Edge Cases and Non-Compliance

A binding is a line whose key is the trimmed text before the
first `=`, with one optional `export ` prefix stripped; the
rest of the line (the value) is never read. Keys compare
case-sensitively as sets. The oracle is the `.env.example`
sibling in the analyzed file's directory. Extra keys flag on
their line; missing keys flag on line 1. Findings name keys
only — values never echo.

- Extra key in `.env` (missing from the example): MUST be
  flagged, on the key's line. [eval: TC-29.bad]
- Key in the example missing from `.env`: MUST be flagged,
  on line 1. [eval: TC-29.bad]
- Matching keys with different values: MUST NOT be flagged
  (values are out of scope by design). [eval: TC-29.good]
- Comment (`#...`), blank, `export KEY=...`, and spaced
  (`KEY = ...`) lines: comments/blanks skipped, `export`
  and spaces tolerated. [eval: TC-29.good, unit fixture]
- Bare `KEY` (no `=`) and `KEY:` lines: not bindings,
  skipped. [eval: unit fixture]
- Missing sibling `.env.example`: silent (fail-open —
  parity is unjudgeable). [eval: unit fixture]
- `.env.example` analyzed directly: MUST NOT be flagged
  (the oracle is never judged). [eval: unit fixture]
- CRLF line endings: tolerated. [eval: unit fixture]
- UTF-8 BOM: stripped from the first key. [eval: unit
  fixture]
- Duplicate keys within a file: collapse (set semantics),
  NOT flagged. [unevaluated]
- Non-`.env.example` oracle names (`.env.sample`,
  `.env.template`): out of scope v0. [unevaluated]
- `.env.local` override conventions: no carve-out (strict
  parity — the baseline ratchets legacy trees).
  [unevaluated]

`sync_env_keys` is model-owned per the SYS-HEAL-001 closed
fast-path list (adding a key needs a value decision — real
secret vs placeholder — that only a human makes); the
harness never attempts it as a fast-path patch.
[unevaluated]
