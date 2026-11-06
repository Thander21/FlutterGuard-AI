---
spec_version: "openspec-1.0"
id: "FG-DOC-032"
title: "local Markdown links must resolve"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "(line scan: inline link/image targets vs the filesystem)"
invariant: "Every local link and image target in a Markdown file MUST resolve to an existing file or directory next to that file — a `[guide](missing.md)` ships dead documentation."
fp_limits:
  - "links to existing files, directories, and file#fragment targets"
  - "remote targets (http, mailto, data) and absolute /root paths"
  - "pure #anchors, empty targets, and angle-bracket spellings of them"
  - "links inside fenced blocks and inline code spans"
  - "reference-style links and HTML anchors (out of scope v0)"
golden_vectors:
  failing: "benchmark/vectors/tc32/bad/guide.md"
  passing: "benchmark/vectors/tc32/good/guide.md"
auto_heal_strategy: "model-owned"
---

# 1. Anti-Pattern Diagnosis

AI-written docs link the file the plan promised instead of the
file that landed: `[runbook](docs/runbook.md)` points at a page
that was renamed two refactors ago, and the screenshot embeds
`![flow](assets/flow.png)` from a directory that never existed.
Nobody clicks every link before merging, so the dead ends ship.
The campodeforca `DocLinks` gate (SYS-CAL-003 R2-5 medium list)
fails broken local links; this rule is that gate, universal and
config-free. One finding per dead target, on the link's line.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
-  See the [runbook](docs/runbook.md) for details.
+  See the [runbook](docs/run-book.md) for details.
```

# 3. Edge Cases and Non-Compliance

Only inline links `[text](target)` and images `![alt](target)`
are read. Fenced blocks (triple backtick or tilde) and inline
code spans are stripped before matching, so literal text never
flags. A target is local unless it carries a remote scheme
(`http:`, `https:`, `mailto:`, `data:`, `//host`), is a pure
`#anchor`, is empty, or is an absolute `/root` path (unresolvable
without a doc root — skipped). `target#fragment` checks the file
part only; fragments are renderer-specific and unchecked.
Angle-bracket destinations `<a b.md>` unwrap before resolving,
and trailing `"titles"` are ignored. Existence is
platform-native (`File`/`Directory.existsSync`), so case follows
the filesystem.

- Dead file link: MUST be flagged, on the link's line.
  [eval: TC-32.bad]
- Dead image target: MUST be flagged, on the link's line.
  [eval: TC-32.bad]
- Existing file, existing directory, and `file#fragment`
  targets: MUST NOT be flagged. [eval: TC-32.good]
- Fenced and inline-code links to nowhere: MUST NOT be
  flagged. [eval: TC-32.good]
- Remote, pure-anchor, empty, and absolute-path targets:
  MUST NOT be flagged. [eval: TC-32.good]
- Reference-style links (`[x][r]` + `[r]: nowhere.md`):
  MUST NOT be flagged (out of scope v0 — pinned, not
  forgotten). [eval: TC-32.good]
- Titles (`[x](target.md "t")`) and angle destinations
  (`[x](<target dir.md>)`): resolved on the path part.
  [eval: unit fixture]
- Multiple dead links on one line: one finding each (`check`
  dedups per line). [eval: unit fixture]
- CRLF line endings: tolerated. [eval: unit fixture]
- HTML anchors (`<a href>`), bare autolinks (`<./x.md>`),
  and nested-bracket link text: unchecked v0.
  [unevaluated]
- Indented code blocks: links inside still resolve (fences
  and spans are the v0 code shapes). [unevaluated]
- Non-`.md` files: never evaluated (extension walk scope).
  [eval: unit fixture]

`fix_doc_link` is model-owned per the SYS-HEAL-001 closed
fast-path list (a dead link needs intent — rename, move, or new
page — never a mechanical patch); the harness never attempts it
as a fast-path patch. [unevaluated]
