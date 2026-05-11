///|
/// Stable public reference to one original grammar rule in generic CST output.
pub(all) struct CstRuleRef {
  rule_id : Int
  rule_name : String
  declaring_grammar : String
}

///|
/// Stable public reference to one original grammar alternative.
pub(all) struct CstAlternativeRef {
  rule : CstRuleRef
  alternative_index : Int
  alternative_label : String?
}

///|
/// Public child-slot source categories carried on CST edges.
pub(all) enum CstSlotSourceKind {
  RuleRef(String)
  TokenRef(String)
  Literal(String)
  Range(String)
  CharSet(String)
  Wildcard
  Group
  Action
  Predicate
}

///|
/// Public reference to one original grammar slot.
pub(all) struct CstSlotRef {
  alternative : CstAlternativeRef
  slot_id : Int
  element_index : Int
  label : String?
  source_kind : CstSlotSourceKind
}

///|
/// One child edge from a rule node to a rule/token/error child.
pub(all) struct CstChildEdge {
  child : CstNodeId
  slot : CstSlotRef
  occurrence_index : Int
  recovered : Bool
}

///|
/// One rule node in the public generic CST arena.
pub(all) struct CstRuleNode {
  rule : CstRuleRef
  alternative : CstAlternativeRef?
  span : @antlr.SourceSpan
  children : Array[CstChildEdge]
  recovered : Bool
}

///|
/// One token node in the public generic CST arena.
pub(all) struct CstTokenNode {
  token : CstTokenId
  span : @antlr.SourceSpan
  implicit_literal : Bool
}

///|
/// Public generic CST node variants.
pub(all) enum CstNode {
  Rule(CstRuleNode)
  Token(CstTokenNode)
  Error(CstErrorNode)
}

///|
fn cst_copy_child_edges(values : Array[CstChildEdge]) -> Array[CstChildEdge] {
  let copied : Array[CstChildEdge] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn cst_slot_source_kind_name(kind : CstSlotSourceKind) -> String {
  match kind {
    RuleRef(name) => "rule:" + name
    TokenRef(name) => "token:" + name
    Literal(text) => "literal:" + text
    Range(text) => "range:" + text
    CharSet(text) => "charset:" + text
    Wildcard => "wildcard"
    Group => "group"
    Action => "action"
    Predicate => "predicate"
  }
}
