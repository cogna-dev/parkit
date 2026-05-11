///|
/// Aggregate parser-runtime result for one token stream.
pub struct ParserRunResult {
  success : Bool
  start_rule_id : Int
  start_rule_name : String
  tokens : Array[LexerToken]
  events : Array[ParserEvent]
  recovery_events : Array[ParserRecoveryEvent]
  diagnostics : Array[@antlr.Diagnostic]
  dfa : ParserDfa
  consumed_visible_tokens : Int
  full_context_fallbacks : Int
  ambiguities : Int
}

///|
fn parser_event_kind_name(kind : ParserEventKind) -> String {
  match kind {
    EnterRule => "enter-rule"
    ExitRule => "exit-rule"
    CommitAlternative => "commit-alt"
    ConsumeToken => "consume-token"
    Action => "action"
    Recovery => "recovery"
  }
}

///|
fn parser_recovery_kind_name(kind : ParserRecoveryKind) -> String {
  match kind {
    UnexpectedToken => "unexpected-token"
    DeletedToken => "deleted-token"
    InsertedToken => "inserted-token"
    RecoveryFence => "recovery-fence"
  }
}

///|
fn parser_snapshot_escape(text : String) -> String {
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
fn parser_encode_option_int(value : Int?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "-"
  }
}

///|
fn parser_encode_option_text(value : String?) -> String {
  match value {
    Some(text) => parser_snapshot_escape(text)
    None => "-"
  }
}

///|
fn encode_parser_span(span : @antlr.SourceSpan) -> String {
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
fn join_parser_lines(lines : Array[String]) -> String {
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
fn parser_join_ints(values : Array[Int]) -> String {
  if values.length() == 0 {
    return ""
  }
  let mut text = values[0].to_string()
  for index = 1; index < values.length(); index = index + 1 {
    text = text + "," + values[index].to_string()
  }
  text
}

///|
/// Serialize one parser run into a stable line-oriented snapshot format.
///
/// Example:
/// let text = serialize_parser_run({ success: true, start_rule_id: 0, start_rule_name: "r", tokens: [], events: [], recovery_events: [], diagnostics: [], dfa: empty_parser_dfa(), consumed_visible_tokens: 0, full_context_fallbacks: 0, ambiguities: 0 })
/// inspect(text.has_prefix("PARSER"), content="true")
///
/// Notes:
/// - The format is intended for parser regression snapshots and trace diffs.
/// - DFA internals remain available on `ParserRunResult.dfa` and are only summarized here.
pub fn serialize_parser_run(result : ParserRunResult) -> String {
  let lines : Array[String] = []
  lines.push("PARSER\t1")
  lines.push(
    "summary\t" +
    parser_snapshot_escape(result.start_rule_name) +
    "\t" +
    (if result.success { "1" } else { "0" }) +
    "\t" +
    result.consumed_visible_tokens.to_string() +
    "\t" +
    result.full_context_fallbacks.to_string() +
    "\t" +
    result.ambiguities.to_string() +
    "\t" +
    result.recovery_events.length().to_string() +
    "\t" +
    result.diagnostics.length().to_string() +
    "\t" +
    result.dfa.entries.length().to_string(),
  )
  for event in result.events {
    lines.push(
      "event\t" +
      parser_event_kind_name(event.kind) +
      "\t" +
      event.depth.to_string() +
      "\t" +
      event.visible_offset.to_string() +
      "\t" +
      parser_encode_option_text(event.rule_name) +
      "\t" +
      parser_encode_option_int(event.alternative_index) +
      "\t" +
      parser_encode_option_text(event.label) +
      "\t" +
      parser_encode_option_int(event.slot_id) +
      "\t" +
      parser_encode_option_int(event.element_index) +
      "\t" +
      parser_encode_option_int(event.token_index) +
      "\t" +
      parser_encode_option_text(event.token_name) +
      "\t" +
      (if event.recovered { "1" } else { "0" }) +
      "\t" +
      encode_parser_span(event.span) +
      "\t" +
      parser_encode_option_text(event.text) +
      "\t" +
      parser_encode_option_text(event.message),
    )
  }
  for recovery in result.recovery_events {
    lines.push(
      "recovery\t" +
      parser_recovery_kind_name(recovery.kind) +
      "\t" +
      parser_encode_option_int(recovery.token_index) +
      "\t" +
      parser_encode_option_text(recovery.token_name) +
      "\t" +
      recovery.visible_offset.to_string() +
      "\t" +
      encode_parser_span(recovery.span) +
      "\t" +
      parser_snapshot_escape(recovery.message),
    )
  }
  for diagnostic in result.diagnostics {
    lines.push(
      "diagnostic\t" +
      parser_snapshot_escape(
        @antlr.diagnostic_severity_name(diagnostic.severity),
      ) +
      "\t" +
      encode_parser_span(diagnostic.span) +
      "\t" +
      parser_snapshot_escape(diagnostic.message),
    )
  }
  for entry in result.dfa.entries {
    let ambiguous = if entry.ambiguous_alternatives.length() == 0 {
      "-"
    } else {
      parser_join_ints(entry.ambiguous_alternatives)
    }
    lines.push(
      "dfa\t" +
      entry.decision_id.to_string() +
      "\t" +
      entry.input_offset.to_string() +
      "\t" +
      parser_snapshot_escape(entry.lookahead_token_name) +
      "\t" +
      parser_encode_option_int(entry.chosen_alternative) +
      "\t" +
      ambiguous +
      "\t" +
      (if entry.used_full_context { "1" } else { "0" }) +
      "\t" +
      parser_snapshot_escape(entry.config_signature),
    )
  }
  join_parser_lines(lines)
}
