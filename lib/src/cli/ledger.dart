// Per-run evidence ledger for `check --evidence`
// (SYS-CAL-003 R2-5 engine item).
//
// Builds canon-shaped gate lines (SYS-TELE-001, zero new keys:
// `CHECK_GATE` phase, `CHECK_RECORDED` action, `WARNED` verdict)
// and appends them to an explicit path. Takes anonymous records
// instead of `check.dart` types so no import cycle forms; the
// `check()` edge maps verdicts and findings (one comprehension
// each) and writes before rendering.
import 'dart:convert';
import 'dart:io';

/// Builds one JSONL line per gate in [gates] order: the canon 9
/// keys with the audited [target], the mapped verdict, and the
/// first reported [findings] message per rule (or `""`). Timings
/// and counts stay on the `--by-gate` surface — the ledger
/// records verdicts. [timestamp] injects the stamp (tests);
/// without it the current UTC time is used.
List<String> buildLedgerLines({
  required String target,
  required List<({String ruleId, String status})> gates,
  required List<({String ruleId, String message})> findings,
  String? timestamp,
}) {
  final first = <String, String>{};
  for (final finding in findings) {
    first.putIfAbsent(finding.ruleId, () => finding.message);
  }
  final stamp = timestamp ?? DateTime.now().toUtc().toIso8601String();
  return [
    for (final gate in gates)
      jsonEncode({
        'timestamp': stamp,
        'phase': 'CHECK_GATE',
        'rule_id': gate.ruleId,
        'file': target,
        'status': _ledgerStatus(gate.status),
        'error_message': first[gate.ruleId] ?? '',
        'recipe_injected': '',
        'iteration': 1,
        'action': 'CHECK_RECORDED',
      }),
  ];
}

/// Maps `--by-gate` verdicts onto canon statuses.
String _ledgerStatus(String verdict) => switch (verdict) {
  'FAIL' => 'FAILED',
  'WARN' => 'WARNED',
  _ => 'PASSED',
};

/// Appends [lines] to [path] (JSONL, trailing newline), creating
/// parent directories (the `writeBaseline` precedent). Empty
/// input writes nothing (no blank JSONL lines). Throws
/// [ArgumentError] naming the cause when the ledger cannot be
/// written.
void appendLedger(String path, List<String> lines) {
  if (lines.isEmpty) return;
  try {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${lines.join('\n')}\n', mode: FileMode.append);
  } on FileSystemException catch (error) {
    throw ArgumentError('cannot write evidence ledger: ${error.message}');
  }
}
