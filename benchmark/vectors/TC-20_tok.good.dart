// Golden passing vector for FG-TOK-020.
// Colors from the theme plus near-misses.
// The AST gate MUST NOT flag this file.
Object buildTile(Object theme) {
  return Tile(
    color: theme.primary,
    swatch: Colors.red,
    blended: Color.lerp(theme.a, theme.b, 0.5),
    radius: BorderRadius.circular(8),
    padding: EdgeInsets.all(8),
  );
}
