// SYS-VIEW-001: Tier-1 viewport harness — fixed adversarial matrix,
// FlutterError interception, screenshot harvest, canon evidence lines.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// One adversarial configuration (logical px, device pixel ratio 1.0).
class Tier1Case {
  const Tier1Case({
    required this.name,
    required this.size,
    this.viewInsetsBottom = 0,
    this.textScaleFactor = 1,
  });

  final String name;
  final Size size;

  /// Simulated open-keyboard inset in logical px (0 = no keyboard).
  final double viewInsetsBottom;

  final double textScaleFactor;
}

/// The fixed 6-case matrix (SYS-VIEW-001 §2). Membership changes amend
/// the spec; cases are never added ad hoc.
const tier1Matrix = <Tier1Case>[
  Tier1Case(name: 'compact-pos', size: Size(320, 480)),
  Tier1Case(
      name: 'keyboard-inset',
      size: Size(320, 480),
      viewInsetsBottom: 320),
  Tier1Case(
      name: 'a11y-zoom', size: Size(320, 480), textScaleFactor: 2.0),
  Tier1Case(name: 'landscape-split', size: Size(512, 768)),
  Tier1Case(name: 'pdv-1024x768', size: Size(1024, 768)),
  Tier1Case(name: 'pdv-800x600', size: Size(800, 600)),
];

/// Pumps [app] under [c], captures every `FlutterError`, writes
/// `<snapshotDir>/<fixture>_<case>.png`, and restores the test view.
///
/// Returns the collected single-line error summaries: empty means the
/// case is clean, anything else is a `layout-break`. A screenshot
/// capture failure throws (fail-closed: Tier-2 feed is contractual).
Future<List<String>> runTier1Case(
  WidgetTester tester, {
  required Widget Function() app,
  required Tier1Case c,
  required String fixture,
  String snapshotDir = 'build/test_snapshots',
}) async {
  final errors = <String>[];
  final view = tester.view;
  final dispatcher = tester.platformDispatcher;
  final prevSize = view.physicalSize;
  final prevDpr = view.devicePixelRatio;
  final prevHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(_firstLine(details.exceptionAsString()));
  };
  try {
    // Device pixel ratio 1.0: physical px == logical px, fixed matrix.
    view.devicePixelRatio = 1.0;
    view.physicalSize = c.size;
    if (c.viewInsetsBottom > 0) {
      view.viewInsets = FakeViewPadding(bottom: c.viewInsetsBottom);
    }
    if (c.textScaleFactor != 1) {
      dispatcher.textScaleFactorTestValue = c.textScaleFactor;
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: app()));
    await tester.pumpAndSettle();
    final taken = tester.takeException();
    if (taken != null) errors.add(_firstLine('$taken'));
    await _capture(tester, boundary, '$snapshotDir/${fixture}_${c.name}.png');
  } finally {
    view.physicalSize = prevSize;
    view.devicePixelRatio = prevDpr;
    view.resetViewInsets();
    dispatcher.clearTextScaleFactorTestValue();
    FlutterError.onError = prevHandler;
  }
  return errors;
}

/// Appends one SYS-TELE-001 line (amendment SYS-VIEW-001) for the case
/// verdict. A no-op when [evidencePath] is null or empty (pure mode).
void appendTier1Evidence({
  required String fixture,
  required Tier1Case c,
  required List<String> errors,
  String? evidencePath,
}) {
  if (evidencePath == null || evidencePath.isEmpty) return;
  final clean = errors.isEmpty;
  final line = jsonEncode({
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'phase': 'VIEWPORT_GATE',
    'rule_id': 'SYS-VIEW-001',
    'file': '${fixture}:${c.name}',
    'status': clean ? 'PASSED' : 'FAILED',
    'error_message': clean ? '' : errors.first,
    'recipe_injected': '',
    'iteration': 1,
    'action': 'EVAL_RECORDED',
  });
  File(evidencePath).writeAsStringSync('$line\n', mode: FileMode.append);
}

/// Renders the repaint [boundary] to a PNG file (Tier-2 feed).
Future<void> _capture(
    WidgetTester tester, GlobalKey boundary, String path) async {
  final bytes = await tester.runAsync(() async {
    final context = boundary.currentContext;
    if (context == null) throw StateError('repaint boundary has no context');
    final render = context.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1.0);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('toByteData returned null');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  if (bytes == null) throw StateError('screenshot capture returned null');
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}

String _firstLine(String text) =>
    text.split('\n').first.trim().replaceAll(RegExp(r'\s+'), ' ');
