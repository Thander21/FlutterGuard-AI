// FG-TST-033: lib files need mirror tests.
//
// New logic files land without tests: the suite stays green
// because nothing exercises the new code. Every `.dart` file
// under a `lib/` directory must have its mirror test (`test/`
// plus the `_test.dart` suffix). Layouts vary by project, so
// the rule stays silent until a `test_presence:` section opts
// in; newness comes from the run (`--diff` or the baseline),
// never from the rule itself.
import 'dart:io';

import '../rule_params.dart';
import '../util.dart';
import 'rule_violation.dart';

/// A single FG-TST-033 violation.
class TstViolation implements RuleViolation {
  const TstViolation({required this.line, required this.message});

  /// Always 1 (the whole file is the finding).
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-TST-033 violation found.
///
/// [enabled] injects the opt-in (tests); without it the nearest
/// `flutterguard.yaml` is discovered and the rule runs only with
/// a `test_presence:` map section.
List<TstViolation> analyzeTstFile(String path, {bool? enabled}) {
  final on = enabled ?? RuleSection.load(path, 'test_presence').value is Map;
  if (!on) return const [];
  final normalized = path.replaceAll(r'\', '/');
  if (isGeneratedDartFile(normalized)) return const [];
  if (_isLibMain(normalized)) return const [];
  final mirror = mirrorTestFor(path);
  if (mirror == null) return const [];
  if (File(mirror).existsSync()) return const [];
  return [
    TstViolation(
      line: 1,
      message:
          "'${normalized.split('/').last}' has no mirror test "
          "'${mirror.split('/').last}'; add it under test/",
    ),
  ];
}

/// True for `<...>/lib/main.dart` (the package entrypoint —
/// wiring, not logic). Deeper `main.dart` files are logic like
/// any other file.
bool _isLibMain(String normalized) {
  final segments = normalized.split('/');
  if (segments.length < 2 || segments.last != 'main.dart') return false;
  return segments[segments.length - 2] == 'lib';
}
