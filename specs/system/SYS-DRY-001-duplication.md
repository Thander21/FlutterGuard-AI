---
spec_version: "openspec-1.0"
id: "SYS-DRY-001"
title: "Structural duplication detector (advisory)"
status: "approved"
kind: "system"
---

# 1. Problem

AI clones whole methods and widget trees instead of extracting
components, renaming identifiers just enough to defeat text diff.
CleanCodeDeterministicGates Gate B calls for AST normalization
(discard identifiers and literals, keep morphological structure)
with a similarity gate. This contract pins the detector and ships
it as advisory verdicts until calibration owns the blocking flip.

# 2. Interface / Schema

Library API (`lib/src/duplication/`, exported from the package
root). Sync — no subprocesses. No CLI command (`dryer` is a
superseded name, PLAN-01). No new dependencies.

```dart
// detector.dart: normalize + bag-Jaccard + verdict.
const duplicationThreshold = 0.8;
const duplicationMinLines = 15; // compared spans must EXCEED this

class DuplicationUnit {
  final String name; // Class.method, Class, or function
  final int line;    // 1-based first line
  final int endLine; // 1-based last line (inclusive)
  final Map<String, int> bag; // normalized token multiset
}

class ClonePair {
  final String nameA; final String fileA;
  final int lineA; final int endLineA;
  final String nameB; final String fileB;
  final int lineB; final int endLineB;
  final double similarity; // 0.8..1.0
}

class DuplicationVerdict {
  final bool passed; // advisory v1: always true
  final List<ClonePair> pairs; // canonical order
  final int unitsCompared;
  final int filesScanned;
  final List<CheckError> errors; // per-file, never fatal
}

/// Collects comparable units (>15-line declarations) from [source].
List<DuplicationUnit> collectUnits(String source, {String? path});

/// Ruzicka (bag) Jaccard: sum(min)/sum(max) over the union.
/// Both empty -> 1.0; one empty -> 0.0.
double bagJaccard(Map<String, int> a, Map<String, int> b);

/// Scores [target] (one `.dart` file or a directory scanned
/// recursively, sorted). Same walk discipline as `checkPath`.
DuplicationVerdict findDuplication(String target);
```

Units are declarations: top-level functions, methods,
constructors, classes, mixins, enums — whole-declaration spans
exceeding 15 lines (`endLine - line + 1 > 15`). Local functions
are skipped (their tokens already belong to the enclosing unit's
span). Widget-tree clones surface as `build()`-method pairs:
normalization keeps the structure that matters.

Pure data-holder classes are never units (shared TS-13
doctrine, `isDataHolderClass` in `lib/src/ast/data_holder.dart`:
every field `final`/`const`, only value-identity,
serialization, `copyWith`, and Equatable companions beyond
fields and constructors — v3 widened by SYS-CAL-003 R2-4)
— their shape similarity is structural coincidence, never
cloning. Mixins and enums are never excluded (no observed
FP; classes only). Members below an excluded class are
still collected normally: only the class-like unit is
skipped.

Normalization (token walk
`firstTokenAfterCommentAndMetadata..endToken`; doc comments and
metadata never enter the bag — units compare by code shape, so
`///` prose must not dilute similarity): `IDENTIFIER` → `ID`;
`STRING`/`INT`/`DOUBLE` → `LIT`; every other token verbatim
(keywords incl. `true`/`false`/`null`, operators, punctuation).
Two clones differing only in names, literals, docs, and metadata
normalize identically (similarity exactly 1.0). Unit spans still
run from the node offset (docs included in the 15-line bar).

A pair is reported when similarity `>= 0.8`. Canonical order:
units sorted by (file, line); pairs emitted `i < j`; `A < B` by
(file, line). Intra-file pairs included (same-file copy-paste is
the classic case); self-pairs and same-file overlapping spans
(nesting, not cloning) excluded. Member suppression: when two
class-likes are reported as a pair, any pair touching a member
across those two classes (member-member and member-class) is
dropped — the class finding subsumes them; the class pair itself
is always kept.

Complexity strategy (the "complexity strategy" clause):
exact-hash shortcut (identical normalized bags short-circuit to
1.0 without Jaccard math) plus a sound size-ratio prefilter
(pairs with min/max token count `< 0.8` cannot reach 0.8 Ruzicka,
so they are skipped before the math).

# 3. File Placement

- `specs/system/SYS-DRY-001-duplication.md` (this contract).
- `lib/src/duplication/detector.dart` (units + normalize +
  similarity + verdict, one cohesive unit).
- `lib/flutterguard_ai.dart` (re-export).
- `test/duplication_test.dart` (normalization/Jaccard units;
  clone pair at exactly 16 lines flagged; 15-line twins skipped;
  small twins skipped; structurally different pair clean;
  same-file clones found; nesting never self-reports;
  class-match member suppression; missing target + error
  tolerance). All fixtures inline → system-temp files (sync
  reads need no package context, so no committed samples).
- Runtime-only: none (pure reads).

# 4. Evidence Wiring

Emits no `evidence.jsonl` in v1: the verdict object is the record.
Any future duplication lines MUST amend SYS-TELE-001 first (canon
rule §4).

# 5. Errors and Edges

- Missing target: `ArgumentError`. Non-`.dart` file target or
  `.dart`-less directory: empty verdict (`passed`, zero counts).
- Unreadable file: one `CheckError`, the run continues (same
  tolerance as `checkPath`). Collection crashes (unexpected AST
  shapes) also land one `CheckError` per file, never fatal — one
  weird file must not kill an advisory scan. `parseString` runs
  with `throwIfDiagnostics: false`; partial ASTs still score.
- Span exactly 15 lines: skipped (strictly-greater rule);
  similarity exactly 0.8: flagged (`>=` rule).
- Advisory v1: `passed` is always true; the blocking flip
  requires a SYS-CAL-001 amendment (similarity is an explicitly
  listed calibration threshold).
- Canonical fix direction (Gate B recipe): extract the shared
  shape into a parameterized method/widget — recorded here as
  the future heal pointer (system specs carry no §2 recipe).

# 6. Contradictions Resolved

- Compared "nodes" (Gate B) are concretized as declarations in
  v1; arbitrary block-level slicing is deferred (overlapping
  O(n²) findings; declarations are the actionable extract unit).
- Jaccard/Tree-Edit fork: bag-Jaccard (Ruzicka) wins —
  frequency-aware; plain set-Jaccard saturates on the small
  structural vocabulary and false-positives. Tree-edit stays a
  valid future refinement.
- `flutterguard dryer` is superseded (PLAN-01) → library API only.
- Blocking (Gate B "rejeita a edição") vs the calibration bar
  (REVIEW-01 §3.9): enforcement deferred — v1 advisory, flip
  owned by SYS-CAL-001 (same treatment as CRAP and MET-007).
- Data-holder class-likes (CAL-001's ten data-class pairs) are
  excluded at collection (§2): their bags match by construction
  (fields + ctor + `toString`), never by cloning. A >15-line
  member of a data holder (e.g. a giant `toString`) stays
  comparable — only the class-like span is skipped.
