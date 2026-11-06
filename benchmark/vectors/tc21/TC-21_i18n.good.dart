// Golden passing vector for FG-I18N-021.
// Localized text plus near-misses (see ./flutterguard.yaml).
// The AST gate MUST NOT flag this file.
Object buildLabels(Object t, Object name) {
  return Column(
    children: [
      Text(t.greeting),
      Text(''),
      Text('  '),
      Text('$name'),
      Label('not a text widget'),
    ],
  );
}
