///|
fn first_diagnostic_message(
  diagnostics : Array[@antlr.Diagnostic],
  fallback : String,
) -> String {
  if diagnostics.length() == 0 {
    fallback
  } else {
    diagnostics[0].message
  }
}

///|
fn runtime_atn() -> Result[@antlr.GrammarAtn, String] {
  let report = @antlr.run_frontend_pipeline(grammar_source)
  if report.has_errors() {
    return Err(
      first_diagnostic_message(
        report.all_diagnostics(),
        "failed to load generated grammar",
      ),
    )
  }
  match report.grammar_atn {
    Some(atn) => Ok(atn)
    None => Err("failed to load generated grammar")
  }
}

///|
fn first_parser_message(result : @antlr_runtime.ParserRunResult) -> String {
  if result.diagnostics.length() != 0 {
    return result.diagnostics[0].message
  }
  if result.recovery_events.length() != 0 {
    return result.recovery_events[0].message
  }
  "input does not match grammar"
}

///|
fn lowering_message() -> String {
  "failed to build typed parse result"
}

///|
/// Parse one input string with this generated package.
///
/// Example:
/// let root = parse("hello abc")
/// inspect(root is Ok(_), content="true")
///
/// Notes:
/// - The function runs the full parse flow for the generated grammar.
/// - Errors are returned as plain text for direct application or CLI use.
pub fn parse(input : String) -> Result[RootNode, String] {
  let atn = match runtime_atn() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let lexer_result = @antlr_runtime.lex_with_atn(
    atn,
    input,
    @antlr_runtime.LexerHostHooks::empty(),
  )
  if lexer_result.diagnostics.length() != 0 {
    return Err(lexer_result.diagnostics[0].message)
  }
  let parsed = @antlr_runtime.parse_with_atn(
    atn,
    lexer_result.tokens,
    @antlr_runtime.ParserHostHooks::empty(),
  )
  if parsed.diagnostics.length() != 0 || parsed.recovery_events.length() != 0 {
    return Err(first_parser_message(parsed))
  }
  let document = match @antlr_cst.build_cst_document(atn, parsed) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match lower_root(document) {
    Ok(root) => Ok(root)
    Err(_) => Err(lowering_message())
  }
}
