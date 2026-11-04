// FG-IMP-015: forbid illegal imports and exports.
//
// Two triggers, both parse-only decidable: `dart:mirrors` (banned
// on Flutter) in any import/export URI, and relative URIs escaping
// the nearest ancestor `lib/` directory (breaks package
// encapsulation). Main and conditional (`if`) URIs are judged
// alike. Files outside any `lib/` are never judged for escape (no
// package context); `part` directives are out of scope.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'rule_violation.dart';

/// Import/export URI banned on Flutter (reflection is unavailable).
const importBannedUri = 'dart:mirrors';

/// A single FG-IMP-015 violation.
class ImportViolation implements RuleViolation {
  const ImportViolation({required this.line, required this.message});

  /// 1-based line number of the offending directive.
  @override
  final int line;

  @override
  final String message;

  @override
  String toString() => 'line $line: $message';
}

/// Analyzes [path] and returns every FG-IMP-015 violation found.
List<ImportViolation> analyzeImportFile(String path) {
  final source = File(path).readAsStringSync();
  final result = parseString(content: source, path: path);
  final guard = ImportGuard(result.lineInfo, path);
  result.unit.accept(guard);
  return guard.violations..sort((a, b) => a.line.compareTo(b.line));
}

/// Flags banned URIs and lib-escape relative directives.
class ImportGuard extends RecursiveAstVisitor<void> {
  ImportGuard(this._lineInfo, String path)
      : _fileDir = _dirSegments(path),
        _libDir = _nearestLibDir(path);

  final LineInfo _lineInfo;

  /// Normalized directory segments of the analyzed file.
  final List<String> _fileDir;

  /// Segments of the nearest ancestor `lib/` directory, or null
  /// when the file sits outside any `lib/` (escape unjudgeable).
  final List<String>? _libDir;
  final List<ImportViolation> violations = [];

  @override
  void visitImportDirective(ImportDirective node) {
    _checkDirective(node, 'import');
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    _checkDirective(node, 'export');
    super.visitExportDirective(node);
  }

  void _checkDirective(NamespaceDirective node, String kind) {
    _checkUri(node.uri.stringValue, node, kind);
    for (final config in node.configurations) {
      _checkUri(config.uri.stringValue, config, kind);
    }
  }

  void _checkUri(String? uri, AstNode site, String kind) {
    if (uri == null) return;
    if (uri == importBannedUri) {
      _flag(site,
          "$kind of 'dart:mirrors' is banned on Flutter; use explicit serialization or code generation");
      return;
    }
    final libDir = _libDir;
    if (libDir == null || !_isRelative(uri)) return;
    if (_escapesLib(libDir, _fileDir, uri)) {
      _flag(site, "relative $kind '$uri' escapes the package lib/ directory");
    }
  }

  void _flag(AstNode node, String message) {
    violations.add(ImportViolation(
      line: _lineInfo.getLocation(node.offset).lineNumber,
      message: message,
    ));
  }
}

/// Directory segments of [path] (forward slashes, file dropped).
List<String> _dirSegments(String path) {
  final segments = path.replaceAll(r'\', '/').split('/')..removeLast();
  return segments;
}

/// Segments of the nearest ancestor `lib/` directory of [path]
/// (exact lowercase segment), or null when there is none.
List<String>? _nearestLibDir(String path) {
  final segments = _dirSegments(path);
  final index = segments.lastIndexOf('lib');
  if (index < 0) return null;
  return segments.sublist(0, index + 1);
}

/// True for file-relative URIs (no scheme): `./x`, `../x`, `x`.
bool _isRelative(String uri) => !uri.contains(':') && !uri.startsWith('/');

/// True when [uri] resolved against [fileDir] leaves [libDir].
bool _escapesLib(List<String> libDir, List<String> fileDir, String uri) {
  final resolved = [...fileDir];
  for (final segment in uri.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else {
      resolved.add(segment);
    }
  }
  if (resolved.length < libDir.length) return true;
  for (var i = 0; i < libDir.length; i++) {
    if (resolved[i] != libDir[i]) return true;
  }
  return false;
}
