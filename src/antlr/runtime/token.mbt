///|
/// One emitted lexer token record from the Phase 2 runtime.
pub struct LexerToken {
  token_index : Int
  token_id : Int
  token_name : String
  text : String
  channel_id : Int
  channel_name : String
  start_mode_id : Int
  start_mode_name : String
  end_mode_id : Int
  end_mode_name : String
  span : @antlr.SourceSpan
  implicit : Bool
  is_eof : Bool
}

///|
/// One recorded action invocation observed while lexing.
pub struct LexerActionInvocation {
  action_text : String
  label : String
  rule_name : String
  span : @antlr.SourceSpan
}

///|
/// Aggregate lexer-runtime result for one input.
pub struct LexerRunResult {
  tokens : Array[LexerToken]
  diagnostics : Array[@antlr.Diagnostic]
  action_log : Array[LexerActionInvocation]
  dfa : LexerDfa
}

///|
fn lexer_snapshot_escape(text : String) -> String {
  let mut escaped = ""
  let mut index = 0
  while index < text.length() {
    let c = text.get_char(index).unwrap()
    if c == '\\' {
      escaped = escaped + "\\\\"
    } else if c == '\n' {
      escaped = escaped + "\\n"
    } else if c == '\r' {
      escaped = escaped + "\\r"
    } else if c == '\t' {
      escaped = escaped + "\\t"
    } else {
      escaped = escaped + text[index:index + 1].to_string()
    }
    index = index + 1
  }
  escaped
}

///|
fn encode_runtime_span(span : @antlr.SourceSpan) -> String {
  span.start.offset.to_string() +
  "," +
  span.start.line.to_string() +
  "," +
  span.start.column.to_string() +
  "," +
  span.end.offset.to_string() +
  "," +
  span.end.line.to_string() +
  "," +
  span.end.column.to_string()
}

///|
fn join_runtime_lines(lines : Array[String]) -> String {
  if lines.length() == 0 {
    return ""
  }
  let mut result = lines[0]
  for index = 1; index < lines.length(); index = index + 1 {
    result = result + "\n" + lines[index]
  }
  result
}

///|
/// Serialize one lexer run into a stable line-oriented snapshot format.
///
/// Example:
/// let text = serialize_lexer_run({ tokens: [], diagnostics: [], action_log: [], dfa: empty_lexer_dfa() })
/// inspect(text.has_prefix("LEXER"), content="true")
///
/// Notes:
/// - The format is intended for regression snapshots and diagnostic diffs.
/// - DFA internals remain available on `LexerRunResult.dfa` and are not serialized here.
pub fn serialize_lexer_run(result : LexerRunResult) -> String {
  let lines : Array[String] = []
  lines.push("LEXER\t1")
  for token in result.tokens {
    lines.push(
      "token\t" +
      token.token_index.to_string() +
      "\t" +
      lexer_snapshot_escape(token.token_name) +
      "\t" +
      lexer_snapshot_escape(token.channel_name) +
      "\t" +
      lexer_snapshot_escape(token.start_mode_name) +
      "\t" +
      lexer_snapshot_escape(token.end_mode_name) +
      "\t" +
      (if token.implicit { "1" } else { "0" }) +
      "\t" +
      (if token.is_eof { "1" } else { "0" }) +
      "\t" +
      encode_runtime_span(token.span) +
      "\t" +
      lexer_snapshot_escape(token.text),
    )
  }
  for diagnostic in result.diagnostics {
    lines.push(
      "diagnostic\t" +
      lexer_snapshot_escape(
        @antlr.diagnostic_severity_name(diagnostic.severity),
      ) +
      "\t" +
      encode_runtime_span(diagnostic.span) +
      "\t" +
      lexer_snapshot_escape(diagnostic.message),
    )
  }
  for invocation in result.action_log {
    lines.push(
      "action\t" +
      lexer_snapshot_escape(invocation.label) +
      "\t" +
      lexer_snapshot_escape(invocation.rule_name) +
      "\t" +
      encode_runtime_span(invocation.span) +
      "\t" +
      lexer_snapshot_escape(invocation.action_text),
    )
  }
  join_runtime_lines(lines)
}
