// Golden failing vector for FG-LOG-019.
// Print calls outside the project logger (see ./flutterguard.yaml).
// The AST gate MUST flag this file.
void submitOrder() {
  print('submitting');
  debugPrint('debug');
  tattle('extra');
}
