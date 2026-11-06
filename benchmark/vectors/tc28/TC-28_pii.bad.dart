// Golden failing vector for FG-PII-028.
// Unmasked PII in log calls (see ./flutterguard.yaml).
// The AST gate MUST flag this file.
void submitOrder(String password, String cpf) {
  print('contact ana@example.com');
  debugPrint('owner ${user.email}');
  print(password);
  print(user.cpf);
  print('doc 123.456.789-00 on file');
  auditLog('login ana@example.com');
}
