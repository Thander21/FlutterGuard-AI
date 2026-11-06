// Golden passing vector for FG-CC-025.
// A small branching function.
// The AST gate MUST NOT flag this file.
int classify(int x) {
  if (x > 0) return 1;
  if (x < 0) return -1;
  return 0;
}
