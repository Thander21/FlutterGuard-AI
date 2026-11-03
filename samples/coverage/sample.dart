// SYS-COV-001 coverage sample: one fully covered method (CC 2), one
// uncovered method (CC 2), one uncovered complex method (CC 5).
int max2(int a, int b) => a > b ? a : b;

int negateIfPositive(int x) {
  if (x > 0) return -x;
  return x;
}

int complex(int x) {
  if (x > 0) x = -x;
  if (x < -10) x = 0;
  for (var i = 0; i < x; i++) {
    x += i;
  }
  while (x < 0) {
    x++;
  }
  return x;
}
