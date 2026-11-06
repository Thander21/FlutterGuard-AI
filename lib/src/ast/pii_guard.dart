// FG-PII-028: PII in log calls must be masked.
//
// Unmasked e-mail, document, and password data flows from log
// calls into aggregators — an LGPD/GDPR breach surface. Every
// sink-call argument is scanned for PII: literal runs against
// the e-mail shape plus configured patterns, identifier sites
// against the PII names. A site enclosed in a mask call is
// masked. Findings never echo literal spans (the span IS the
// PII — kind plus line only); identifiers echo (names are not
// values). Default-ON: the defaults are universal-only, and no
// settled vector or dogfood root passes PII to a sink.
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
import 'rule_violation.dart';

/// Default log sinks (universal; projects extend via `sinks`).
/// Bare `log` stays out — it collides with `dart:math`.
const _defaultSinks = <String>{'print', 'debugPrint'};

/// Default PII names (cross-language; projects extend via `names`).
const _defaultNames = <String>{'email', 'password'};

/// Default mask verbs (projects extend via `masks`).
const _defaultMasks = <String>{
  'mask',
  'masked',
  'redact',
  'redacted',
  'obscure',
};

/// E-mail shape (TS-28 §3, normative).
final _emailPattern = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');

/// A single FG-PII-028 violation.
class PiiViolation implements RuleViolation {
  const PiiViolation({required this.line, required this.message});

  /// 1-based line number of the sink call.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// A loaded `pii` section: sink/name/pattern/mask lists plus the
/// shared except/message/baseDir tail. The section only EXTENDS
/// the universal defaults — a missing or malformed section still
/// flags (default-ON); malformed entries degrade leniently.
class PiiConfig {
  const PiiConfig({
    this.sinks = const {},
    this.names = const {},
    this.patterns = const {},
    this.masks = const {},
    this.except = const [],
    this.message,
    this.baseDir = '',
  });

  final Set<String> sinks;
  final Set<String> names;
  final Set<String> patterns;
  final Set<String> masks;
  final List<String> except;
  final String? message;
  final String baseDir;

  /// Loads the nearest `pii` section governing [target]. Never
  /// throws on config problems (SYS-CLI-001a §5).
  static PiiConfig load(String target) {
    final found = RuleSection.load(target, 'pii');
    final raw = found.value;
    if (raw is! Map) return PiiConfig(baseDir: found.baseDir);
    final message = raw['message'];
    return PiiConfig(
      sinks: _stringSet(raw, 'sinks'),
      names: _stringSet(raw, 'names'),
      patterns: _stringSet(raw, 'patterns'),
      masks: _stringSet(raw, 'masks'),
      except: _stringSet(raw, 'except').toList(),
      message: message is String ? message : null,
      baseDir: found.baseDir,
    );
  }
}

/// Lenient string set at [key]: skips non-strings and empties.
Set<String> _stringSet(Map section, String key) {
  final raw = section[key];
  if (raw is! List) return const {};
  final out = <String>{};
  for (final value in raw) {
    if (value is String && value.isNotEmpty) out.add(value);
  }
  return out;
}

/// Analyzes [path] and returns every FG-PII-028 violation found.
///
/// [config] injects a section (tests); without it the nearest
/// `flutterguard.yaml` is discovered and loaded.
List<PiiViolation> analyzePiiFile(String path, {PiiConfig? config}) {
  final loaded = config ?? PiiConfig.load(path);
  if (isExcepted(loaded.except, exceptKey(path, loaded.baseDir))) {
    return const [];
  }
  final extraPatterns = <RegExp>[];
  for (final source in loaded.patterns) {
    try {
      extraPatterns.add(RegExp(source));
    } on FormatException {
      continue; // malformed regex drops leniently
    }
  }
  return scanTarget(path, (unit, info) {
    final guard = _PiiGuard(
      info,
      sinks: {..._defaultSinks, ...loaded.sinks},
      names: {..._defaultNames, ...loaded.names},
      extraPatterns: extraPatterns,
      masks: {..._defaultMasks, ...loaded.masks},
      message: loaded.message,
    );
    unit.accept(guard);
    return guard.violations;
  });
}

/// Flags unmasked PII in sink-call arguments.
///
/// Sinks match by method simple name on any target. Every
/// argument is scanned by [_ArgScanner]; arg labels never visit
/// as identifiers (probed on analyzer 14), so `f(email: x)`
/// stays clean on the label alone.
class _PiiGuard extends RecursiveAstVisitor<void> {
  _PiiGuard(
    this._lineInfo, {
    required this.sinks,
    required this.names,
    required this.extraPatterns,
    required this.masks,
    this.message,
  });

  final LineInfo _lineInfo;
  final Set<String> sinks;
  final Set<String> names;
  final List<RegExp> extraPatterns;
  final Set<String> masks;
  final String? message;
  final List<PiiViolation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (sinks.contains(node.methodName.name)) {
      final line = _lineInfo.getLocation(node.offset).lineNumber;
      for (final argument in node.argumentList.arguments) {
        argument.accept(
          _ArgScanner(
            line,
            names: names,
            extraPatterns: extraPatterns,
            masks: masks,
            message: message,
            violations: violations,
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Scans one sink argument for PII sites, carving out mask-call
/// subtrees (a mask name on any target masks the whole subtree).
class _ArgScanner extends RecursiveAstVisitor<void> {
  _ArgScanner(
    this._line, {
    required this.names,
    required this.extraPatterns,
    required this.masks,
    this.message,
    required this.violations,
  });

  final int _line;
  final Set<String> names;
  final List<RegExp> extraPatterns;
  final Set<String> masks;
  final String? message;
  final List<PiiViolation> violations;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (masks.contains(node.methodName.name)) return;
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _scanRun(node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    for (final element in node.elements) {
      if (element is InterpolationString) _scanRun(element.value);
    }
    super.visitStringInterpolation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) _flag("'${node.name}' (PII name)");
    super.visitSimpleIdentifier(node);
  }

  /// Flags one finding per literal run: the e-mail shape first,
  /// then each configured pattern (kind only — never the span).
  void _scanRun(String? run) {
    if (run == null || run.isEmpty) return;
    if (_emailPattern.hasMatch(run)) {
      _flag('an email-shaped span (PII)');
      return;
    }
    for (final pattern in extraPatterns) {
      if (pattern.hasMatch(run)) {
        _flag('a span matching a configured pattern (PII)');
        return;
      }
    }
  }

  void _flag(String kind) {
    final custom = message;
    violations.add(
      PiiViolation(
        line: _line,
        message: custom == null || custom.isEmpty
            ? 'log call passes $kind; mask it before logging'
            : 'log call passes $kind; mask it before logging: $custom',
      ),
    );
  }
}
