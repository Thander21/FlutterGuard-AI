// Golden passing vector for FG-PII-028.
// Masked or PII-free log calls (see ./flutterguard.yaml).
// The AST gate MUST NOT flag this file.
void submitOrder(String password, String cpf) {
  print(mask(password));
  print('user ${maskDoc(cpf)} done');
  print('***');
  print('hello $name, count $count');
  contact = 'ana@example.com';
  Text('ana@example.com');
}
