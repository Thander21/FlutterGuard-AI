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

`check <path> [--json] [--include-generated] [--baseline=<path>]
[--update-baseline] [--diff] [--diff-base=<ref>] [--analyze]
[--dep-audit] [--license-audit] [--by-gate] [--evidence=<path>]
[--help]`, parsed
with `package:args` (`args` dependency). Exit codes: 0 clean or
warnings-only, 1 error-severity violations found, 2 bad arguments
(REVIEW-01 verified the launcher swallows returned codes, so `main`
calls `exit()` explicitly). `--help` prints usage and exits 0.
Warnings (today: FG-MET-007 advisories until SYS-CAL-001
calibrates them, plus FG-RIV-026 naming advisories) are
reported but never fail the gate; blocking
on uncalibrated thresholds is barred. `--diff-base` implies
`--diff` (base defaults to `origin/main`); `--update-baseline`
requires `--baseline` and rejects `--diff` (a diff-scoped
rewrite would silently prune the legacy baseline).

Generated files are skipped by default: `*.g.dart`,
`*.freezed.dart`, `*.gr.dart`, `*.mocks.dart`, Flutter l10n
catalogs (`app_localizations*.dart`), and anything under a
`generated/`, `gen/`, or `flutter_gen/` directory — findings
there are unactionable (the next build overwrites any fix).
`--include-generated` scans them (SYS-CAL-002 P0-3).

File scopes (SYS-CAL-003 R2-5 tail T4): the walk covers the
registered extension union (`.dart` plus every non-Dart scope
some rule declares — `.arb` today), and every rule sees only
its scoped extensions. Dart visitors never parse catalog
files (so FG-SYN-017 never fails closed on them); catalog
rules never see `.dart`. A single non-matching file target
yields an empty run; a missing target still throws. Tail T6
adds basename-prefix scopes for dotfiles (`.env*`), matched
on the basename start and collected by the same union. Medium
M1 adds exact-basename scopes for singletons (`pubspec.yaml`
— neither an extension nor a prefix fits), matched on the full
basename and collected by the same union, and `.md` joins the
extension union for FG-DOC-032.

Rules disabled by the nearest `flutterguard.yaml` are skipped
(schema v2, SYS-CAL-002 P3-1): discovery walks up from the
target to the filesystem root; a missing or broken file means
all-enabled (the gate never silently shrinks). `grade` always
runs the full registry — it validates the rules themselves.

## Rule parameters (SYS-CAL-003 R2-5)

Parameterized rules self-load their section from the nearest
`flutterguard.yaml` (shared walk-up discovery — the same config
that governs rule toggles governs parameters; nearest wins, no
merging). Missing/unparseable configs, missing sections, and
malformed entries degrade to each rule's documented default
(silent unless the rule says otherwise); config problems are
never file verdicts (§5).

`banned_symbols` (FG-BAN-018): a list of `{symbol, message?,
except?}` — `symbol` the case-sensitive simple name
(required), `message` project guidance (optional), `except` a
glob list (`*`, `?`, full-segment `**`) matched against the
analyzed file relative to the config directory (absolute when
outside it). Non-map entries, missing/non-string `symbol`s,
and non-list `except`s are skipped silently.

`print_logger` (FG-LOG-019): a map `{symbols?, except?,
message?}` — presence (even an empty map) opts in, banning
bare `print`/`debugPrint` plus the extra `symbols` names;
`except` globs and `message` behave as above. A missing or
non-map section disables the rule; malformed `symbols`/
`except`/`message` fields degrade leniently (defaults still
flag) — the gate never shrinks on partial garbage.

`theme_tokens` (FG-TOK-020): a map `{extra_ctors?, except?,
message?}` — unlike the opt-in rules above, the `Color`
default (unnamed + `fromARGB`/`fromRGBO` ctors) fires with
or without the section; the map only adds `Type`/`Type.ctor`
extras, theme `except` globs, and a custom message.
Malformed extras (wrong arity, empty segments, lowercase
types, non-strings) are ignored.

`i18n` (FG-I18N-021): a map `{widgets?, except?, message?}` —
presence (even an empty map) opts in, banning literal text in
`Text` plus the extra `widgets` names; `except` globs and
`message` behave as above. A missing or non-map section
disables the rule; malformed `widgets`/`except`/`message`
fields degrade leniently (defaults still flag).

`layer_rules` (FG-LYR-024): a list of
`{files, deny_imports, except?, message?}` — `files` globs
select the capped files (config-relative), `deny_imports`
globs match import/export URI strings as written (no
resolution), `except` globs exempt files. Malformed rules
(non-map, missing/empty glob lists, non-string entries, bad
`except`) are skipped like `banned_symbols` entries.

`pii` (FG-PII-028): a map `{sinks?, names?, patterns?,
masks?, except?, message?}` — like `theme_tokens`, the
e-mail/`email`/`password` defaults fire with or without the
section; the map only adds sink names (simple-name match on
any target), PII identifier names, Dart regex sources over
literal runs, and mask verbs. Malformed regexes drop
silently; other malformed fields degrade leniently
(defaults still flag).

`test_presence` (FG-TST-033): presence (even an empty map)
opts in, requiring a mirror `test/..._test.dart` for every
`lib/` file; a missing or non-map section disables the rule.
`except`/`message` keys are reserved for v1 and ignored in
v0 (the baseline already ratchets legacy trees).

## Adoption scope (SYS-CAL-003 R2-2)

Dedup: `checkPath` collapses findings on (file, line, rule) after
the sort, joining distinct messages with `; `. `grade` is
untouched (it validates rules, not output); the MCP `analyze_ast`
tool inherits the collapse via `checkPath`.

Baseline: a JSON object `{file: {rule_id: count}}` (per-file
per-rule finding counts, campodeforca-shaped). `--baseline
<path>` reads it and reports only findings ABOVE the stored
count per (file, rule), in deterministic finding order; files
or rules absent from the baseline fail on any finding
(fail-closed for new code). Keys are project-relative
(findings still display as-walked): the root is the nearest
ancestor of the target (the target itself when it is a
directory) holding a `pubspec.yaml`, else the target directory
(a file target's parent); no git lookup. Keys use `/`, carry no
drive letter and no leading slash (`lib/apps/desktop/main.dart`),
with `.`/`..` collapsed, so one baseline is stable across working
directories, checkout folders, machines, and CI, and can be
committed. Legacy baselines keyed by absolute-normalized paths
still match: a finding tries its relative key, then its absolute
key; absolute keys written at another location simply match
nothing (rewrite with `--update-baseline` to migrate). Disabled rules are never
counted and baseline entries for them are ignored silently.
`--update-baseline` rewrites `<path>` from the current
unfiltered run (never from the suppressed set), pruning stale
entries, and exits 0 with a delta note; it never reads the old
file. No walk-up discovery of the baseline file in v1 (explicit
flag only);
`.flutterguard/baseline.json` is the suggested conventional
path. Counts cover errors and warnings alike (the legacy
noise is mostly warnings).

Diff: `--diff` restricts the run to files changed in the
worktree versus the merge-base with `<base>` (`--diff-base`,
default `origin/main`), plus untracked files (honoring
`.gitignore`), intersected with the target walk — file-level
v1 (line-level deferred). Design note: this worktree scope
(rather than committed-vs-HEAD only) is what makes the mode
useful to the agent loop, whose edits are uncommitted; the Q2
"merge-base with HEAD" shorthand is read this way. The hook
keeps whole-tree `check .` (the baseline makes legacy green);
`--diff` is for the agent loop and CI. A file target is
checked iff changed, else reported clean.

Analyze step: `--analyze` also runs the ambient SDK's
`dart analyze --fatal-infos` over the target (whole target,
even under `--diff` — the analyzer needs package context)
and parses `--format machine` issues into per-file
`analyzer:`-prefixed gate errors. An analyzer failure exits
1 (the summary counts findings only, so a red analyze step
with clean visitors still prints `0 violation(s)`); a spawn
failure exits 2 naming the cause. Findings stay rule-pure
(no synthetic rule ids); `--update-baseline` still writes
from visitor findings but exits 1 when the analyze step is
red. The step runs at the `check()` edge, so `checkPath`
stays stdio-free and the MCP `analyze_ast` tool stays
visitors-only.

DepAudit: `--dep-audit` runs `pub outdated --json` per package
root under the target (every `pubspec.yaml` found) and flags
discontinued, replaced, retracted-current, and
advisory-affected packages as `dep-audit:`-prefixed gate
errors, exiting 1. Behind-latest-but-healthy packages never
flag (maintenance, not gate failures). Malformed JSON fails
closed (exit 2 — no exit-code backstop exists, so a blind gate
says so loudly); spawn failure and non-zero exits exit 2
naming the cause. Requires network; CI without it omits the
flag. Runs under the ambient Dart SDK (Flutter-package
fidelity unevaluated in v0). The positive path is
network-bound and verified out-of-band; the suite pins
parsing, the offline-empty case, and exits.

LicenseAudit: `--license-audit` classifies each hosted
dependency's license text from the pub cache against the
`licenses.deny` policy (`licenses: {deny: [...], allow_pkgs:
{pkg: SPDX}}` in the nearest config; substring-matched,
case-insensitive, so `GPL` catches the family). Denied,
unrecognized, and missing license texts fail closed as
`licenses:`-prefixed gate errors on the owning pubspec,
exiting 1; `allow_pkgs` pins beat the classifier and the deny
list. Roots without a lockfile pass silently (unauditable);
path/git/sdk deps are skipped. A missing or empty deny list
exits 2 (nothing to enforce). The cache resolves via
`PUB_CACHE` or the platform default, defaulting to the
pub.dev host with a mirror fallback scan.

Per-gate report: `--by-gate` appends one verdict row per
enabled rule (`gate PASS|WARN|FAIL <RULE> (<e> errors, <w>
warnings, <ms> ms)`, registry order; JSON gains a `gates`
array) computed from reported findings plus measured scan
times. Default output is byte-identical without the flag.

Execution is sequential by default; `--jobs <n>` (n ≥ 2)
fans the per-file loop out to file shards over worker
isolates (`Isolate.run` one-shot per shard; at most
min(<n>, cores, files) workers). Workers receive plain
data only (enabled rule ids + file paths) and re-resolve
the registry by id inside the isolate, so the FG-LINT-009
`severityFor` closure never crosses a boundary and the
registry stays untouched. Findings, per-file errors, and
per-rule timings merge back into the same deterministic
tail (sort + dedup), so `--jobs` output is finding-identical
to sequential (only `ms` values differ). The FG-FMT-016
batch still runs in the main isolate. A dead worker fails
closed: its shard re-runs sequentially in the main
isolate. The library core (`checkPath`/`checkFiles`/
`analyzeFilesWithRules`) stays synchronous; only the thin
`check()` CLI wrapper is async.

Per-run ledger: `--evidence <path>` appends one canon-shaped
line per enabled rule (SYS-TELE-001, zero new keys:
`CHECK_GATE` phase, `CHECK_RECORDED` action, `WARNED`
verdict) recording the reported verdicts — the audited
target, the mapped status, and the first finding message per
rule. Timings and counts stay on the `--by-gate` surface;
the ledger records verdicts. Written before rendering on
both the normal and `--update-baseline` paths; unwritable
paths exit 2 naming the cause. Changes no exits
(report-only). Default runs write nothing, anywhere.

## Test selection (medium M2)

`select-tests <path> [--diff-base=<ref>] [--help]` prints the
tests for the worktree diff (one absolute-normalized path per
line): changed `*_test.dart` files plus existing mirrors of
changed lib files (shared `mirrorTestFor`, so selection agrees
with FG-TST-033 on the layout). `<path>` locates the repo; the
selection is always repo-wide (fail-closed). Deleted files and
non-runnable changes (helpers, docs, configs) select nothing —
an empty selection prints nothing and exits 0, composing to a
full `dart test` run under shell substitution. Git failures exit
2 naming the cause (the `--diff` edge semantics). The mutation
and coverage runners keep explicit test paths in v1; selection
is a standalone CI step (auto-wire is a follow-up).

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
  "errors": [{"file": "lib/broken.dart", "error": "…"}],
  "summary": {"errors": 1, "warnings": 0}
}
```

Text rendering prefixes warnings (`warning: FG-MET-007 …`); error
lines keep the bare `RULE file:line message` shape. The summary
line is `N violation(s) (E errors, W warnings) in <target>.`
(counts of reported findings, post-baseline). `--update-baseline`
prints `Baseline written to <path>: F files, N findings (E
errors, W warnings).` instead (JSON: `{"baseline": ..., "files":
F, "summary": {"errors": E, "warnings": W}}).

## Gate mapping (ForceField §2)

| Gate | Contents | Budget | Status |
|------|----------|--------|--------|
| `validate-light` | immediate parse-only AST rules (FG-BLOC-001, FG-RIV-001, FG-ST-001, FG-LIFE-001, FG-ARCH-003, FG-ASYNC-002, FG-LAY-004, FG-ST-005, FG-CTX-006, FG-WID-008, FG-LINT-009, FG-KEY-001r, FG-MET-007 advisory, FG-BUILD-014, FG-IMP-015, FG-FMT-016, FG-SYN-017, FG-BAN-018, FG-LOG-019, FG-TOK-020, FG-I18N-021, FG-ENC-022, FG-ORP-023, FG-LYR-024, FG-CC-025, FG-RIV-026 advisory, FG-ARB-027, FG-PII-028, FG-ENV-029, FG-ASSET-030, FG-VER-031, FG-DOC-032, FG-TST-033, FG-SYNC-034); imports/format/syntax checks live (TS-15/16/17) | ~1–3 s | live |
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
line, message) so output is byte-stable, and dedup collapses
post-sort on (file, line, rule), so the collapse is stable too;
test gates run with `--concurrency=1` (ClientAgents §2 Gate 3)
plus a pinned ordering seed where the runner supports one.

Evidence-presence enforcement: `commit-check` rejects a commit whose
touched specs lack matching SYS-TELE-001 lines. `grade` is the producer;
`check` stays read-only (never writes evidence — foreign-target safe per
the pollution budget), with one exception: `--update-baseline` writes
only the explicitly named baseline path, never the target tree.

## 3. File Placement

- `bin/flutterguard.dart` `check()` (thin CLI: parse, render, exit codes).
- `lib/src/cli/check.dart` (`checkPath`: pure core, per-file errors
  collected, sorted output; plus the `--jobs` parallel scan:
  `checkFilesParallel`, the worker entry, and the sequential
  fallback — co-located so no import cycle forms).
- `lib/src/cli/rules.dart` (registry both `grade` and `check` run).
- `lib/src/cli/baseline.dart` (R2-2 adoption scope: baseline
  load/write/ratchet filter + diff file-set resolution; the git and
  baseline reads run at the `check()` edge so `checkPath` stays
  stdio-free). Re-exported from `lib/flutterguard_ai.dart`.
- Tests: `test/check_test.dart` (audit behavior, parallel
  equivalence), `test/check_cli_test.dart`
  (arg parsing, exit codes, `--jobs` matrix), `test/baseline_test.dart` (ratchet math,
  key stability, diff scope, flag matrix), `test/select_test.dart`
  (selection mapping, CLI lines and exits), `test/analyze_test.dart`
  (machine-output parsing, real-SDK runs, `--analyze` exits),
  `test/deps_test.dart` (outdated parsing, offline-empty run,
  `--dep-audit` exits), `test/licenses_test.dart` (classifier,
  fake-cache audits, `--license-audit` exits),
  `test/gate_report_test.dart` (verdicts, timings, `--by-gate`
  output), `test/ledger_test.dart` (canon lines, append
  semantics, `--evidence` exits).
- `lib/src/cli/select.dart` (`selectChangedTests`: pure core over
  `resolveChangedFiles`; `selectTests`: thin CLI).
- `lib/src/cli/analyze.dart` (`runAnalyzer` subprocess plus
  `parseAnalyzerOutput`/`groupAnalyzerIssues`; wired at the
  `check()` edge, never in `checkPath`).
- `lib/src/cli/deps.dart` (`runDepAudit` subprocess plus
  `parseOutdatedJson`; wired at the `check()` edge).
- `lib/src/cli/licenses.dart` (`classifyLicenses`,
  `resolvePubCache`, `runLicenseAudit`; wired at the
  `check()` edge with the `licenses` config section).
- Per-gate verdicts (`GateVerdict`, `gateReport`, `gateLine`)
  and timings (`CheckResult.msByRule`) live in
  `lib/src/cli/check.dart`.
- `lib/src/cli/ledger.dart` (`buildLedgerLines` canon shaping
  plus `appendLedger`; called at the `check()` edge, never in
  `checkPath`).
- `lib/src/ast/format_guard.dart` (FG-FMT-016 batch core:
  bounded `dart format` spawns per `checkPath` call, 50 files
  each (TS-16); called by `checkPath`, not the per-file loop).
- `checkFilesParallel` is called at the `check()` edge when
  `--jobs` ≥ 2, never in `checkPath`.

# 4. Evidence Wiring

`check` is read-only by design: default runs write nothing,
anywhere — no `evidence.jsonl` (grade-owned, never touched by
`check`), nothing inside the target tree. The only writes are
explicitly-named side paths: `--update-baseline` (the given
baseline file) and `--evidence` (the given ledger file), both
opt-in, both outside the target unless the caller points them
there. Its JSON findings (`rule_id`/`file`/`line`/`message`,
`spec`, `recipe`) align with the SYS-TELE-001 subset heal/MCP
consume; no key is claimed identical.

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
- Missing, unreadable, or malformed `--baseline` file (bad JSON,
  non-map shape, non-integer or negative counts): usage error →
  exit 2 naming the cause (an explicit path that cannot be read
  is a typo, not an empty baseline).
- `--update-baseline` without `--baseline`, or combined with
  `--diff`: usage error → exit 2.
- Unwritable baseline path on update: exit 2 naming the cause.
- `--diff` outside a git worktree, unresolvable base ref, or git
  failure (missing binary, no commits): exit 2 naming the cause.
- `--analyze` spawn failure (missing SDK): exit 2 naming the
  cause. Analyzer findings: per-file `analyzer:` errors, exit 1
  (the summary counts findings only). `--analyze` with
  `--update-baseline` still writes the baseline but exits 1 when
  the analyze step is red.
- `select-tests` outside a git worktree, unresolvable base ref,
  or git failure: exit 2 naming the cause (the `--diff` edges).
  Empty selection: exit 0 with no output.
- `--dep-audit` spawn failure, non-zero `pub outdated` exit, or
  malformed JSON: exit 2 naming the cause. Signals: per-package
  `dep-audit:` errors, exit 1.
- `--license-audit` without a `licenses.deny` list: exit 2.
  Denied/unrecognized/missing licenses: per-package `licenses:`
  errors on the owning pubspec, exit 1.
- `--by-gate` changes no exits (report-only).
- `--evidence` with an unwritable path: exit 2 naming the cause
  (written before rendering, so a bad path prints nothing).
  `--evidence` changes no exits (report-only); without the flag
  no ledger file is created anywhere.
- Empty diff set (nothing changed under the target): clean run,
  exit 0 with zero findings.
- Baseline entries for disabled rules or vanished files are
  ignored on read and pruned on update (never an error).
- `--jobs` with a non-integer or < 1 value: usage error →
  exit 2 naming the cause. `--jobs 1` is explicit
  sequential. `--jobs` changes no exits (finding-identical).
- Dead worker isolate: the shard re-runs sequentially in
  the main isolate (fail-closed fallback); no `errors`
  entry, no exit change — output stays finding-identical.

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
- Isolate parallelism (2026-11-07): the v0 sequential bar is
  lifted for an opt-in shard-by-file path — per-rule
  sharding rejected (breaks per-file error-once), async
  `checkPath` rejected (breaks the sync library core),
  sending analyzer tear-offs rejected (workers resolve the
  registry by id from plain data, so no closure crosses).
