// SYS-COV-001 red-suite sample: coverage of a failing suite is
// meaningless, so the runner refuses to score it.
import 'package:test/test.dart';

import 'sample.dart';

void main() {
  test('red', () {
    expect(max2(1, 2), 999);
  });
}
