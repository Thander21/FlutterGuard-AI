# Pilot-3 Runbook: Field Re-run on ERP `lib/`

Owner-run protocol for the SYS-CAL-003 §5 acceptance bar. Method is
identical to round 2 (Q8): a clean FlutterGuard clone, zero ERP-side
changes, every rule's findings checked against the code, reported in
the round-2 shape.

- Normative bar: `specs/system/SYS-CAL-003-field-calibration-r2.md` §5.
- Round-2 method + numbers:
  `docs/pilots/RELATORIO_FlutterGuard_reteste_ERP.md` (§0 table).
- Round-2 baseline: `fb61306`, 694 files, Dart 3.13.7, Windows x64,
  no config, no `init`, 31.6 s, 2,355 findings, 76 duplicates.
- This runbook prepared at `3f2bf85` (2026-11-07). Record the actual
  hash you run; if it moved past `3f2bf85`, note the delta.

## 0. Preconditions

1. Fresh clone of FlutterGuard-AI at the pinned commit (no local
   changes: `git status --short` empty). Run `dart pub get` once.
2. ERP checkout untouched: no `flutterguard.yaml`, no `init`, no
   committed or uncommitted edits for this pilot. Record the ERP
   commit hash.
3. Same ambient SDK as round 2 (Dart 3.13.7, Windows x64). Record
   `dart --version` verbatim.
4. All pilot artifacts (JSON output, baseline file, notes) go
   OUTSIDE the ERP checkout (scratch dir), never into ERP `lib/`.

Denominator command (run once, record N):

```powershell
(Get-ChildItem -Recurse -Filter *.dart "<ERP>\lib").Count
```

## 1. Main run (flag-identical to round 2)

From the FlutterGuard repo root:

```powershell
Measure-Command { dart run bin/flutterguard.dart check "<ERP>\lib" --json > <scratch>\pilot3.json }
dart run bin/flutterguard.dart check "<ERP>\lib" --by-gate > <scratch>\pilot3-gates.txt
```

Rules for this step:

- The `--json` run is the primary record: same flags as round 2,
  no `--jobs`, no `--baseline`, no `--diff`, no `--analyze`.
- The `--by-gate` run is timing + per-gate table only (31.6 s
  comparison); verdicts come from the JSON run.
- Exit codes: 0 clean-or-warnings, 1 errors, 2 usage. Warnings
  never fail the gate. Record the exit code of each run.
- Human summary shape: `N violation(s) (E errors, W warnings)
  in <target>.` JSON carries `summary: {errors, warnings}`.

## 2. Headline table

Rebuild the §0 table with a pilot-3 column:

| | `fb61306` (pilot 2) | pilot 3 |
|---|---|---|
| Files read clean | 694 / 694 | ? / N |
| Parse errors (`FG-SYN-017`) | 0 | ? |
| `FG-FMT-016` on Windows | runs, zero findings | ? |
| Generated-file findings | 0 | ? |
| Time | 31.6 s | ? |
| Total findings | 2,355 | ? |
| Duplicates (file, line, rule) | 76 | must be 0 |

Per-rule counts table (`rule_id`, findings, files) for every rule
with findings, mirroring the round-2 table. Any rule at zero that
was nonzero in round 2 needs a one-line cause (fixed vs silent).

## 3. Required re-verifications (§5 bar)

Sampling protocol: when a rule has ≤ 10 findings, check all of
them; otherwise sample ≥ 6 spread across files. Every sampled
finding is judged against the code as TP or FP with `file:line`
and cause. New FP classes (shapes never sampled before) are
always reported, even singletons.

Must-be-clean shapes (round-2 FPs, fixed in R2-1–R2-4):

- `FG-ASYNC-002`: `FiscalContext` locals
  (`emission_readiness_service.dart:64`), `SecurityContext`
  properties (`sefaz_soap_client_io.dart:70`), the 31-findings
  service file, mounted blocks (`printer_page.dart:70`,
  `open_pdv_page.dart:115`), `context:` label shapes.
  Bar: ≈0 FP on `data/`/`engine/`/`service` files.
- `FG-RIV-001`: the three §1.1 shapes (`company_page.dart:47`,
  `category_repository.dart:47`, `pdv_page.dart:1177`).
- `FG-LIFE-001`: cascade `ref..onDispose`
  (`boot_resolver_io.dart:47`), constructor-received controllers
  (`cnpj_input_step.dart:30`, `whatsapp_phone_field.dart:27`),
  `stop`/`close` releases (`fiscal_sync_worker.dart:113`,
  `hybrid_log_sink.dart:265`).
- `FG-BUILD-014`: indirect subclass (`BootResolverImpl`).
- `FG-LINT-009`: above-line `//` rationale (the 28 sampled);
  same-line form stays clean.
- `FG-CTX-006`: builder signatures (`pdv_workspace_page.dart:44`)
  and method parameters (`NotificationService`, `*FieldBuilder`).
- `FG-MET-007`: holder-widened models (note: true primary ctors
  are unmeasured by design per the §2.6 correction, not exempt).
  Depth holds at 5; record the new count vs 1,913.
- `FG-KEY-001r`: foreign targets (`danfe_printer_service.dart:439`,
  `nfce_daily_cfop_chart.dart:367`) and static lists clean.

Must-still-flag shapes (true post-await `BuildContext` uses for
ASYNC-002 included): if the ERP has no witness for a rule, write
"no witness in corpus" — do not invent one.

## 4. Real-signal retention

These round-2 true positives must still flag, same files:

- `FG-ARCH-003`: Drift queries inside `cbenef_search_widget.dart`
  (and the `cclasstrib_search_widget.dart` twin).
- `FG-LIFE-001`: undisposed controller in
  `support_mode_selection_modal.dart:35`.
- `FG-LINT-009`: the 13 fully-empty catches as ERRORS
  (incl. the `connection_io.dart` trio); comment-only catches
  as WARNINGS.

## 5. Rules new since `fb61306`

Default-ON rules that did not exist in round 2 — judge EVERY
finding (counts are expected to be small):

- `FG-TOK-020`, `FG-ENC-022`, `FG-CC-025`, `FG-RIV-026` (warning),
  `FG-PII-028`.
- `FG-ARB-027`, `FG-ENV-029`, `FG-ASSET-030`, `FG-VER-031`,
  `FG-DOC-032` only read non-`lib/` scopes; expect zero on a
  `lib/` target unless the tree carries those files.

Silent-without-config rules (`FG-BAN-018`, `FG-LOG-019`,
`FG-I18N-021`, `FG-ORP-023`, `FG-LYR-024`, `FG-TST-033`) must be
absent from the output. If any fires with no config present,
that is itself a pilot finding (defaults bug).

## 6. Adoption-engine demo (baseline + diff)

Still on the untouched ERP checkout, baseline path OUTSIDE it:

```powershell
dart run bin/flutterguard.dart check "<ERP>\lib" --baseline <scratch>\baseline.json --update-baseline
dart run bin/flutterguard.dart check "<ERP>\lib" --baseline <scratch>\baseline.json
dart run bin/flutterguard.dart check "<ERP>\lib" --diff --diff-base origin/main
```

Expected: the first command exits 0 with a delta note; the second
is green (legacy adopted, only-above-baseline would report); the
`--diff` run scopes to `git diff --name-only` of the merge-base
with HEAD. If the ERP checkout is not git, `--diff` exits 2 with
the cause named — record as blocked-with-cause, not as a failure.
Record the merge-base hash when git is present.

## 7. Optional: `--jobs` field check

The isolate-parallelism follow-up landed after the R2 program
(`3f2bf85`). If time allows, validate it is finding-identical in
the field:

```powershell
dart run bin/flutterguard.dart check "<ERP>\lib" --json --jobs 4 > <scratch>\pilot3-jobs4.json
```

Compare the two JSON runs on sorted `(file, line, rule_id)`
tuples: the sets must be equal (only `ms`/timings may differ).
Report equal-or-first-difference plus both timings.

## 8. Report

Archive a verbatim report next to the round-2 report in
`docs/pilots/`, mirroring its three parts: prior criticisms
(resolved / partial / open, with proof), new criticisms (with
`file:line` samples), and the ERP verdict. Include the §0-style
numbers table, the per-rule table, and the per-rule TP/FP
samples. Until the §5 bar is fully met, the ERP stays off-gate
on the selective yaml (ARCH-003, ST-001, ST-005 on; LIFE-001
advisory; rest off) and the three real-signal classes are fixed
out of band.

Deliberately out of scope for this pilot: R2-6 (already executed
via r26-fiscal-03), Tier-2, any ERP-side fix, and
`--analyze` / `--dep-audit` / `--license-audit` (may be recorded
as extras, never mixed into the identical-run numbers).
