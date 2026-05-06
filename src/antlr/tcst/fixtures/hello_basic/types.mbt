///|
pub type RootNode = RNode

///|
pub(all) struct RAlt1Fields {
  span : @antlr.SourceSpan
  first_token : @antlr_tcst.TerminalToken?
  last_token : @antlr_tcst.TerminalToken?
  hello_token : @antlr_tcst.TerminalToken
  id_token : @antlr_tcst.TerminalToken
}

///|
pub(all) enum RNode {
  Alt1(RAlt1Fields)
}
