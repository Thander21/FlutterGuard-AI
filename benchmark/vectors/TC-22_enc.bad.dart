// Golden failing vector for FG-ENC-022.
// Mojibake from a Latin-1 misread: cafÃ© naÃ§Ã£o.
// The AST gate MUST flag this file.
Object label() {
  return 'cafÃ©';
}
