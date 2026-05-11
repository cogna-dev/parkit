///|
pub type RootNode = ExprNode

///|
pub(all) struct ExprAddFields {
  span : @antlr.SourceSpan
  first_token : @antlr_tcst.TerminalToken?
  last_token : @antlr_tcst.TerminalToken?
  expr_1 : ExprNode
  plus_token : @antlr_tcst.TerminalToken
  expr_2 : ExprNode
}

///|
pub(all) struct ExprAtomFields {
  span : @antlr.SourceSpan
  first_token : @antlr_tcst.TerminalToken?
  last_token : @antlr_tcst.TerminalToken?
  int_token : @antlr_tcst.TerminalToken
}

///|
pub(all) enum ExprNode {
  Add(ExprAddFields)
  Atom(ExprAtomFields)
}
