///|
/// Return the source span captured on this typed `root` node.
///
/// Example:
/// let span = value.span()
/// ignore(span)
///
/// Notes:
/// - The span is copied from the source generic CST rule node during strict lowering.
/// - Query methods never re-read the source `CstDocument`.
pub fn RootNode::span(self : RootNode) -> @antlr.SourceSpan {
  match self {
    Alt1(fields) => fields.span
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
pub fn RootNode::first_token(self : RootNode) -> @antlr_tcst.TerminalToken? {
  match self {
    Alt1(fields) => fields.first_token
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
pub fn RootNode::last_token(self : RootNode) -> @antlr_tcst.TerminalToken? {
  match self {
    Alt1(fields) => fields.last_token
  }
}
