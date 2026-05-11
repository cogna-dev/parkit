///|
pub(all) struct RootAlt1Fields {
  span : @antlr.SourceSpan
  first_token : @antlr_tcst.TerminalToken?
  last_token : @antlr_tcst.TerminalToken?
  maybe : @antlr_tcst.TerminalToken?
  many : Array[@antlr_tcst.TerminalToken]
  some : @antlr_tcst.NonEmpty[@antlr_tcst.TerminalToken]
}

///|
pub(all) enum RootNode {
  Alt1(RootAlt1Fields)
}
