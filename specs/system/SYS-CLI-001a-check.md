---
spec_version: "openspec-1.0"
id: "SYS-CLI-001a"
title: "check command and gate mapping"
status: "approved"
kind: "system"
---

# 1. Problem

Rules are useless without a fixed way to run them. This contract pins the
portable `check` gate (one target in, verdict out) and maps every rule and
validation activity onto the four ForceField gates, so runners, hooks, and
humans agree on what runs where, on which budget, and with what evidence
duty.

# 2. Interface / Schema

`check <path> [--json] [--include-generated] [--help]`, parsed with `package:args` (`args`
dependency). Exit codes: 0 clean or warnings-only, 1 error-severity
violations found, 2 bad arguments (REVIEW-01 verified the launcher
swallows returned codes, so `main` calls `exit()` explicitly).
`--help` prints usage and exits 0. Warnings (today: FG-MET-007
advisories until SYS-CAL-001 calibrates them) are reported but never
fail the gate; blocking on uncalibrated thresholds is barred.

Generated files are skipped by default: `*.g.dart`,
`*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`, Flutter l10n
catalogs (`app_localizations*.dart`), and anything under a
`generated/`, `gen/`, or `flutter_gen/` directory — findings
there are unactionable (the next build overwrites any fix).
`--include-generated` scans them (SYS-CAL-002 P0-3).

Rules disabled by the nearest `flutterguard.yaml` are skipped
(schema v2, SYS-CAL-002 P3-1): discovery walks up from the
target to the filesystem root; a missing or broken file means
all-enabled (the gate never silently shrinks). `grade` always
runs the full registry — it validates the rules themselves.

`--json` shape (from `CheckResult.toJson()`):

```json
{
  "findings": [
    {
      "rule_id": "FG-BLOC-001",
      "spec": "specs/TS-01-bloc-emit-guard.md",
      "recipe": "specs/TS-01-bloc-emit-guard.md (§2)",
      "file": "benchmark/vectors/TC-01_bloc.bad.dart",
      "line": 26,
      "message": "emit() called after async gap without isClosed check",
      "severity": "error"
    }
  ],
  "errors": [{"file": "lib/broken.dart", "error": "…"}]
}
```

Text rendering prefixes warnings (`warning: FG-MET-007 …`); error
lines keep the bare `RULE file:line message` shape.

## Gate mapping (ForceField §2)

| Gate | Contents | Budget | Status |
|------|----------|--------|--------|
| `validate-light` | immediate parse-only AST rules (FG-BLOC-001, FG-RIV-001, FG-ST-001, FG-LIFE-001, FG-ARCH-003, FG-ASYNC-002, FG-LAY-004, FG-ST-005, FG-CTX-006, FG-WID-008, FG-LINT-009, FG-KEY-001r, FG-MET-007 advisory, FG-BUILD-014, FG-IMP-015, FG-FMT-016, FG-SYN-017); imports/format/syntax checks live (TS-15/16/17) | ~1–3 s | live |
| `test` | changed-file unit tests via `dart test` / `flutter test --concurrency=1`; 100% green, no warnings | ~5–15 s | live |
| `validate` | `dart analyze --fatal-infos` over the module, cross-regression tests, contract integrity; resolved-analysis rules attach here | ~30–60 s | live (analyzer part) |
| `commit-check` | evidence presence per SYS-TELE-001, no temp files, clean diff | ~2 s | defined here, enforced by the hook in SYS-CLI-001b |

Rule→gate assignment is mechanical: `analysis: parse-only` runs in
`validate-light`, `analysis: resolved` runs in `validate`. Formal
light/full mapping: the practical parse-only subsets (async-gap guard →
FG-ASYNC-002, dispose symmetry → FG-LIFE-001) run in `validate-light`;
deep/resolved prover remnants stay spike-gated and attach to `validate`
only if ever built resolved.

Measured baselines (Windows x64, Dart 3.13.7, 2026-11-03, repo at 13
rules / 26 vectors; 14 rules / 28 vectors after FG-BUILD-014 — same
order of magnitude, startup-dominated): `check` over
`benchmark/vectors` 5.9 s wall via
`dart run` (in-process audit core is milliseconds — startup dominates);
`dart test` full suite 15.4 s (dominated by the scratch-clone hook test);
`dart analyze lib bin test` 2.4 s. The
`validate-light` wall budget needs the installed/compiled CLI
(distribution owns it); until then budgets are tracked, not blocking:
overruns warn, violations fail closed.

Deterministic invocation: `check` sorts files and findings (file, rule,
line) so output is byte-stable; test gates run with `--concurrency=1`
(ClientAgents §2 Gate 3) plus a pinned ordering seed where the runner
supports one.

Evidence-presence enforcement: `commit-check` rejects a commit whose
touched specs lack matching SYS-TELE-001 lines. `grade` is the producer;
`check` stays read-only (never writes evidence — foreign-target safe per
the pollution budget).

## 3. File Placement

- `bin/flutterguard.dart` `check()` (thin CLI: parse, render, exit codes).
- `lib/src/cli/check.dart` (`checkPath`: pure core, per-file errors
  collected, sorted output).
- `lib/src/cli/rules.dart` (registry both `grade` and `check` run).
- Tests: `test/check_test.dart` (audit behavior), `test/check_cli_test.dart`
  (arg parsing, exit codes).
- `lib/src/ast/format_guard.dart` (FG-FMT-016 batch core:
  bounded `dart format` spawns per `checkPath` call, 50 files
  each (TS-16); called by `checkPath`, not the per-file loop).

# 4. Evidence Wiring

`check` emits no `evidence.jsonl` (read-only by design). Its JSON findings
(`rule_id`/`file`/`line`/`message`, `spec`, `recipe`) align with the
SYS-TELE-001 subset heal/MCP consume; no key is claimed identical.

# 5. Errors and Edges

- Missing target: `ArgumentError` → usage → exit 2.
- Non-`.dart` file target: zero files scanned → clean, exit 0.
- Generated-file target: skipped files (see §2) never appear in
  findings or `errors` — a directory scan omits them, and an
  explicitly targeted single generated file scans zero files
  (clean, exit 0) unless `--include-generated` is passed.
- Broken config (unparseable YAML, non-map `rules`, non-boolean
  values, unknown rule ids): ignored piece by piece, defaulting
  to enabled. No `errors` entry is emitted for config problems
  (config is not a file verdict).
- Unreadable file (I/O failure) or analyzer crash: collected in
  `errors` once per file (stderr + JSON), reported but never fails
  the gate — exit follows findings only. Unparseable file:
  FG-SYN-017 finding (fails closed); the other visitors' identical
  parse throws still dedup to one `errors` entry. FG-FMT-016 emits
  no verdict for unparseable files (owned by FG-SYN-017).
- Unknown flags / wrong arity: usage → exit 2. `--help` (or `-h`): usage
  → exit 0. `--json` never changes exit codes.

# 6. Contradictions Resolved

- `bin/ast_guardian.dart`, `fg run`, `flutterguard analyze` are superseded
  by `check` (PLAN-01 decision, owned here).
- Grade-vs-check doctrine: `grade` is the repo-local dev-loop (appends
  evidence); `check` is the portable read-only gate.
- Syntax fail-closed flip (TS-17, 2026-11-04): unparseable files
  fail via FG-SYN-017 findings; §5 report-only now covers
  unreadable/crash only. The old fail-open hole (parse errors
  green) is closed.
- Formatter oracle (TS-16, 2026-11-04): the ambient `dart format`
  subprocess on the original paths; no new dependency (rejected:
  in-process `dart_style` pins a second formatting
  implementation that can skew from the ambient SDK; temp
  copies lose package context and flip the language version).
