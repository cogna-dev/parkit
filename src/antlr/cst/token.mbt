///|
/// One full token-table record preserved on the public generic CST document.
pub(all) struct CstTokenRecord {
  id : CstTokenId
  token_kind_id : Int
  symbolic_name : String?
  literal_name : String?
  channel : Int
  channel_name : String
  mode : String?
  lexeme : String
  span : @antlr.SourceSpan
  synthetic : Bool
  implicit_literal : Bool
  eof : Bool
}

///|
fn cst_token_is_visible(record : CstTokenRecord) -> Bool {
  record.eof || record.channel_name == "DEFAULT_TOKEN_CHANNEL"
}
