// FG-TOK-020: hardcoded design tokens.
//
// A literal Color(0x...) in a widget bypasses the theme: dark
// mode, branding, and contrast fixes all live in the color
// scheme. Unnamed Color(...) (any argument, fail-closed) and
// the channel ctors fromARGB/fromRGBO flag everywhere outside
// the theme_tokens except files; projects add radius/spacing
// entries under extra_ctors. Unlike FG-BAN-018/FG-LOG-019 the
// rule defaults ON — a Color construction is never valid
// outside a theme file. Parsing only (no type resolution).
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
import 'rule_violation.dart';

/// Channel ctors banned alongside the unnamed Color(...).
const _channelCtors = <String>{'fromARGB', 'fromRGBO'};

/// One extra_ctors entry: a whole type (`EdgeInsets`) or a single
/// named ctor (`BorderRadius.circular`).
class TokExtra {
  const TokExtra(this.type, [this.ctor]);

  /// Simple type name.
  final String type;

  /// Ctor name, or null for the whole type.
  final String? ctor;

  /// Parses `Type` or `Type.ctor` (null when malformed —
  /// wrong arity, empty segments, or a lowercase type).
  static TokExtra? parse(String entry) {
    final parts = entry.split('.');
    if (parts.length == 1 && parts[0].isNotEmpty && _isCapitalized(parts[0])) {
      return TokExtra(parts[0]);
    }
    if (parts.length == 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty &&
        _isCapitalized(parts[0])) {
      return TokExtra(parts[0], parts[1]);
    }
    return null;
  }
}

/// A single FG-TOK-020 violation.
class TokViolation implements RuleViolation {
  const TokViolation({required this.line, required this.message});

  /// 1-based line number of the hardcoded token.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-TOK-020 violation found.
///
/// [config] injects a section (tests); without it the nearest
/// `flutterguard.yaml` is discovered and loaded.
List<TokViolation> analyzeTokFile(String path, {FlatRuleConfig? config}) {
  return runFlatRule(
    path,
    config: config,
    section: 'theme_tokens',
    namesKey: 'extra_ctors',
    defaults: const {},
    defaultOn: true,
    scan: (names, message) => _scanTokFile(path, names, message),
  );
}

/// Parses [path] and collects hardcoded tokens (raw names become
/// [TokExtra] entries; malformed ones drop).
List<TokViolation> _scanTokFile(
  String path,
  Set<String> names,
  String? message,
) {
  final extras = names.map(TokExtra.parse).whereType<TokExtra>().toList();
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ThemeTokenGuard(result.lineInfo, extras, message: message);
  result.unit.accept(guard);
  return guard.violations;
}

/// Flags Color constructions and configured extra ctors.
///
/// Parse-only shapes (no resolution): bare `C(...)` and
/// `C.named(...)` arrive as `MethodInvocation`s; only
/// `const`/`new` force `InstanceCreationExpression` — and there
/// the parser folds `C.named` into the dotted type source
/// (`name` stays null), indistinguishable from a `p.C` import
/// prefix. Both overrides therefore decode (type, ctor) from
/// syntax: a capitalized first segment reads as `Class.ctor`,
/// a lowercase one as a prefix (whole-type only).
///
/// A use is a construction whose type is `Color` with an
/// unnamed/`fromARGB`/`fromRGBO` constructor, or whose
/// type/(type, ctor) matches an extra. Properties
/// (`theme.primary`, `Colors.red`) never match.
class ThemeTokenGuard extends RecursiveAstVisitor<void> {
  ThemeTokenGuard(this._lineInfo, this._extras, {this.message});

  final LineInfo _lineInfo;
  final List<TokExtra> _extras;
  final String? message;
  final List<TokViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final parts = _splitCreation(node.constructorName.type.toSource());
    _check(parts.type, parts.ctor, node.offset);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      if (_isCapitalized(node.methodName.name)) {
        _check(node.methodName.name, null, node.offset);
      }
    } else if (target is SimpleIdentifier) {
      if (_isCapitalized(target.name)) {
        _check(target.name, node.methodName.name, node.offset);
      } else if (_isCapitalized(node.methodName.name)) {
        _check(node.methodName.name, null, node.offset);
      }
    }
    super.visitMethodInvocation(node);
  }

  void _check(String type, String? ctor, int offset) {
    if (!_isBanned(type, ctor)) return;
    final display = ctor == null ? '$type(...)' : '$type.$ctor(...)';
    final custom = message;
    violations.add(
      TokViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message: custom == null || custom.isEmpty
            ? "hardcoded '$display' outside the theme; use a theme token"
            : "hardcoded '$display' outside the theme: $custom",
      ),
    );
  }

  /// True for default Color ctors and configured extras.
  bool _isBanned(String type, String? ctor) {
    if (type == 'Color' && (ctor == null || _channelCtors.contains(ctor))) {
      return true;
    }
    for (final extra in _extras) {
      if (extra.type != type) continue;
      if (extra.ctor == null || extra.ctor == ctor) return true;
    }
    return false;
  }
}

/// True when [name] starts uppercase (leading underscores ignored).
bool _isCapitalized(String name) {
  final stripped = name.replaceAll(RegExp('^_+'), '');
  if (stripped.isEmpty) return false;
  final first = stripped[0];
  return first.toUpperCase() == first;
}

/// Splits a forced-creation type source into (type, ctor):
/// `C` → whole type; `C.named` → the named ctor; `p.C` →
/// whole type (lowercase first segment reads as a prefix).
/// Longer chains take the outer ends (`p.C.named` → `C`,
/// `named`).
({String type, String? ctor}) _splitCreation(String source) {
  final parts = source.split('<').first.trim().split('.');
  if (parts.length == 1) return (type: parts[0], ctor: null);
  if (parts.length == 2) {
    if (_isCapitalized(parts[0])) {
      return (type: parts[0], ctor: parts[1]);
    }
    return (type: parts[1], ctor: null);
  }
  if (_isCapitalized(parts[0])) {
    return (type: parts[0], ctor: parts.last);
  }
  return (type: parts[1], ctor: parts.last);
}
