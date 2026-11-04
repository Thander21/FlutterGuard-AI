// SYS-DRY-001: structural duplication detector.
//
// Normalized-token bag-Jaccard over >15-line declarations. Sync, pure
// reads: identifiers collapse to ID, string/number literals to LIT,
// everything else stays verbatim, so renames never hide a clone.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../cli/check.dart';

/// Similarity at or above which a pair is reported (advisory in v1).
const duplicationThreshold = 0.8;

/// Compared spans must strictly exceed this many lines.
const duplicationMinLines = 15;

/// One comparable declaration: a >15-line span with its normalized
/// token multiset.
class DuplicationUnit {
  const DuplicationUnit({
    required this.name,
    required this.line,
    required this.endLine,
    required this.bag,
  });

  /// `Class.method`, `Class`, or a bare function name.
  final String name;

  /// 1-based first line.
  final int line;

  /// 1-based last line (inclusive).
  final int endLine;

  /// Normalized token multiset (identifiers -> ID, literals -> LIT).
  final Map<String, int> bag;
}

/// One reported clone pair, `A < B` by (file, line).
class ClonePair {
  const ClonePair({
    required this.nameA,
    required this.fileA,
    required this.lineA,
    required this.endLineA,
    required this.nameB,
    required this.fileB,
    required this.lineB,
    required this.endLineB,
    required this.similarity,
  });

  final String nameA;
  final String fileA;
  final int lineA;
  final int endLineA;
  final String nameB;
  final String fileB;
  final int lineB;
  final int endLineB;

  /// Bag-Jaccard similarity (0.8..1.0).
  final double similarity;

  @override
  String toString() =>
      '$nameA ($fileA:$lineA-$endLineA) ~= $nameB ($fileB:$lineB-$endLineB) '
      '@ ${similarity.toStringAsFixed(3)}';
}

/// Outcome of [findDuplication]: advisory clone pairs.
class DuplicationVerdict {
  const DuplicationVerdict({
    required this.passed,
    required this.pairs,
    required this.unitsCompared,
    required this.filesScanned,
    required this.errors,
  });

  /// Advisory v1: always true; the blocking flip is owned by
  /// SYS-CAL-001.
  final bool passed;

  /// Reported pairs in canonical order.
  final List<ClonePair> pairs;
  final int unitsCompared;
  final int filesScanned;

  /// Per-file failures (unreadable input); never fatal.
  final List<CheckError> errors;
}

/// Collects comparable units (>15-line declarations) from [source],
/// in source order.
List<DuplicationUnit> collectUnits(String source, {String? path}) {
  final result = parseString(
    content: source,
    path: path ?? 'duplication.dart',
    throwIfDiagnostics: false,
  );
  final collector = _UnitCollector(result.lineInfo);
  result.unit.accept(collector);
  return [for (final u in collector.units) u.unit];
}

/// Ruzicka (bag) Jaccard: sum(min)/sum(max) over the union.
/// Both empty -> 1.0; one empty -> 0.0.
double bagJaccard(Map<String, int> a, Map<String, int> b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  if (a.isEmpty || b.isEmpty) return 0.0;
  var minSum = 0;
  var maxSum = 0;
  for (final key in {...a.keys, ...b.keys}) {
    final x = a[key] ?? 0;
    final y = b[key] ?? 0;
    minSum += x < y ? x : y;
    maxSum += x > y ? x : y;
  }
  return minSum / maxSum;
}

/// Finds structural clones in [target] (one `.dart` file or a
/// directory scanned recursively, sorted).
///
/// Throws [ArgumentError] when [target] is missing.
DuplicationVerdict findDuplication(String target) {
  final type = FileSystemEntity.typeSync(target);
  if (type == FileSystemEntityType.notFound) {
    throw ArgumentError('No such file or directory: $target');
  }
  final files = <String>[];
  if (type == FileSystemEntityType.directory) {
    for (final entity in Directory(target).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(_normalize(entity.path));
      }
    }
  } else if (target.endsWith('.dart')) {
    files.add(_normalize(target));
  }
  files.sort();

  final units = <_Unit>[];
  final errors = <CheckError>[];
  for (final file in files) {
    String source;
    try {
      source = File(file).readAsStringSync();
    } catch (error) {
      errors.add(CheckError(file: file, error: '$error'));
      continue;
    }
    final result = parseString(
        content: source, path: file, throwIfDiagnostics: false);
    final collector = _UnitCollector(result.lineInfo);
    result.unit.accept(collector);
    for (final unit in collector.units) {
      units.add(_Unit(unit: unit.unit, file: file, isClassLike: unit.isClassLike));
    }
  }
  units.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.unit.line.compareTo(b.unit.line);
  });

  // Exact-hash shortcut: identical normalized bags short-circuit to
  // 1.0 (grouped by a canonical string key, no Jaccard math).
  final groupOf = <int, String>{};
  for (var i = 0; i < units.length; i++) {
    final entries = units[i].unit.bag.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    groupOf[i] = entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  final candidates = <({int i, int j, double similarity})>[];
  for (var i = 0; i < units.length; i++) {
    for (var j = i + 1; j < units.length; j++) {
      final a = units[i];
      final b = units[j];
      if (a.file == b.file && _overlaps(a.unit, b.unit)) continue;
      double similarity;
      if (groupOf[i] == groupOf[j]) {
        similarity = 1.0;
      } else {
        // Sound size prefilter: Ruzicka <= min/max token counts, so a
        // pair below the ratio can never reach the threshold.
        final sizeA = _sizeOf(a.unit.bag);
        final sizeB = _sizeOf(b.unit.bag);
        final minSize = sizeA < sizeB ? sizeA : sizeB;
        final maxSize = sizeA > sizeB ? sizeA : sizeB;
        if (minSize / maxSize < duplicationThreshold) continue;
        similarity = bagJaccard(a.unit.bag, b.unit.bag);
        if (similarity < duplicationThreshold) continue;
      }
      candidates.add((i: i, j: j, similarity: similarity));
    }
  }

  // Member suppression: a reported class-like pair subsumes any
  // pair touching a member across those two classes (the class
  // finding says it all; the class pair itself is always kept).
  final matchedClasses = <(String, String)>{};
  for (final c in candidates) {
    if (units[c.i].isClassLike && units[c.j].isClassLike) {
      final ka = _keyOf(units, c.i);
      final kb = _keyOf(units, c.j);
      matchedClasses.add(ka.compareTo(kb) < 0 ? (ka, kb) : (kb, ka));
    }
  }
  final pairs = <ClonePair>[];
  for (final c in candidates) {
    final a = units[c.i];
    final b = units[c.j];
    if (!a.isClassLike || !b.isClassLike) {
      final oa = a.isClassLike ? _keyOf(units, c.i) : _owner(units, c.i);
      final ob = b.isClassLike ? _keyOf(units, c.j) : _owner(units, c.j);
      if (oa != null && ob != null && oa != ob) {
        final pair = oa.compareTo(ob) < 0 ? (oa, ob) : (ob, oa);
        if (matchedClasses.contains(pair)) continue;
      }
    }
    pairs.add(ClonePair(
      nameA: a.unit.name,
      fileA: a.file,
      lineA: a.unit.line,
      endLineA: a.unit.endLine,
      nameB: b.unit.name,
      fileB: b.file,
      lineB: b.unit.line,
      endLineB: b.unit.endLine,
      similarity: c.similarity,
    ));
  }
  return DuplicationVerdict(
    passed: true,
    pairs: pairs,
    unitsCompared: units.length,
    filesScanned: files.length,
    errors: errors,
  );
}

/// True when two same-file spans overlap (nesting, not cloning).
bool _overlaps(DuplicationUnit a, DuplicationUnit b) =>
    a.line <= b.endLine && b.line <= a.endLine;

int _sizeOf(Map<String, int> bag) =>
    bag.values.fold(0, (sum, count) => sum + count);

String _keyOf(List<_Unit> units, int index) {
  final u = units[index];
  return '${u.file}:${u.unit.line}:${u.unit.endLine}';
}

/// Key of the smallest class-like unit in the same file strictly
/// containing [index], or null when there is none.
String? _owner(List<_Unit> units, int index) {
  final inner = units[index];
  String? owner;
  var ownerSpan = 1 << 30;
  for (var i = 0; i < units.length; i++) {
    if (i == index || !units[i].isClassLike) continue;
    final outer = units[i];
    if (outer.file != inner.file) continue;
    if (outer.unit.line <= inner.unit.line &&
        inner.unit.endLine <= outer.unit.endLine) {
      final span = outer.unit.endLine - outer.unit.line;
      if (span < ownerSpan) {
        ownerSpan = span;
        owner = _keyOf(units, i);
      }
    }
  }
  return owner;
}

/// Forward slashes on every platform, so findings sort and compare the same
/// on Windows, macOS, and Linux.
String _normalize(String path) => path.replaceAll(r'\', '/');

/// A collected unit with the file and class-likeness the verdict needs.
class _Unit {
  const _Unit(
      {required this.unit, required this.file, required this.isClassLike});

  final DuplicationUnit unit;
  final String file;
  final bool isClassLike;
}

/// Collected unit under construction (class-likeness attached).
class _Collected {
  const _Collected({required this.unit, required this.isClassLike});

  final DuplicationUnit unit;
  final bool isClassLike;
}

class _UnitCollector extends RecursiveAstVisitor<void> {
  _UnitCollector(this._lineInfo);

  final LineInfo _lineInfo;
  final List<_Collected> units = [];
  final List<String> _classStack = [];

  void _add(String name, AstNode node, {required bool isClassLike}) {
    final line = _lineInfo.getLocation(node.offset).lineNumber;
    final endLine = _lineInfo.getLocation(node.end).lineNumber;
    if (endLine - line + 1 <= duplicationMinLines) return;
    units.add(_Collected(
        unit: DuplicationUnit(
            name: name, line: line, endLine: endLine, bag: _bagOf(node)),
        isClassLike: isClassLike));
  }

  void _classLike(String name, AstNode node, void Function() visit) {
    _add([..._classStack, name].join('.'), node, isClassLike: true);
    _classStack.add(name);
    visit();
    _classStack.removeLast();
  }

  String _member(String name) =>
      _classStack.isEmpty ? name : '${_classStack.last}.$name';

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _classLike(node.name.lexeme, node, () => super.visitClassDeclaration(node));

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _classLike(node.name.lexeme, node, () => super.visitMixinDeclaration(node));

  @override
  void visitEnumDeclaration(EnumDeclaration node) =>
      _classLike(node.name.lexeme, node, () => super.visitEnumDeclaration(node));

  // No extension-type override: the AST node is experimental in the
  // pinned analyzer, and suppression comments violate FG-LINT-009.
  // Methods inside extension types are still collected; the
  // extension type itself is skipped as a unit.

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    final name = node.name?.lexeme;
    if (name != null) _classStack.add(name);
    super.visitExtensionDeclaration(node);
    if (name != null) _classStack.removeLast();
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Top-level functions only; local functions fold into the
    // enclosing unit's span (their tokens are walked with it).
    if (node.parent is CompilationUnit) {
      _add(node.name.lexeme, node, isClassLike: false);
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _add(_member(node.name.lexeme), node, isClassLike: false);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final name = node.name?.lexeme;
    final cls = _classStack.isEmpty ? '' : _classStack.last;
    _add(name == null ? cls : '$cls.$name', node, isClassLike: false);
    super.visitConstructorDeclaration(node);
  }
}

/// Normalized token multiset over the node span: identifiers -> ID,
/// string/number literals -> LIT, everything else verbatim. Comments
/// never enter the token chain.
Map<String, int> _bagOf(AstNode node) {
  final bag = <String, int>{};
  var token = node.beginToken;
  final end = node.endToken;
  while (true) {
    final type = token.type;
    final key = type == TokenType.IDENTIFIER
        ? 'ID'
        : type == TokenType.STRING ||
                type == TokenType.INT ||
                type == TokenType.DOUBLE
            ? 'LIT'
            : token.lexeme;
    bag[key] = (bag[key] ?? 0) + 1;
    if (token == end) break;
    token = token.next!;
  }
  return bag;
}
