///|
/// Return the source span captured on this typed `expr` node.
///
/// Example:
/// let span = value.span()
/// ignore(span)
///
/// Notes:
/// - The span is copied from the source generic CST rule node during strict lowering.
/// - Query methods never re-read the source `CstDocument`.
pub fn ExprNode::span(self : ExprNode) -> @antlr.SourceSpan {
  match self {
    Add(fields) => fields.span
    Atom(fields) => fields.span
  }
}

///|
/// Return the first lexical token reachable from this typed node.
///
/// Example:
/// let token = value.first_token()
/// ignore(token)
///
/// Notes:
/// - The token was precomputed during strict lowering.
/// - Empty-token nodes return `None`.
pub fn ExprNode::first_token(self : ExprNode) -> @antlr_tcst.TerminalToken? {
  match self {
    Add(fields) => fields.first_token
    Atom(fields) => fields.first_token
  }
}

///|
/// Return the last lexical token reachable from this typed node.
///
/// Example:
/// let token = value.last_token()
/// ignore(token)
///
/// Notes:
/// - The token was precomputed during strict lowering.
/// - Empty-token nodes return `None`.
pub fn ExprNode::last_token(self : ExprNode) -> @antlr_tcst.TerminalToken? {
  match self {
    Add(fields) => fields.last_token
    Atom(fields) => fields.last_token
  }
}
