---
spec_version: "openspec-1.0"
id: "FG-ARB-027"
title: "ARB placeholders must declare @key metadata"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(JSON text scan: top-level brace heads + sibling @key map)"
invariant: "Every top-level `{placeholder}` head in an `.arb` message value MUST be declared under the sibling `@key` `placeholders` map."
fp_limits:
  - "messages without placeholders (no @key required)"
  - "declared placeholders (including plural/select heads)"
  - "extra declared-but-unused placeholder entries"
  - "@@-prefixed global entries (@@locale and friends)"
  - "non-string message values"
  - "orphan @key metadata without a message"
golden_vectors:
  failing: "benchmark/vectors/TC-27_arb.bad.arb"
  passing: "benchmark/vectors/TC-27_arb.good.arb"
auto_heal_strategy: "add_placeholder_metadata"
---

# 1. Anti-Pattern Diagnosis

AI-generated `.arb` catalogs add `{userName}` to the copy and
forget the `@key` block: `gen-l10n` then generates an untyped
argument — or fails the build outright for formatted
(date/number/plural) placeholders — and translators lose the
description and type context. The campodeforca `ArbMetadata`
gate (SYS-CAL-003 R2-5 tail T4) draws the line at declared
metadata; this rule is that line, universal and config-free
(like FG-ENC-022: an `.arb` catalog is either sound or it is
not). One finding per undeclared placeholder, on the message
key's line; malformed JSON fails closed with a single finding
(a broken catalog breaks codegen — never silently clean).

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   "greeting": "Hello {userName}!",
   "@greeting": {
-    "description": "Greets the user."
+    "description": "Greets the user.",
+    "placeholders": {
+      "userName": {"type": "String"}
+    }
   }
```

# 3. Edge Cases and Non-Compliance

A message is a top-level entry whose key does not start with
`@` and whose value is a string. Placeholders are the head
identifiers of top-level `{...}` spans (`{name}` and
`{count, plural, ...}` both yield one head; nested spans
inside plural/select cases are case text, not placeholders).
A head is declared iff the sibling `@key` entry is a map
whose `placeholders` entry is a map containing the head.
Findings land on the message key's line, in document order.

- Undeclared placeholder with a description-only `@key`:
  MUST be flagged. [eval: TC-27.bad]
- Message with placeholders and no `@key` at all: MUST be
  flagged (one finding per placeholder). [eval: TC-27.bad]
- Plural/select heads (`{count, plural, ...}`): the head
  counts, nested case spans do not. [eval: TC-27.bad,
  TC-27.good]
- Message without placeholders and without `@key`: MUST NOT
  be flagged (metadata is only required for placeholders).
  [eval: TC-27.good]
- Declared placeholders: MUST NOT be flagged.
  [eval: TC-27.good]
- Declared-but-unused placeholder entries: MUST NOT be
  flagged (one direction only). [eval: TC-27.good]
- `@@`-prefixed entries (`@@locale`): skipped, never
  messages. [eval: TC-27.good]
- Non-string values (numbers, bools, objects): skipped, not
  messages. [eval: TC-27.good]
- Orphan `@key` metadata without a message: out of scope
  (the gate is placeholders-must-have-metadata, not the
  reverse), NOT flagged. [eval: TC-27.good]
- Malformed JSON: exactly one finding naming the syntax
  error; no placeholder scan. [eval: unit fixture]
- Top-level JSON that is not an object: one finding, no
  scan. [eval: unit fixture]
- `@key` entry that is not a map, or `placeholders` that is
  not a map: treated as missing, placeholders flagged.
  [eval: unit fixture]
- Unbalanced `{` without a closing span, stray `}`, and
  non-identifier heads (`{}`, `{0}`): ignored (ICU
  validation is not this gate). [unevaluated]
- ICU apostrophe-quoted braces (`'{x}'`): read as
  placeholders (quote-naive v0 — quoted-brace literals are
  vanishingly rare, apostrophe copy is common, and strict
  quoting would miss real placeholders after a `don't`).
  [unevaluated]
- Duplicate message keys: decoded per `jsonDecode` (last
  wins); the line locator lands on the first spelling.
  [unevaluated]

`add_placeholder_metadata` is model-owned per the
SYS-HEAL-001 closed fast-path list (picking the placeholder
type and format needs semantic judgment); the harness never
attempts it as a fast-path patch. [unevaluated]
