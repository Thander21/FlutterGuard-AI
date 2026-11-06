// FG-I18N-021: hardcoded strings in text widgets.
//
// A Text('Hello') ships untranslatable: every locale added later
// must hunt string literals scattered through widget trees. Text
// constructions (plus configured widgets) with literal text are
// banned everywhere outside the i18n except files. The rule
// self-loads its section from the nearest flutterguard.yaml;
// without the section it is silent. Parsing only (no type
// resolution).
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
import 'rule_violation.dart';

/// Widgets checked by default once the section exists.
const _defaultWidgets = <String>{'Text'};

/// A single FG-I18N-021 violation.
class I18nViolation implements RuleViolation {
  const I18nViolation({required this.line, required this.message});

  /// 1-based line number of the hardcoded string.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-I18N-021 violation found.
///
/// [config] injects a section (tests); without it the nearest
/// `flutterguard.yaml` is discovered and loaded.
List<I18nViolation> analyzeI18nFile(String path, {FlatRuleConfig? config}) {
  return runFlatRule(
    path,
    config: config,
    section: 'i18n',
    namesKey: 'widgets',
    defaults: _defaultWidgets,
    defaultOn: false,
    scan: (widgets, message) => _scanI18nFile(path, widgets, message),
  );
}

/// Parses [path] and collects text widgets with literal text.
List<I18nViolation> _scanI18nFile(
  String path,
  Set<String> widgets,
  String? message,
) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = I18nGuard(result.lineInfo, widgets, message: message);
  result.unit.accept(guard);
  return guard.violations;
}

/// Flags text-widget constructions with literal text.
///
/// A use is a bare, const, or prefixed construction of a tracked
/// widget whose first positional argument carries non-blank
/// literal text (prefix-agnostic: user-visible text needs
/// translation wherever it is built).
class I18nGuard extends RecursiveAstVisitor<void> {
  I18nGuard(this._lineInfo, this._widgets, {this.message});

  final LineInfo _lineInfo;
  final Set<String> _widgets;
  final String? message;
  final List<I18nViolation> violations = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkConstruction(
      _simpleName(node.constructorName.type.toSource()),
      node.argumentList,
      node.offset,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      if (_isCapitalized(node.methodName.name)) {
        _checkConstruction(
          node.methodName.name,
          node.argumentList,
          node.offset,
        );
      }
    } else if (target is SimpleIdentifier &&
        _isCapitalized(node.methodName.name)) {
      _checkConstruction(
        _isCapitalized(target.name) ? target.name : node.methodName.name,
        node.argumentList,
        node.offset,
      );
    }
    super.visitMethodInvocation(node);
  }

  void _checkConstruction(String type, ArgumentList args, int offset) {
    if (!_widgets.contains(type)) return;
    if (args.arguments.isEmpty) return;
    final first = args.arguments.first;
    if (first is NamedArgument) return;
    if (first is! Expression) return;
    final text = _literalText(first);
    if (text == null || text.trim().isEmpty) return;
    final custom = message;
    violations.add(
      I18nViolation(
        line: _lineInfo.getLocation(offset).lineNumber,
        message: custom == null || custom.isEmpty
            ? "hardcoded string in $type(...); move it to the l10n catalog"
            : "hardcoded string in $type(...): $custom",
      ),
    );
  }
}

/// Literal text of [node]: a simple value, interpolation chunks,
/// or an adjacent combination — null for non-literals.
String? _literalText(Expression node) {
  if (node is SimpleStringLiteral) return node.value;
  if (node is StringInterpolation) {
    final buffer = StringBuffer();
    for (final element in node.elements) {
      if (element is InterpolationString) buffer.write(element.value);
    }
    return buffer.toString();
  }
  if (node is AdjacentStrings) {
    final buffer = StringBuffer();
    for (final part in node.strings) {
      final text = _literalText(part);
      if (text != null) buffer.write(text);
    }
    return buffer.toString();
  }
  return null;
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
