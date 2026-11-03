// SYS-COV-001 coverage sample test: exercises only `max2`.
import 'package:test/test.dart';

import 'sample.dart';

void main() {
  test('max2', () {
    expect(max2(2, 1), 2);
    expect(max2(1, 2), 2);
  });
}
