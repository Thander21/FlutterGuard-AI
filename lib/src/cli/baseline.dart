// R2-2 adoption scope: finding baseline (load/write/ratchet) plus
// diff file-set resolution. The git and baseline reads run at the
// `check()` edge so `checkPath` stays stdio-free (SYS-CLI-001a §3).
import 'dart:convert';
import 'dart:io';

import 'check.dart';

/// A finding baseline: project-relative file path (see
/// [baselineRoot]) → rule id → finding count. Legacy baselines keyed
/// by absolute-normalized paths still load and match. Counts cover
/// errors and warnings alike.
class FindingBaseline {
  const FindingBaseline(this.counts);

  final Map<String, Map<String, int>> counts;
}

/// Reads the baseline at [path]. Throws [ArgumentError] naming the
/// cause when the file is missing, unreadable, or malformed.
FindingBaseline loadBaseline(String path) {
  String raw;
  try {
    raw = File(path).readAsStringSync();
  } on FileSystemException catch (error) {
    throw ArgumentError('Cannot read baseline "$path": ${error.message}');
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw ArgumentError('Malformed baseline "$path": ${error.message}');
  }
  if (decoded is! Map) {
    throw ArgumentError(
      'Malformed baseline "$path": top level must be an object',
    );
  }
  final counts = <String, Map<String, int>>{};
  for (final entry in decoded.entries) {
    final file = entry.key;
    final rules = entry.value;
    if (file is! String || rules is! Map) {
      throw ArgumentError(
        'Malformed baseline "$path": entries must map file → {rule → count}',
      );
    }
    final fileCounts = <String, int>{};
    for (final ruleEntry in rules.entries) {
      final rule = ruleEntry.key;
      final count = ruleEntry.value;
      if (rule is! String || count is! int || count < 0) {
        throw ArgumentError(
          'Malformed baseline "$path": counts must be non-negative integers',
        );
      }
      fileCounts[rule] = count;
    }
    counts[file] = fileCounts;
  }
  return FindingBaseline(counts);
}

/// Rewrites the baseline at [path] from [findings] (counts per
/// [root]-relative file and rule id), pruning stale entries.
/// Files and rules serialize sorted, so repeated writes are
/// byte-stable. Throws [ArgumentError] when [path] cannot be written.
void writeBaseline(
  String path,
  List<CheckFinding> findings, {
  required String root,
}) {
  final counts = baselineCounts(findings, root: root);
  final sorted = {
    for (final file in counts.keys.toList()..sort())
      file: {
        for (final rule in counts[file]!.keys.toList()..sort())
          rule: counts[file]![rule],
      },
  };
  try {
    File(path).writeAsStringSync('${jsonEncode(sorted)}\n');
  } on FileSystemException catch (error) {
    throw ArgumentError('Cannot write baseline "$path": ${error.message}');
  }
}

/// Counts [findings] per [root]-relative file (see [baselineKey])
/// and rule id.
Map<String, Map<String, int>> baselineCounts(
  List<CheckFinding> findings, {
  required String root,
}) {
  final rootKey = _resolved(root);
  final counts = <String, Map<String, int>>{};
  for (final finding in findings) {
    final perFile = counts.putIfAbsent(
      _relativeKey(rootKey, _resolved(finding.file)),
      () => <String, int>{},
    );
    perFile[finding.ruleId] = (perFile[finding.ruleId] ?? 0) + 1;
  }
  return counts;
}

/// Reports only the findings ABOVE the stored per-(file, rule)
/// count, in input order; files or rules absent from [baseline]
/// report every finding (fail-closed for new code). A finding
/// matches its [root]-relative key first, then its legacy
/// absolute-normalized key (pre-relative baselines keep working
/// at their original location).
List<CheckFinding> applyBaseline(
  List<CheckFinding> findings,
  FindingBaseline baseline, {
  required String root,
}) {
  final rootKey = _resolved(root);
  final remaining = <String, Map<String, int>>{
    for (final entry in baseline.counts.entries) entry.key: Map.of(entry.value),
  };
  final reported = <CheckFinding>[];
  for (final finding in findings) {
    final absolute = _resolved(finding.file);
    final key = [
      _relativeKey(rootKey, absolute),
      absoluteNormalized(finding.file),
    ].where((k) => (remaining[k]?[finding.ruleId] ?? 0) > 0).firstOrNull;
    if (key == null) {
      reported.add(finding);
    } else {
      remaining[key]![finding.ruleId] = remaining[key]![finding.ruleId]! - 1;
    }
  }
  return reported;
}

/// The directory baseline keys are relative to, for a `check`
/// [target]: the nearest ancestor of the target (the target itself
/// when it is a directory) holding a `pubspec.yaml`, else the target
/// directory (a file target's parent). Absolute-normalized.
String baselineRoot(String target) {
  final start = _resolved(_scopeDir(target));
  for (Directory? dir = Directory(start); dir != null; dir = _parentOf(dir)) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
  }
  return start;
}

/// [dir]'s parent, or null at the filesystem root.
Directory? _parentOf(Directory dir) {
  final parent = dir.parent;
  return parent.path == dir.path ? null : parent;
}

/// The baseline key of absolute-normalized [file] under
/// absolute-normalized [root]: the `/`-separated relative path, or
/// [file] itself when it lies outside [root]. Drive letters compare
/// case-insensitively on Windows.
String _relativeKey(String root, String file) {
  final prefix = root.endsWith('/') ? root : '$root/';
  final inside = Platform.isWindows
      ? file.toLowerCase().startsWith(prefix.toLowerCase())
      : file.startsWith(prefix);
  return inside ? file.substring(prefix.length) : file;
}

/// [absoluteNormalized] with `.`/`..` segments collapsed, so
/// differently spelled targets yield the same keys.
String _resolved(String path) {
  final segments = <String>[];
  for (final segment in absoluteNormalized(path).split('/')) {
    if (segment == '.') continue;
    if (segment == '..' && segments.length > 1) {
      segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  final joined = segments.join('/');
  return joined.length > 1 && joined.endsWith('/')
      ? joined.substring(0, joined.length - 1)
      : joined;
}

/// Absolute-normalized files changed in the worktree versus the
/// merge-base with [base], plus untracked files (honoring
/// `.gitignore`). Only `.dart` paths are returned. Throws
/// [ArgumentError] naming the cause outside a git worktree, on an
/// unresolvable base, or on git failure.
Set<String> resolveChangedFiles(String target, String base) {
  final dir = _scopeDir(target);
  final top = _git(dir, [
    'rev-parse',
    '--show-toplevel',
  ], 'not a git repo').trim();
  final mergeBase = _git(dir, [
    'merge-base',
    'HEAD',
    base,
  ], 'unresolvable base "$base"').trim();
  final changed = _git(dir, [
    'diff',
    '--name-only',
    '-z',
    mergeBase,
  ], 'diff failed');
  final untracked = _git(dir, [
    'ls-files',
    '--others',
    '--exclude-standard',
    '-z',
  ], 'untracked scan failed');
  final files = <String>{};
  for (final entry in [...changed.split('\x00'), ...untracked.split('\x00')]) {
    if (entry.isEmpty || !entry.endsWith('.dart')) continue;
    files.add(absoluteNormalized('$top/$entry'));
  }
  return files;
}

/// Absolute form of [path] with forward slashes, for stable
/// baseline keys and diff membership on every platform.
String absoluteNormalized(String path) {
  return File(path).absolute.path.replaceAll(r'\', '/');
}

/// Directory git runs in for [target]: itself for directories,
/// its parent for files.
String _scopeDir(String target) {
  if (FileSystemEntity.isDirectorySync(target)) {
    return File(target).absolute.path;
  }
  return File(target).absolute.parent.path;
}

/// Runs `git` with [args] in [dir], returning stdout. Throws
/// [ArgumentError] on any failure, naming [cause].
String _git(String dir, List<String> args, String cause) {
  ProcessResult result;
  try {
    result = Process.runSync('git', args, workingDirectory: dir);
  } on ProcessException catch (error) {
    throw ArgumentError(
      'git ${args.join(' ')} failed ($cause): ${error.message}',
    );
  }
  if (result.exitCode != 0) {
    throw ArgumentError(
      'git ${args.join(' ')} failed ($cause): ${result.stderr}',
    );
  }
  return result.stdout as String;
}
