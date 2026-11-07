---
name: fg-audit
description: Run the full harness execution battery in an isolated worktree and emit a docs-vs-reality report. Use to validate the whole tool end to end or to re-verify after a release.
---

# fg-audit — Full Execution Battery (`*audit`)

Proves every executable surface green from a pinned commit, without
touching the main checkout: analyzer, suite, grade, check matrix,
CLI surface, adoption engine, hook, viewport, live mutation, and
docs-vs-reality counts. Conventions: `<WT>` = detached worktree in
a scratch dir, `<OUT>` = report artifacts outside the worktree.

## Setup (isolation first)

1. `git worktree add --detach <WT> <commit>` (fresh clone to
   scratch when no checkout exists). Record `git rev-parse HEAD`.
2. `cd <WT>`; `dart pub get`. Everything below runs in `<WT>`.
3. Record `dart --version` and `flutter --version` (presence
   only — never install SDKs for an audit).

## Steps

1. Analyzer: `dart analyze --fatal-infos lib bin test tool` must
   be clean (the CI scope). Root-wide analyze fails on purpose
   (unresolvable fixtures in `benchmark/vectors/`, separate
   `viewport/` package) — record, do not fix.
2. Suite: `dart test` unfiltered. Record total, failures, time.
3. Grade: `dart run bin/flutterguard.dart grade` exits 0; confirm
   appended `evidence.jsonl` lines carry the 9 canon keys.
4. Check matrix on the worktree itself:
   - `check lib --by-gate`: record per-gate PASS/WARN/FAIL, ms,
     and the `(E errors, W warnings)` summary line.
   - `check . --json`: findings must live in
     `benchmark/`/`fixtures/`/`viewport/` (intentionally bad)
     plus advisory warnings at most; zero findings on
     `*.good.*` files; summary counts must match the list.
   - `--jobs 1` vs `--jobs 4`: sorted `(file,line,rule_id)`
     sets identical.
   - Exit matrix: usage errors → 2, `--help` → 0, warnings → 0.
5. CLI surface: `heal` red→green (exit 0) + no-recipe (exit 2,
   names the spec §2); `sandbox` load/check/reset (1 with
   content, 0 empty); `select-tests` silent on clean trees,
   prints changed tests on dirty ones (silence composes to a
   full run under shell substitution — never "prints all");
   baseline update → green re-run → above-baseline fails;
   `--diff` on a clean tree is green.
6. Foreign hook: fresh temp repo + `init --scaffold`, then commit
   a planted violation with `FLUTTERGUARD_ROOT=<WT>` — the commit
   must block naming findings (without the root or a global
   install, the hook's documented fallback fails by design).
7. Flags: `check lib --analyze` green; `--license-audit` without
   config exits 2; `--dep-audit` signals counted from the JSON
   `dep-audit:` errors, never from the exit code alone.
8. Heavy (only when the SDK is present): `flutter test` in
   `viewport/` (14/14: 6-case matrix × bad/good + 2 evidence
   tests); live mutation on a mini package via the default
   `dart test` spawn (shadow dir removed afterwards). The
   `flutter test` mutation path stays suite-covered unless a
   field target exists.
9. Focused suites: `mcp_server`, `plugin_bundle`,
   `coverage_runner`, `duplication` (includes the real stdio
   smoke over all 5 tools).
10. Docs-vs-reality: `test/doc_counts_test.dart` is the
    mechanical pin; anything it cannot cover (install paths,
    Tier-1 matrix size, hook chain) gets verified by hand and
    recorded with file:line + observed output.
11. Report + verdict: environment, command log with exit codes,
    gate tables, numbered discrepancies with severity,
    unevaluated points with reason, one-line verdict
    (READY / READY-WITH-RESERVATIONS / NOT-READY).
12. Cleanup: `git worktree remove --force <WT>` + prune, delete
    scratch probes, keep only the report; main-checkout `git
    status` must match its pre-audit state.

## Done criteria

- Report emitted outside the worktree; worktree removed.
- Every numbered step has an observed result or a named reason.
- No functional discrepancy left unrecorded; doc-count drift is
  impossible while `doc_counts_test.dart` stays green.
