// FG-LOG-019: print calls must route through the logger.
//
// A stray print in shipped code has no level, no sink, and no
// sampling — and debugPrint turns lossy exactly when traffic
// peaks. Bare print/debugPrint calls (plus configured extra
// symbols) are banned everywhere outside the print_logger
// except files. The rule self-loads its section from the nearest
// flutterguard.yaml; without the section it is silent. Parsing
// only (no type resolution).
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../rule_params.dart';
import 'rule_violation.dart';

/// Bare calls banned by default once the section exists.
const _defaultSymbols = <String>{'print', 'debugPrint'};

/// A single FG-LOG-019 violation.
class LogViolation implements RuleViolation {
  const LogViolation({required this.line, required this.message});

  /// 1-based line number of the banned call.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-LOG-019 violation found.
///
/// [config] injects a section (tests); without it the nearest
/// `flutterguard.yaml` is discovered and loaded.
List<LogViolation> analyzeLogFile(String path, {FlatRuleConfig? config}) {
  return runFlatRule(
    path,
    config: config,
    section: 'print_logger',
    namesKey: 'symbols',
    defaults: _defaultSymbols,
    defaultOn: false,
    scan: (banned, message) => _scanLogFile(path, banned, message),
  );
}

/// Parses [path] and collects banned bare calls.
List<LogViolation> _scanLogFile(
  String path,
  Set<String> banned,
  String? message,
) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = PrintLoggerGuard(result.lineInfo, banned, message: message);
  result.unit.accept(guard);
  return guard.violations;
}

/// Flags bare print-like calls (target-less invocations only).
///
/// Dotted calls (`logger.info`, `stderr.writeln`), tear-offs,
/// and bare references never flag — v1 matches invocations of
/// the bare name.
class PrintLoggerGuard extends RecursiveAstVisitor<void> {
  PrintLoggerGuard(this._lineInfo, this._banned, {this.message});

  final LineInfo _lineInfo;
  final Set<String> _banned;
  final String? message;
  final List<LogViolation> violations = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && _banned.contains(node.methodName.name)) {
      final custom = message;
      violations.add(
        LogViolation(
          line: _lineInfo.getLocation(node.offset).lineNumber,
          message: custom == null || custom.isEmpty
              ? "bare '${node.methodName.name}' call outside the project logger; "
                    'route it through the logger'
              : "bare '${node.methodName.name}' call outside the project logger: "
                    '$custom',
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}
