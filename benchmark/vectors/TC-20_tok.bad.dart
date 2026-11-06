// Golden failing vector for FG-TOK-020.
// Hardcoded colors outside the theme.
// The AST gate MUST flag this file.
Object buildTile() {
  return Tile(
    color: Color(0xFF0000),
    shadow: const Color.fromARGB(255, 0, 0, 0),
    overlay: Color.fromRGBO(0, 0, 0, 0.5),
  );
}
