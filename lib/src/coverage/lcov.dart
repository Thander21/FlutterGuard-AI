// SYS-COV-001: minimal lcov parser (SF/DA records only).
//
// Pure, synchronous. Reads `SF`/`DA`/`end_of_record`; `LF`/`LH`/
// `FN*`/`BR*`/`TN` lines are ignored. Malformed input throws
// [FormatException] — loud, never skipped.
class LcovFile {
  const LcovFile({required this.path, required this.lineHits});

  /// SF value as emitted (matching/normalization is the runner's job).
  final String path;

  /// Executable line -> hit count (duplicate DA lines are summed).
  final Map<int, int> lineHits;
}

/// Parses lcov [content] into files keyed by raw SF value.
Map<String, LcovFile> parseLcov(String content) {
  final files = <String, LcovFile>{};
  String? current;
  Map<int, int>? hits;

  void close() {
    if (current != null) {
      files[current!] = LcovFile(path: current!, lineHits: hits!);
      current = null;
      hits = null;
    }
  }

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.startsWith('SF:')) {
      close();
      current = line.substring(3);
      if (current!.isEmpty) throw FormatException('empty SF: $line');
      hits = <int, int>{};
    } else if (line.startsWith('DA:')) {
      if (current == null) throw FormatException('DA outside record: $line');
      final parts = line.substring(3).split(',');
      if (parts.length < 2) throw FormatException('malformed DA: $line');
      final number = int.tryParse(parts[0]);
      final count = int.tryParse(parts[1]);
      if (number == null || count == null || number <= 0 || count < 0) {
        throw FormatException('malformed DA: $line');
      }
      hits![number] = (hits![number] ?? 0) + count;
    } else if (line == 'end_of_record') {
      close();
    }
  }
  close();
  return files;
}
