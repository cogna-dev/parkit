///|
/// Stable parser event categories emitted by the Phase 3 interpreter.
pub(all) enum ParserEventKind {
  EnterRule
  ExitRule
  CommitAlternative
  ConsumeToken
  Action
  Recovery
}

///|
/// Stable recovery categories emitted by the Phase 3 interpreter.
pub(all) enum ParserRecoveryKind {
  UnexpectedToken
  DeletedToken
  InsertedToken
  RecoveryFence
}

///|
/// One parser trace event recorded during interpretation.
pub struct ParserEvent {
  kind : ParserEventKind
  rule_id : Int?
  rule_name : String?
  alternative_index : Int?
  label : String?
  slot_id : Int?
  element_index : Int?
  token_index : Int?
  token_name : String?
  text : String?
  message : String?
  visible_offset : Int
  depth : Int
  recovered : Bool
  span : @antlr.SourceSpan
}

///|
/// One parser recovery record intended for Phase 4 CST error integration.
pub struct ParserRecoveryEvent {
  kind : ParserRecoveryKind
  token_index : Int?
  token_name : String?
  message : String
  visible_offset : Int
  span : @antlr.SourceSpan
}
