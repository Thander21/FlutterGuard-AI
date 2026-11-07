---
spec_version: "openspec-1.0"
id: "SYS-CAL-004"
title: "Field calibration round 3: MVP precision program"
status: "draft"
kind: "system"
---

# 1. Problem

The MVP external evaluation (FOLLOWUP-01 F-011: FG `bc46a7b`
via read-only worktree, ERP `lib/` at `a6e17772`) returned
APROVAR-COM-RESSALVAS: the engine is MVP-ready (697/697
parse-clean, 0 duplicates, `--jobs 4` finding-identical,
baseline update→green, `--diff` scoped), but not on default
rules — only on a selective yaml. Two blocking rules carry 54%
of the 516 errors (FG-ASYNC-002 at 0/12 sampled, FG-ENC-022 at
4/109 on PT-BR); with the FG-TOK-020 theme self-findings the
share reaches 75%. CAL-003 §5 adjudicated 6 bars MET, 2 NOT
MET (ASYNC precision, no-new-FP-class).

This spec charters the round-3 precision program that makes
defaults gate-worthy. Unlike R2, the failure mechanisms were
verified against the repo and the ERP checkout BEFORE
chartering (intake turn, §2) — the fix turns start from pinned
mechanisms, not hypotheses. Rule-behavior changes amend their
owning TS contracts via the `fg-spec` flow; each ships with
golden vectors or regression tests plus a spec diff.

Scope note: the ERP stays calibration corpus #1, not the mold.
External corpora from the `docs/prompt.md` program join as
corpus #2+ when their reports land (needs the origin push);
§7 binds every item to multi-project generality.

# 2. Evidence Verification (done at intake, 2026-11-07)

- ENC-022 spec bug CONFIRMED (F-012): TS-22 treats lone
  U+00C3/U+00C2 as markers while "never trips" only holds for
  lowercase. Byte proof: TP `terminal_model.dart:80` is
  `C3 83 C5 A1` (marker + non-ASCII follower), FP
  `boot_resolver_io.dart:123` is `C3 83 4F` (marker + ASCII).
- ASYNC-002 mechanisms CONFIRMED (F-013) against
  `async_context_guard.dart`: (M1) `_flagSinks` fires on the
  whole pre-armed statement subtree before descending, so
  nested guards are dead letters (`printer_page.dart:70`,
  `reseller_page_smartform.dart:128` — the R2-1 witness
  itself); (M2) compound arming marks whole try/if bodies
  from the first statement (`main.dart:160` before any
  await); (M3) the awaited call's own args/builder flag
  (`waiter_cart_page.dart:44`). `&&`/`||` guards stay the
  KNOWN documented gap (TS-06:138), now load-bearing.
- Fixture-fidelity gap CONFIRMED: R2-1 fixtures placed guards
  as direct siblings and missed real nesting (same family in
  RIV-001 Consumer-in-dialog). R3 fixtures MUST include the
  nesting (bar in §5).
- LIFE-001 helper gap CONFIRMED (F-014): releases collected
  as direct receivers only (`lifecycle_guard.dart:265`);
  `destroy()` outside the release set (`:395`).
- Baseline absolute keys and TOK empty-except CONFIRMED
  by design (F-015/F-016). LAY strictness is DOCUMENTED T3
  behavior (contract question, not bug). RIV depth
  inheritance CONFIRMED (same nesting family). MET
  measurement correct (format + budgets question).
- F-012–F-017 rows carry every sample with file:line.

# 3. Remediation Program

## R3-1. FG-ENC-022: pair grammar

Marker-plus-follower rule per ratified Q1 + TS-22 "never
trips" correction. Vectors: TP pairs (incl. `C3 83 C5 A1`
and `C3`-plus-C1 shapes) + FP capitals ("NÃO",
"HIDRATAÇÃO") + intentional accent tables. Amends TS-22.
Acceptance: the 109-case ERP census re-judged (4 TP flag,
105 clean); golden gates green.

## R3-2. FG-ASYNC-002: nesting, order, args, chains

(a) Nested-guard honoring (prune mounted-guarded subtrees
before outer flagging, per Q2); (b) statement-order arming
inside compounds (an await arms subsequent siblings only);
(c) await's-own-args/builder carve-out (scope per Q2);
(d) `&&`/`||` guard grammar v1 (forms per Q2). Fixtures
from the :70/:128/:160/:44 shapes INCLUDING nesting, plus
the full `reseller :113–128` method shape. Amends TS-06.
Acceptance: the 12-sample re-judged clean where the
contract says clean; true post-await uses still flag (a TP
witness is required — if the ERP has none, vectors carry
it); order-dependent cases (`desktop_setup:149`,
`pdv_page:289`) discriminated by fixture (M1 vs
stale-correct).

## R3-3. FG-LIFE-001: helpers, lifecycle, transfer

One-level helper following and/or releaser config,
lifecycle-set extension, Autocomplete-transfer rule — all
per Q3. The 2 TPs (`support_mode_selection_modal:35/:36`)
must keep flagging. Amends TS-04. Acceptance: the 14-case
census lands per contract with a reason per case.

## R3-4. Adoption: portable baseline, quiet theme default

Relative/root-anchored baseline keys per Q4 (with absolute
read-compat); TOK default except (or warn-when-unconfigured)
per Q5. Amends CLI-001a (+ TS-20/init template). Acceptance:
a baseline written on one checkout applies on another
(two-clone test); TOK self-findings gone by default or
warned; legacy-adopt demo stays green.

## R3-5. Secondary batch

RIV nested re-entry, LINT fourth rationale format, ARCH
exception-type carve-out (all per Q6); BUILD-014 message fix
(trivial, rides along); MET const-params doctrine +
per-line format call (per Q7 — const-entity data is ripe).
KEY n=1, CTX vacuous, LAY strictness, MET display getters:
NO action (watch/accepted/deferred — re-entry is new
samples). Amends TS-02/TS-11/TS-05/TS-14/TS-13 as decided.

# 4. Open Questions (owner review before implementation)

1. ENC pair grammar: exact follower rule. RECOMMENDED:
   decoded-text rule — a marker codepoint (U+FFFD/U+00C3/
   U+00C2) flags iff followed by a codepoint ≥ U+0080
   (TP Ã+Ł fires, FP Ã+O and EOL-Ã pass; strict-decode
   failures stay a separate finding). REJECTED: narrower
   C1+Latin-1 follower set (misses the observed Ł case).
   RATIFIED 2026-11-07: decoded-text rule adopted.
   IMPLEMENTED AS (flutterguardai): narrower anchored pair - uppercase C3/C2
   + ghost (U+0080-U+00BF, incl. CP1252 0x80-0x9F display forms) + E2 20AC
   ghost + U+FFFD. Behaviorally equivalent on corpus (4/4 TP incl. U+0161,
   0 FP on 108 former FPs). RE-RATIFIED 2026-11-07 to the implemented
   variant: tighter codepoint grounding, same observable outcome.
2. ASYNC fix shape. RECOMMENDED: (i) `_flagSinks` prunes
   mounted-guarded subtrees (early-return + mounted-block)
   before collecting; (ii) compounds scan children with
   PRE-statement armed (statement-order); (iii) carve the
   awaited call's own argument subtrees, and builder
   closures of recognized show/dialog functions (narrow,
   evidence-backed: the ERP passes `use_build_context_
   synchronously` on exactly these); (iv) recognize
   `||`-chains containing a negated mounted check as
   early-return guards and `&&`-chains containing an
   affirmative one as block guards, any position in chain.
   Alternatives: broader builder carve-out, leading-only
   chains — wider/narrower, owner picks.
   RATIFIED 2026-11-07: full package ((i) prune, (ii)
   statement-order, (iii) await-args + show/dialog-builder
   carve-out, (iv) any-position chains).
   IMPLEMENTED AS (flutterguardai): headers-only prune + statement-order +
   entry-state inheritance (Builder/showDialog via entering-scope rule,
   not always-safe) + await-args + polarity-aware any-position chains +
   exiting-branch extra (await-then-always-exit branch is not a gap;
   retro-adopted into the charter during merge, RED-written by the
   implementing session). Result on corpus: 169 -> 15 (11 TP + 4 FP on
   already-pushed context closures, next-series gap).
3. LIFE scope. RECOMMENDED: config over hardcode (a
   `releasers:` list for helper/lifecycle names — the
   project-varying surface per CAL-003 §7) plus one-level
   same-file helper following; Autocomplete transfer via
   callee-name rule + config. `destroy` joins via config,
   not the standing set.
   RATIFIED 2026-11-07: option A (config + one-level
   following) adopted.
   IMPLEMENTED AS (flutterguardai): K2 hardcoded + destroy-entry +
   dispose-aliases + broadened borrowed; NO config mechanism (the config
   half of the ratification is CARRIED as R3 residue). Behaviorally
   complete on corpus: 14 -> 4 (2 TP incl. support-modal leak, 2 known
   open on Drift widgets + late-init).
4. Baseline keys. RECOMMENDED: relative to the enclosing
   git toplevel (fallback: target dir); v1 readers keep
   accepting absolute keys, writers emit relative.
   RATIFIED 2026-11-07: option A (git-toplevel-relative
   + absolute read-compat) adopted.
   IMPLEMENTED AS (flutterguardai): pubspec-anchored resolution (nearest
   enclosing pubspec.yaml, falling back to git toplevel). Owner decision
   recorded in the handoff: pubspec anchoring is sufficient (per-project
   baselines live below the pubspec, not at the mono-repo root).
   SUPERSEDES the git-toplevel half of the ratification; absolute
   read-compat kept as ratified.
5. TOK default. RECOMMENDED: ship a narrow default except
   (`**/themes/**`, `**/theme/**` — a theme's own files
   legitimately construct colors) + init-template note.
   Alternative: status quo + README callout (stays noisy).
   RATIFIED 2026-11-07: option A (narrow default except
   + init-template note) adopted.
   IMPLEMENTED AS (flutterguardai): superset (theme dirs + *_theme.dart +
   *_colors.dart + color_scheme*). A filename that declares palette
   purpose (*_colors) belongs with the theme-file carve-out by the same
   rationale, and the field corpus offers zero counter-evidence (all 108
   former FPs came from theme dirs; no *_colors file exists in the ERP).
   KEPT 2026-11-07; projects may narrow via configured except.
   RE-RATIFIED to the implemented set.
6. Secondary grammars. RECOMMENDED: inner build scope
   resets RIV depth; accept comma-led inline rationale
   (`, <non-empty text>`) for LINT; carve ARCH imports
   referenced only in catch/on type positions.
   RATIFIED 2026-11-07: option A (all three) adopted.
   IMPLEMENTED AS (flutterguardai): PARTIAL. RIV-001 done via ref-rebind +
   when(data:)/map + any-*Builder (minus optionsBuilder) - mechanism
   differs from the ratified inner-reset sketch; accepted, with one
   documented edge (outer-ref mutation inside an inner *Builder still
   flags, next-series). LINT-009 done as a superset (dash + AR/wildcard
   markers + comma-before-noncode); RE-RATIFIED to the implemented
   definition. NOT DONE: ARCH-003 lib/src carve-out, BUILD-014 actionable
   message - both CARRIED to the follow-up series.
7. MET doctrine + format (A3, data ripe for the first).
   RECOMMENDED: const classes whose constructor takes only
   named parameters count as holders (extends the holder
   doctrine to idiomatic immutable value objects); keep
   per-line format for MVP (advisory + baseline cover it),
   revisit on corpus #2. Display getters stay deferred
   (no samples arrived).
   RATIFIED 2026-11-07: option A (const-named holder;
   per-line kept; display getters deferred) adopted.
   NOT DONE (flutterguardai): MET-005 untouched in this series (1,826
   warnings on the merged tree). CARRIED to the follow-up series along
   with the display-getter samples. The re-pilot MET sample re-probed
   28/28 consistent; corpus MET share re-keyed to 192 (see CAL-001 §5).
8. Field access: owner re-runs the MVP battery post-R3 on
   ERP `lib/` (same read-only method) + at least one
   external corpus via `docs/prompt.md` (needs the origin
   push). Who/when?
   RATIFIED 2026-11-07: option A (owner ERP re-run +
   1 external corpus via prompt) adopted.
   PARTIAL: the ERP re-run executed post-merge on f8db2eaa (see §9).
   External corpus still pending (blocked on push: docs/prompt.md pins
   commits not yet on origin).

# 5. Acceptance (post-R3 bar)

Re-run the MVP battery on ERP `lib/` plus ≥1 external
corpus: ENC FP class gone (capitals clean, 4 TP flag);
ASYNC samples clean-per-contract with a flagging TP
witness; LIFE census per contract; baseline portable
across checkouts; TOK default self-clean; no NEW FP class
in samples; real signals retained (Drift widgets,
support-modal leak, empty catches); suite + grade green;
fixture-fidelity bar holds (every fix fixture carries its
real nesting); bars hold on vectors + dogfood + external
corpus. Until then the F-011 selective yaml stands.

# 6. Non-goals / stays-deferred (B triage recorded)

TS-24 allow-graph, TS-30 vice-versa, TS-25 warn-20, TS-20
swatches, TS-05 layer map, TS-02 unwired doctrine,
line-level diff, analyze auto-wire, COV/DRY enforcement
flips (owned by CAL-001's bar), other-framework packs,
Tier-2 — each keeps its recorded re-entry; none enters
R3. KEY/LAY-strictness/CTX/MET-display-getters stay
watch/accepted/deferred as §3 states.

# 7. Multi-project Scope

Inherits CAL-003 §7: ERP is corpus #1, external corpora
join via the prompt program; every new grammar ships
fixtures from 2+ shapes; project-varying surfaces ship as
config; framework knowledge stays pack-local; §5 bars must
hold on golden vectors + dogfood as well as field corpora.

# 8. Implementation Status

- Chartered 2026-11-07 from F-011–F-017 (MVP run at
  `bc46a7b` / ERP `a6e17772`). Q1–Q8 await owner review;
  no implementation starts before ratification.
- RATIFIED 2026-11-07: Q1–Q8 all adopted as recommended
  (option A throughout). Program unblocked: R3-1 → R3-5
  proceed in pilot order via the `fg-spec` flow; status
  stays draft until the round closes (CAL-003 precedent).
  MERGED 2026-11-07: reconciled with the flutterguardai execution record
  (units 1-6 + re-pilot). Carried items keep this charter open: MET-005,
  ARCH-003, BUILD-014, LIFE config half, external corpus. The handoff
  patch was LOSSY (35 of the worktree's 37 modified files): the LAY-004
  single-Row exemption arrived as its test half only, which was REVERTED
  during merge; the lib half (list_viewport_guard) + TC-07 tweak never
  arrived. The merged tree is strict throughout (Rows pass unbounded
  constraints) - the correct end state, §9. Future handoffs must verify
  patch-file-count == worktree-modified-count.

## 9. Execution Record (flutterguardai, merged 2026-11-07)

  Units (each: failing probes -> guard fix -> TS spec + TC vectors + rule
  tests + full suite): (1) ASYNC-002, (2) ENC-022, (3) baseline-relative +
  CLI-001a, (4) TOK-020 + LINT-009 + init --scaffold docs, (5) LIFE-001 +
  RIV-001 + LAY-004 + TS-00, (6) calibration_test recalibration. All
  RED-written by the implementing session; full suite green.

  Re-pilot on the ERP (their tree, pinned a6e17772, WITH the Row
  exemption): 1,954 total, 117 errors. Merged tree (f8db2eaa, exemption
  reverted): 1,974 total, 130 errors - LAY-004 back to 80, TP
  sale_history:160 restored. Per-rule (before -> after): ASYNC-002
  169 -> 15 (11 TP + 4 FP on pre-pushed context closures), ENC-022
  109 -> 4 (the 4 real mojibakes), TOK-020 111 -> 3, LIFE-001 14 -> 4,
  RIV-001 2 -> 0, LAY-004 80 -> 80 (exemption reverted; unchanged from
  round baseline), LINT-009 34 -> 27, MET-005 1,826 (untouched),
  ARCH-003 5, BUILD-014 1, CC-025 1, KEY-011 1.

  FP accounting: 36 sampled FPs eliminated (their PT report says 36 of
  37; HANDOFF says 37 of 40 - the two sample sizes differ by 3,
  unresolved handoff noise, immaterial to the merged verification below).
  pdv_total_bar.dart:58 (spaceBetween Row) is an admitted pendency
  misfiled in the elimination checklist - confirmed still flagging on
  the merged tree, pre and post. All 24 confirmed TPs retained (>=14
  errors/__tests__ probes + LAY/ENC/TOK spot probes). Determinism: --jobs 1 == --jobs 4
  (1,974 == 1,974, diff 0) on the merged tree; baseline writes
  lib/-relative keys and the second run exits 0; extra_stable = 0
  (zero new findings on files unchanged between a6e17772 and f8db2eaa;
  the 29 deltas all fall in 9 ERP-evolved files, e.g. the pdv_page
  :1229 -> :1238 line-shift under the rzero31 refactor).
