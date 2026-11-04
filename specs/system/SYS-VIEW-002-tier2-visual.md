---
spec_version: "openspec-1.0"
id: "SYS-VIEW-002"
title: "Tier-2 visual gate (SAM/Vision) — deferred"
status: "deferred"
kind: "system"
---

# 1. Problem

Tier-1 catches rendered breakage the harness can see for free
(`FlutterError`s under an adversarial matrix). Tier-2 was meant to
see what errors cannot: occluding buttons, truncated text, weak
contrast — via SAM 3.1 geometry plus a Muse/Vision semantic audit.
This contract records the Phase 5 go/no-go: the endpoints do not
verify, so Tier-2 is explicitly DEFERRED with Tier-1 standing as the
visual gate. Nothing in the product depends on Tier-2.

# 2. Interface / Schema

No interface ships in v1 (deferred). The go/no-go verification ran
2026-11-03 with this result:

| check | method | result |
|---|---|---|
| SAM endpoint documented? | read `.agents/metaai/SamSegmentAnything.md` + repo-wide URL search | NO — §4 lists "explore Meta's SAM docs" as a study item; zero endpoint URLs, SDKs, or auth schemes anywhere in `docs/`, `.agents/`, `lib/`, `bin/`, `viewport/` |
| Vision endpoint documented? | read `.agents/metaai/MuseImageVision.md` | NO — prompt format for "the Meta multimodal API" (unnamed, no URL/auth); §4 lists Base64 + verdict prompting as study items |
| Credentials configured? | env scan (`META*`, `SAM*`, `VISION*`, `API*`, `TOKEN*`, provider keys) + repo secret scan | NO — only Muse CLI session vars (own runtime, not a vision API) and `OLLAMA_HOST` |
| Local model server? | `curl localhost:11434/api/tags` (8s) | NO — connection refused (exit 7) |
| Documented output shape valid? | PLAN-02 pre-audit | NO — SAM `"label": "button"` outputs as sketched are invalid (SAM emits masks, not semantic labels); mask→widget identity mapping was never designed |

Go criteria (all required, none met): reachable endpoint URL +
working auth + verified response schema + mask→widget identity
design (render-tree dump/debug keys). Verdict: NO-GO.

Standing cover (what guards visuals today): SYS-VIEW-001 —
6-case headless matrix (`FlutterError` verdicts), 12 PNGs per run
harvested to `build/test_snapshots/` as the Tier-2 feed the day it
exists, plus Tier-1-lite AST fallback. Suite: `flutter test` 14/14
in `viewport/`.

Re-entry criteria (any future Tier-2 work starts here, not from
this file's sketches): (1) a reachable endpoint + credentials the
maintainer can rotate; (2) a verified response schema (masks with
pixel coordinates, no semantic labels unless the provider emits
them); (3) the mask→widget identity design; (4) overlap/tap-target
thresholds with the calibration corpus behind them (SYS-CAL-001);
(5) offline behavior (fail-closed or explicit skip — decided then).

# 3. File Placement

- `specs/system/SYS-VIEW-002-tier2-visual.md` (this record; the
  grader skips `specs/system/` non-recursively and `kind: system`
  explicitly).
- No `lib/`, `bin/`, or `test/` files: a deferral ships no code.
  Validation is this record plus the Tier-1 suite staying green
  (standing cover), not a unit test — there is nothing to execute.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: no gate runs. Tier-1 lines (amendment
SYS-VIEW-001) remain the only viewport telemetry. Any future Tier-2
emission MUST amend SYS-TELE-001 first (canon rule §4).

# 5. Errors and Edges

- PLAN-02 sub-items decided WITH the deferral (not postponed
  separately): overlap/tap-target thresholds, margin-drift-vs-grid,
  IoU-heatmap — all deferred; no threshold is adopted without the
  endpoint that would enforce it.
- Local-vision (OpenCV) fallback: deferred, not built. Rationale:
  no Dart OpenCV binding is in the dependency tree, native
  dependencies break the zero-setup `dart pub global activate`
  story, and pixel heuristics without calibration repeat the
  uncalibrated-threshold bar (REVIEW-01 §3.9).
- `verify_viewport` (SYS-MCP-001) stays lite-vocabulary v1; the v2
  full-harness orchestration does not imply Tier-2 (it pumps
  Tier-1, not SAM/Vision).
- Re-entry does not resurrect superseded items: `golden_toolkit`
  stays rejected (SYS-VIEW-001 §6), SAM semantic labels stay
  invalid until a provider proves otherwise.

# 6. Contradictions Resolved

- Tier-2 existence (docs assume it, PLAN-01/02 gate it):
  the gate wins — unverified endpoints collapse Tier-2 to this
  recorded deferral with zero schedule impact (nothing depends on
  Tier-2 by dependency design).
- SAM labels (dossier sketch vs PLAN-02 audit): the audit wins —
  confirmed invalid and now moot; re-entry criterion (2) bars
  label-shaped schemas without provider proof.
- Keyboard/matrix overlap with Tier-1: none — Tier-1 owns the
  matrix; Tier-2 would consume its PNGs, never re-pump.
