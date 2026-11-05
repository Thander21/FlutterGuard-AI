---
spec_version: "openspec-1.0"
id: "SYS-VIEW-001"
title: "Tier-1 viewport runner (native visual gate)"
status: "approved"
kind: "system"
---

# 1. Problem

Static rules cannot see a rendered screen: `RenderFlex overflowed`
under an open keyboard, truncated text at 2x font scale, or a
landscape split that squeezes a fixed-width row all pass `check`
while breaking production. This contract pins the native Tier-1
runner that pumps widgets headless under a fixed adversarial matrix,
intercepts `FlutterError`s, harvests screenshots for Tier-2, and
fails closed on any layout break — plus the AST fallback that stands
in where the Flutter SDK is absent.

# 2. Interface / Schema

Two surfaces, one verdict vocabulary (`clean` / `layout-break`):

## Full harness (`viewport/` rig, Flutter SDK required)

```dart
/// One adversarial configuration (logical px).
class Tier1Case {
  const Tier1Case({
    required this.name,
    required this.size,       // e.g. Size(320, 480)
    this.viewInsetsBottom = 0, // e.g. 320 (open keyboard)
    this.textScaleFactor = 1, // e.g. 2 (accessibility zoom)
  });
}

/// The fixed 6-case matrix (§2 table below). Never extended ad hoc:
/// membership changes amend this spec.
const tier1Matrix = <Tier1Case>[...];

/// Pumps [app] under [c], captures FlutterErrors, writes
/// `<snapshotDir>/<fixture>_<case>.png`, restores the test view.
/// Returns the collected error summaries (empty = clean).
Future<List<String>> runTier1Case(
  WidgetTester tester, {
  required Widget Function() app,
  required Tier1Case c,
  required String fixture,
  String snapshotDir = 'build/test_snapshots',
});

/// Appends one SYS-TELE-001 line per case verdict (amendment
/// SYS-VIEW-001); a no-op when [evidencePath] is null.
void appendTier1Evidence({
  required String fixture,
  required Tier1Case c,
  required List<String> errors,
  String? evidencePath,
});
```

Fixed matrix (canonical 4 from DisruptiveInnovations §1 item 3,
unioned with the 2 PDV D+ adversarial resolutions from
`uilayout.md` via ReferencePdvDMais §1). Device pixel ratio is 1.0
for every case (deterministic pixels, small PNGs):

| # | name | size | inset / scale | source |
|---|------|------|---------------|--------|
| 1 | `compact-pos` | 320x480 | — | canonical POS |
| 2 | `keyboard-inset` | 320x480 | `viewInsets.bottom` = 320 | canonical |
| 3 | `a11y-zoom` | 320x480 | `textScaleFactor` = 2.0 | canonical |
| 4 | `landscape-split` | 512x768 | — | canonical, concretized as half of the 1024x768 tablet in split mode |
| 5 | `pdv-1024x768` | 1024x768 | — | PDV D+ `uilayout.md` |
| 6 | `pdv-800x600` | 800x600 | — | PDV D+ `uilayout.md` |

Error wiring: the harness overrides `FlutterError.onError` for the
case duration, drains `tester.takeException()` after `pumpAndSettle`,
and restores the previous handler in a `finally`. Any collected
error — `RenderFlex overflowed`, unbounded-viewport throws,
`pumpAndSettle` failures — is a `layout-break`. The matrix test
asserts per-fixture: `.bad` breaks on at least one case (red),
`.good` is clean on all six (green).

Screenshots: manual `RenderRepaintBoundary` capture (no
`golden_toolkit` dependency, §6), PNG per fixture+case into
`build/test_snapshots/` (volatile, gitignored). Pixels are Tier-2
feed, never the Tier-1 verdict: the verdict comes from
`FlutterError`s only.

Timeout: each matrix-case test carries
`timeout: Timeout(Duration(seconds: 8))` — the Flutter-native
mapping of the Architecture §2.5 circuit breaker (an in-process
test runner cannot be `Process.kill`ed; the test package enforces
the budget instead). A timeout fails the case (fail-closed).

Evidence emission is opt-in: the matrix test reads
`String.fromEnvironment('FG_EVIDENCE')` (empty = pure, no writes).
Proof runs pass `--dart-define=FG_EVIDENCE=../evidence.jsonl`.

No new dependencies for the root package. The rig depends only on
Flutter's `flutter_test` (SDK).

## Lite fallback (root package, pure Dart, no SDK)

```dart
/// True when a `flutter` executable resolves on PATH.
bool isFlutterSdkAvailable();

/// Runs the viewport-relevant AST rules (v1: FG-LAY-004 only) over
/// [target] (file or directory, same walk/sort as `checkPath`).
/// A degraded stand-in: reports what AST can see and says plainly
/// what it cannot (rendered overflow needs the full harness).
Tier1LiteResult runTier1Lite(String target);
```

Selection rule: SDK present → full harness (`flutter test` in the
rig); SDK absent (CI without Flutter) → lite. The caller selects;
this contract provides both ends and the detector.

# 3. File Placement

- `specs/system/SYS-VIEW-001-tier1-viewport.md` (this contract).
- Rig (Flutter package, `publish_to: none`, never distributed):
  - `viewport/pubspec.yaml` (SDK `flutter_test` dev-dep only).
  - `viewport/lib/tier1.dart` (cases, matrix, runner, evidence).
  - `viewport/test/tier1_matrix_test.dart` (contract test: bad red,
    good green, evidence keys on a temp file, 8s timeouts).
  - `viewport/test/fixtures/bad_layout.dart` (fixed 2000px row:
    overflows every case, max width 1024).
  - `viewport/test/fixtures/good_layout.dart` (scroll-wrapped row:
    clean on all six).
  - Generated: `viewport/build/test_snapshots/*.png` (volatile).
- Lite (root package, pure Dart):
  - `lib/src/viewport/lite.dart` + package-root re-export.
  - `test/viewport_lite_test.dart` (reuses `TC-07_lay` vectors;
    SDK detector tested with an injected PATH, never asserted
    against the ambient machine).
- Root gates (`dart test`, `dart analyze lib bin test`, `grade`,
  `check`) never touch `viewport/`; the Tier-1 gate is
  `flutter test` run with cwd `viewport/`.

# 4. Evidence Wiring

Tier-1 amends SYS-TELE-001 (amendment SYS-VIEW-001): same 9 keys,
`phase` = `VIEWPORT_GATE`, `rule_id` = `SYS-VIEW-001`,
`file` = `<fixture>:<case>`, `status` = `FAILED` on layout-break /
`PASSED` when clean (same gate semantics as grade),
`error_message` = first single-line `FlutterError` summary,
`action` = `EVAL_RECORDED`. Emission only via explicit
`evidencePath` (default pure). The `commit-check` presence rule
covers Tier-1 lines once emitted.

# 5. Errors and Edges

- `pumpAndSettle` never settles (endless animation): the 8s test
  timeout fires → case FAIL. Fixtures must settle; the harness
  does not shorten `pumpAndSettle`.
- Async errors escaping the pump: caught by the `onError`
  override + `takeException()` drain; anything collected fails
  the case. The previous handler is always restored.
- Bad fixture clean on every case: the test fails — a `.bad`
  fixture that never breaks is a broken fixture (same doctrine
  as golden vectors).
- Screenshot capture failure: fails the case (fail-closed —
  Tier-2 feed is part of the contract, not a best effort).
- Missing `viewport/.dart_tool` (no `flutter pub get`): `flutter
  test` errors with the standard SDK message; the rig documents
  the one setup command.
- Lite over a missing target: `ArgumentError` (same as
  `checkPath`). Lite findings are a subset vocabulary (`FG-LAY-004`
  in v1); lite PASS never claims rendered-clean — the result
  carries the `sdkAvailable` flag and the degraded-mode note.
- Flutter widget tests stay out of `SYS-MUT-001` (pure `dart
  test` there); `flutter test` invocation belongs to this
  contract only.

# 6. Contradictions Resolved

- Screenshot mechanism (PLAN-02): manual `RenderRepaintBoundary`
  capture ("takeScreenshot-style") wins — zero new dependencies,
  raw PNGs feed Tier-2 directly. `golden_toolkit` is rejected
  (golden-file workflow answers a question Tier-1 never asks:
  pixels don't vote here).
- Keyboard inset: 320px (DisruptiveInnovations §1 item 3,
  Architecture §3.2, SddEddWorkflow) wins; the 300px variant in
  DisruptiveInnovations §Vision item 3 is superseded.
- Rig placement vs single-package layout (Architecture §4,
  PLAN-01): the root stays the single DISTRIBUTED package (one
  published pubspec; `flutter_test` cannot resolve under
  `dart pub get`, and converting the root would rewrite every
  gate command). `viewport/` is a non-published test rig
  (`publish_to: none`), same category as `benchmark/` fixtures.
  Target-project consumption of the harness is decided in the
  distribution phase, not here. Decided Wave 2 (SYS-VAL-001 F5):
  DROP — lite suffices, see SYS-MCP-001 §6 for rationale + re-entry.
- ` Landscape Split Ratio` (undimensioned in docs) is
  concretized as 512x768 (half of the 1024x768 PDV tablet in
  split mode); PDV resolutions enter as their own cases, not
  folded into the split case.
- MCP `verify_viewport(test_file)` (Architecture §3.2) is the
  future P3 caller of this harness; the tool itself belongs to
  SYS-MCP-001.
