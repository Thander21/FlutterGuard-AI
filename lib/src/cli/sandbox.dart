// Volatile agent playground over `fixtures/sandbox/`
// (SYS-CLI-001b; moved from `bin/` by SYS-REL-001 R3).
import 'dart:io';

import '../util.dart';
import 'check.dart';

/// CLI usage for `sandbox` (SYS-CLI-001b).
const _sandboxUsage = '''
Usage: dart run bin/flutterguard.dart sandbox <load|reset|check>
  load: copy golden .bad vectors into fixtures/sandbox/ (volatile).
  reset: wipe fixtures/sandbox/.
  check: run check over fixtures/sandbox/.''';

/// Manages the volatile agent playground (SYS-CLI-001b). Returns 0 on
/// success, 1 when the vectors source is missing, 2 on bad arguments.
/// `check` follows check() exit codes (1 = violations present, the
/// expected state right after load).
Future<int> sandbox(List<String> args, {String root = '.'}) async {
  if (args.length != 1 ||
      !const {'load', 'reset', 'check'}.contains(args.first)) {
    stderr.writeln(_sandboxUsage);
    return 2;
  }
  final box = Directory(joinRoot(root, 'fixtures/sandbox'));
  switch (args.first) {
    case 'reset':
      if (box.existsSync()) box.deleteSync(recursive: true);
      box.createSync(recursive: true);
      stdout.writeln('reset: ${box.path}');
      return 0;
    case 'load':
      final vectors = Directory(joinRoot(root, 'benchmark/vectors'));
      if (!vectors.existsSync()) {
        stderr.writeln('error: no benchmark/vectors under $root');
        return 1;
      }
      if (box.existsSync()) box.deleteSync(recursive: true);
      box.createSync(recursive: true);
      var count = 0;
      for (final entity in vectors.listSync()) {
        if (entity is File && entity.path.endsWith('.bad.dart')) {
          final name = entity.uri.pathSegments.last;
          entity.copySync(joinRoot(box.path, name));
          count++;
        }
      }
      stdout.writeln('loaded: $count vectors into ${box.path}');
      return 0;
    case 'check':
      return check([box.path]);
  }
  return 2; // Unreachable: args.first is one of load/reset/check.
}
