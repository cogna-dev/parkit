///|
let grammar_source : String = "grammar Hello;\n\nr : 'hello' ID ;\n\nID : [a-z]+ ;\nWS : [ \\r\\t\\n]+ -> skip ;"

///|
let typed_grammar_info : @antlr_tcst.TypedGrammarInfo = {
  grammar_name: "Hello",
  grammar_kind: @antlr.Combined,
  start_rule_name: "r",
  grammar_fingerprint: "grammar=Hello\nkind=combined\nstart_rule_id=0\nrule=0:r:parser:normal:-:-\nrule=1:ID:lexer:normal:-:-\nrule=2:WS:lexer:normal:-:-\nalt=0:1:-\nalt=1:1:-\nalt=2:1:-\nslot=0:1:0:0:string:-:-:plain\nslot=0:1:1:1:token-ref:-:-:plain\nslot=1:1:0:0:charset:-:one-or-more:greedy:plain\nslot=2:1:0:0:charset:-:one-or-more:greedy:plain\ntoken=0:ID:-:explicit\ntoken=1:WS:-:explicit\ntoken=2:T__0:'hello':implicit\nchannel=0:DEFAULT_TOKEN_CHANNEL\nchannel=1:HIDDEN\nmode=0:DEFAULT_MODE",
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
