// FG-BAN-018: banned project symbols.
//
// Projects ban framework calls they centralized behind a service
// (a bare SnackBar outside the notification service, rogue
// tracing outside telemetry). The rule self-loads the
// `banned_symbols` section of the nearest `flutterguard.yaml`
// (shared walk-up discovery) and flags every creation, call, or
// type reference naming a banned symbol outside the entry's
// `except` files. Without a section it is silent. Parsing only
// (no type resolution).
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
import 'rule_violation.dart';

/// One banned symbol: the name, an optional project message, and
/// `except` globs (matched against the analyzed file, relative to
/// the config directory).
class BannedEntry {
  const BannedEntry({
    required this.symbol,
    this.message,
    this.except = const [],
  });

  /// Simple symbol name, matched case-sensitively.
  final String symbol;

  /// Project guidance surfaced in the violation (the allowed API).
  final String? message;

  /// Glob list silencing this entry (`*`, `?`, full-segment `**`).
  final List<String> except;
}

/// Parses one `banned_symbols` entry, or null when malformed (skipped).
BannedEntry? _parseEntry(dynamic item) {
  if (item is! Map) return null;
  final symbol = item['symbol'];
  if (symbol is! String || symbol.isEmpty) return null;
  final rawExcept = item['except'];
  var except = const <String>[];
  if (rawExcept != null) {
    final parsed = stringListField(item, 'except');
    if (parsed == null) return null;
    except = parsed;
  }
  final message = item['message'];
  return BannedEntry(
    symbol: symbol,
    message: message is String ? message : null,
    except: except,
  );
}

/// A single FG-BAN-018 violation.
class BannedSymbolViolation implements RuleViolation {
  const BannedSymbolViolation({required this.line, required this.message});

  /// 1-based line number of the banned use.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-BAN-018 violation found.
///
/// [config] injects a section (tests); without it the nearest
/// `flutterguard.yaml` is discovered and loaded. Entries whose
/// `except` globs match the file are dropped before the scan.
List<BannedSymbolViolation> analyzeBannedSymbolFile(
  String path, {
  RuleListConfig<BannedEntry>? config,
}) {
  final loaded =
      config ?? RuleListConfig.load(path, 'banned_symbols', _parseEntry);
  if (loaded.items.isEmpty) return const [];
  final fileKey = exceptKey(path, loaded.baseDir);
  final active = loaded.items
      .where((entry) => !isExcepted(entry.except, fileKey))
      .toList();
  if (active.isEmpty) return const [];
  return scanTarget(path, (unit, info) {
    final guard = BannedSymbolGuard(info, active);
    unit.accept(guard);
    return guard.violations;
  });
}

/// Flags creations, calls, and type references naming a banned symbol.
///
/// A use is an `InstanceCreationExpression`, a bare call
/// (`target == null`), a constructor-shaped call (`S(...)`,
/// `S.named(...)`, `p.S(...)`), or a `NamedType` — matched on the
/// simple name, prefix-agnostic, case-sensitive. Declarations bind
/// names rather than using them; show/hide combinators and
/// tear-offs are `SimpleIdentifier`s, never invocations — none of
/// those flag, structurally. Constructor-type positions are
/// skipped (the creation itself already flags).
class BannedSymbolGuard extends RecursiveAstVisitor<void> {
  BannedSymbolGuard(this._lineInfo, List<BannedEntry> entries)
    : _messages = {for (final entry in entries) entry.symbol: entry.message};

  final LineInfo _lineInfo;
  final Map<String, String?> _messages;
  final List<BannedSymbolViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkName(_simpleName(node.constructorName.type.toSource()), node.offset);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      _checkName(node.methodName.name, node.offset);
    } else if (target is SimpleIdentifier) {
      if (_isCapitalized(target.name)) {
        _checkName(target.name, node.offset);
      } else if (_isCapitalized(node.methodName.name)) {
        _checkName(node.methodName.name, node.offset);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (node.parent is! ConstructorName) {
      _checkName(_simpleName(node.toSource()), node.offset);
    }
    super.visitNamedType(node);
  }

  void _checkName(String name, int offset) {
    if (!_messages.containsKey(name)) return;
    final custom = _messages[name];
    violations.add(
      BannedSymbolViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message: custom == null || custom.isEmpty
            ? "uses banned symbol '$name'"
            : "uses banned symbol '$name': $custom",
      ),
    );
  }
}

/// True when [name] starts uppercase (leading underscores ignored).
bool _isCapitalized(String name) {
  final stripped = name.replaceAll(RegExp('^_+'), '');
  if (stripped.isEmpty) return false;
  final first = stripped[0];
  return first.toUpperCase() == first;
}

/// Simple type name (prefixes and type arguments stripped).
String _simpleName(String source) {
  final base = source.split('<').first.trim();
  final dot = base.lastIndexOf('.');
  return dot == -1 ? base : base.substring(dot + 1);
}
