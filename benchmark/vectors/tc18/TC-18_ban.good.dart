// Golden passing vector for FG-BAN-018.
// Allowed API plus near-misses (see ./flutterguard.yaml).
// The AST gate MUST NOT flag this file.
import 'package:notify/notify.dart' show SnackBar;

class SnackBar {
  const SnackBar();
}

void submitOrder() {
  NotificationService.showSuccess('Saved');
  logger.trace('scoped');
  final handler = trace;
  final label = 'SnackBar';
}
