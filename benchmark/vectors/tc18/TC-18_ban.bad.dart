// Golden failing vector for FG-BAN-018.
// Uses of project-banned symbols (see ./flutterguard.yaml).
// The AST gate MUST flag this file.
void submitOrder() {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved')));
  const SnackBar(content: Text('Again'));
  ui.SnackBar(content: Text('Prefixed'));
  trace('submitted');
}
