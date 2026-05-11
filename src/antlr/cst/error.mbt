///|
/// Public CST error-node categories.
pub(all) enum CstErrorKind {
  InsertedToken
  UnexpectedToken
  MissingSubtree
  RecoveryFence
}

///|
/// One error node preserved in the public generic CST arena.
pub(all) struct CstErrorNode {
  kind : CstErrorKind
  span : @antlr.SourceSpan
  message : String?
  expected : Array[String]
}

///|
/// One structured recovery artifact preserved on the generic CST document.
pub(all) struct CstRecoveryEvent {
  kind : CstErrorKind
  detail_kind : String
  span : @antlr.SourceSpan
  node : CstNodeId?
  token : CstTokenId?
  visible_offset : Int
  message : String?
}

///|
fn cst_error_kind_name(kind : CstErrorKind) -> String {
  match kind {
    InsertedToken => "inserted-token"
    UnexpectedToken => "unexpected-token"
    MissingSubtree => "missing-subtree"
    RecoveryFence => "recovery-fence"
  }
}
