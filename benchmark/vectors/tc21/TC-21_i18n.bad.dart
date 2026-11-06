// Golden failing vector for FG-I18N-021.
// Hardcoded strings in text widgets (see ./flutterguard.yaml).
// The AST gate MUST flag this file.
Object buildLabels(Object name) {
  return Column(
    children: [Text('Hello'), Text('Hi $name'), SelectableText('Copy me')],
  );
}
