///|
let grammar_source : String = "grammar CardinalityMix;\n\nroot\n  : maybe=MAYBE? many+=ITEM* some+=REQ+\n  ;\n\nMAYBE : 'm' ;\nITEM : 'i' ;\nREQ : 'r' ;\nWS : [ \\r\\t\\n]+ -> skip ;"

///|
let typed_grammar_info : @antlr_tcst.TypedGrammarInfo = {
  grammar_name: "CardinalityMix",
  grammar_kind: @antlr.Combined,
  start_rule_name: "root",
  grammar_fingerprint: "grammar=CardinalityMix\nkind=combined\nstart_rule_id=0\nrule=0:root:parser:normal:-:-\nrule=1:MAYBE:lexer:normal:-:-\nrule=2:ITEM:lexer:normal:-:-\nrule=3:REQ:lexer:normal:-:-\nrule=4:WS:lexer:normal:-:-\nalt=0:1:-\nalt=1:1:-\nalt=2:1:-\nalt=3:1:-\nalt=4:1:-\nslot=0:1:0:0:token-ref:maybe:single:optional:greedy:plain\nslot=0:1:1:1:token-ref:many:list:zero-or-more:greedy:plain\nslot=0:1:2:2:token-ref:some:list:one-or-more:greedy:plain\nslot=1:1:0:0:string:-:-:plain\nslot=2:1:0:0:string:-:-:plain\nslot=3:1:0:0:string:-:-:plain\nslot=4:1:0:0:charset:-:one-or-more:greedy:plain\ntoken=0:MAYBE:-:explicit\ntoken=1:ITEM:-:explicit\ntoken=2:REQ:-:explicit\ntoken=3:WS:-:explicit\nchannel=0:DEFAULT_TOKEN_CHANNEL\nchannel=1:HIDDEN\nmode=0:DEFAULT_MODE",
  cst_schema_version: 1,
}

///|
/// Return stable grammar metadata for this generated typed CST package.
///
/// Example:
/// let info = grammar_info()
/// inspect(info.start_rule_name.length() > 0, content="true")
///
/// Notes:
/// - The fingerprint must match the input `CstDocument` before strict lowering succeeds.
/// - The schema version is pinned to the generic CST contract this package was generated against.
fn grammar_info() -> @antlr_tcst.TypedGrammarInfo {
  typed_grammar_info
}
