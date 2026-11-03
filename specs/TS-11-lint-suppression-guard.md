---
spec_version: "openspec-1.0"
id: "FG-LINT-009"
title: "Forbid suppressions and empty catch blocks"
status: "approved"
severity: "error"
analysis: "parse-only"
ast_nodes:
  - "Token.precedingComments[type='//']"
  - "CatchClause[body empty]"
invariant: "No single-line comment MUST contain 'ignore:' or 'ignore_for_file:'; no catch clause MUST have an empty body."
fp_limits:
  - "doc (///) and block (/* */) comments mentioning ignore"
  - "comments mentioning ignore without the colon"
  - "non-empty catch blocks (handle or rethrow)"
  - "empty non-catch bodies"
golden_vectors:
  failing: "benchmark/vectors/TC-11_lint.bad.dart"
  passing: "benchmark/vectors/TC-11_lint.good.dart"
auto_heal_strategy: "remove_suppression_and_fix"
---

# 1. Anti-Pattern Diagnosis

`// ignore:` silences the exact signal the gate exists to emit, and an
empty `catch` buries the failure the user will report next week:
both trade a compile-time finding for a production incident.
AI-generated code leans on both because the happy path never trips the
lint and never throws. This rule enforces Root Cause Only: fix the
finding, handle the error, or `rethrow` — never suppress, never swallow.

# 2. Canonical Auto-Heal Recipe (Before / After)

```diff
   void load() async {
     try {
       await fetch();
-    } catch (_) {}
+    } catch (error) {
+      debugPrint('load failed: $error');
+      rethrow;
     }
   }
```

(And every `// ignore:` line is deleted, with the underlying finding
fixed at its root cause.)

# 3. Edge Cases and Non-Compliance

Comments are walked from the token stream (`precedingComments`), not
the AST: any `//` line comment containing the directive text is
flagged, anywhere in the file. A catch body counts as empty when every
statement is an `EmptyStatement` (bare `;` still swallows).

- Own-line `// ignore: x`: MUST be flagged. [eval: TC-11.bad]
- `// ignore_for_file: x` (any position): MUST be flagged.
  [eval: TC-11.bad]
- Empty `catch (_) {}`: MUST be flagged. [eval: TC-11.bad]
- Non-empty catch (log + `rethrow`): MUST NOT be flagged.
  [eval: TC-11.good]
- `///` doc comment containing `ignore:`: MUST NOT be flagged (the
  analyzer does not honor it). [eval: TC-11.good]
- Empty function body: MUST NOT be flagged (catch-only scope).
  [eval: TC-11.good]
- Trailing `code; // ignore: x`: MUST be flagged. [eval: unit fixture]
- Block comment containing `ignore:`: MUST NOT be flagged.
  [eval: unit fixture]
- Empty `on` clause without `catch`: MUST be flagged.
  [eval: unit fixture]
- `catch (e) { ; }`: MUST be flagged (empty statement). [eval: unit fixture]
- Uppercase `IGNORE:`: MUST NOT be flagged (not honored).
  [eval: unit fixture]
- `ignore` without the colon: MUST NOT be flagged. [eval: unit fixture]
- Print-only catch: clean (non-empty by design). [unevaluated]

`remove_suppression_and_fix` is model-owned per the SYS-HEAL-001 closed
fast-path list (deleting the comment is trivial; fixing the underlying
finding takes judgment); the harness never attempts it as a fast-path
patch. [unevaluated]
