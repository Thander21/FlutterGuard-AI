// Golden passing vector for FG-LOG-019.
// Logging through the project logger (see ./flutterguard.yaml).
// The AST gate MUST NOT flag this file.
void submitOrder(Object logger) {
  logger.info('submitting');
  AppLogger.info('submitted');
  final printer = print;
  final label = 'print';
}
