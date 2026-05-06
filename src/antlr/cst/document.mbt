///|
/// Version wrapper for the public generic CST schema.
pub(all) struct CstSchemaVersion(Int)

///|
/// Arena identifier for one generic CST node.
pub(all) struct CstNodeId(Int)

///|
/// Arena identifier for one token-table record.
pub(all) struct CstTokenId(Int)

///|
/// Stable fingerprint for the grammar surface a CST document was built from.
pub(all) struct CstGrammarFingerprint(String)

///|
/// Public grammar metadata stored on the generic CST root object.
pub(all) struct CstGrammarInfo {
  grammar_name : String
  grammar_kind : @antlr.GrammarKind
  start_rule : CstRuleRef
  fingerprint : CstGrammarFingerprint
}

///|
/// Public generic CST root object.
pub(all) struct CstDocument {
  schema_version : CstSchemaVersion
  grammar : CstGrammarInfo
  root : CstNodeId
  nodes : Array[CstNode]
  tokens : Array[CstTokenRecord]
  recovery_events : Array[CstRecoveryEvent]
}

///|
let cst_schema_version_v1 : CstSchemaVersion = CstSchemaVersion(1)

///|
fn cst_grammar_kind_name(kind : @antlr.GrammarKind) -> String {
  match kind {
    @antlr.Combined => "combined"
    @antlr.Lexer => "lexer"
    @antlr.Parser => "parser"
  }
}

///|
fn cst_snapshot_escape(text : String) -> String {
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
fn cst_encode_option_text(value : String?) -> String {
  match value {
    Some(text) => cst_snapshot_escape(text)
    None => "-"
  }
}

///|
fn cst_encode_option_node_id(value : CstNodeId?) -> String {
  match value {
    Some(node_id) => node_id.0.to_string()
    None => "-"
  }
}

///|
fn cst_encode_option_token_id(value : CstTokenId?) -> String {
  match value {
    Some(token_id) => token_id.0.to_string()
    None => "-"
  }
}

///|
fn cst_encode_span(span : @antlr.SourceSpan) -> String {
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
fn cst_join_lines(lines : Array[String]) -> String {
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
/// Serialize one generic CST document into a stable line-oriented snapshot format.
///
/// Example:
/// let text = serialize_cst_document({ schema_version: CstSchemaVersion(1), grammar: { grammar_name: "G", grammar_kind: @antlr.Combined, start_rule: { rule_id: 0, rule_name: "r", declaring_grammar: "G" }, fingerprint: CstGrammarFingerprint("f") }, root: CstNodeId(0), nodes: [], tokens: [], recovery_events: [] })
/// inspect(text.has_prefix("CST"), content="true")
///
/// Notes:
/// - The format is intended for CST regression snapshots and query-baseline diffs.
/// - The serialized output preserves full token-table and recovery-event ordering.
pub fn serialize_cst_document(document : CstDocument) -> String {
  let lines : Array[String] = []
  lines.push("CST\t1")
  lines.push(
    "grammar\t" +
    cst_snapshot_escape(document.grammar.grammar_name) +
    "\t" +
    cst_grammar_kind_name(document.grammar.grammar_kind) +
    "\t" +
    cst_snapshot_escape(document.grammar.start_rule.rule_name) +
    "\t" +
    cst_snapshot_escape(document.grammar.start_rule.declaring_grammar) +
    "\t" +
    cst_snapshot_escape(document.grammar.fingerprint.0),
  )
  lines.push("root\t" + document.root.0.to_string())
  for token in document.tokens {
    lines.push(
      "token\t" +
      token.id.0.to_string() +
      "\t" +
      token.token_kind_id.to_string() +
      "\t" +
      cst_encode_option_text(token.symbolic_name) +
      "\t" +
      cst_encode_option_text(token.literal_name) +
      "\t" +
      token.channel.to_string() +
      "\t" +
      cst_snapshot_escape(token.channel_name) +
      "\t" +
      cst_encode_option_text(token.mode) +
      "\t" +
      (if token.synthetic { "1" } else { "0" }) +
      "\t" +
      (if token.implicit_literal { "1" } else { "0" }) +
      "\t" +
      (if token.eof { "1" } else { "0" }) +
      "\t" +
      cst_encode_span(token.span) +
      "\t" +
      cst_snapshot_escape(token.lexeme),
    )
  }
  for index = 0; index < document.nodes.length(); index = index + 1 {
    match document.nodes[index] {
      Rule(rule_node) => {
        let alternative_index_text = match rule_node.alternative {
          Some(alternative) => alternative.alternative_index.to_string()
          None => "-"
        }
        let alternative_label_text = match rule_node.alternative {
          Some(alternative) =>
            cst_encode_option_text(alternative.alternative_label)
          None => "-"
        }
        lines.push(
          "node\trule\t" +
          index.to_string() +
          "\t" +
          cst_snapshot_escape(rule_node.rule.rule_name) +
          "\t" +
          cst_snapshot_escape(rule_node.rule.declaring_grammar) +
          "\t" +
          alternative_index_text +
          "\t" +
          alternative_label_text +
          "\t" +
          (if rule_node.recovered { "1" } else { "0" }) +
          "\t" +
          cst_encode_span(rule_node.span),
        )
        for edge in rule_node.children {
          lines.push(
            "edge\t" +
            index.to_string() +
            "\t" +
            edge.child.0.to_string() +
            "\t" +
            cst_snapshot_escape(edge.slot.alternative.rule.rule_name) +
            "\t" +
            edge.slot.alternative.alternative_index.to_string() +
            "\t" +
            edge.slot.slot_id.to_string() +
            "\t" +
            edge.slot.element_index.to_string() +
            "\t" +
            cst_encode_option_text(edge.slot.label) +
            "\t" +
            cst_snapshot_escape(
              cst_slot_source_kind_name(edge.slot.source_kind),
            ) +
            "\t" +
            edge.occurrence_index.to_string() +
            "\t" +
            (if edge.recovered { "1" } else { "0" }),
          )
        }
      }
      Token(token_node) =>
        lines.push(
          "node\ttoken\t" +
          index.to_string() +
          "\t" +
          token_node.token.0.to_string() +
          "\t" +
          (if token_node.implicit_literal { "1" } else { "0" }) +
          "\t" +
          cst_encode_span(token_node.span),
        )
      Error(error_node) =>
        lines.push(
          "node\terror\t" +
          index.to_string() +
          "\t" +
          cst_error_kind_name(error_node.kind) +
          "\t" +
          cst_encode_span(error_node.span) +
          "\t" +
          cst_encode_option_text(error_node.message) +
          "\t" +
          cst_snapshot_escape(error_node.expected.join(",")),
        )
    }
  }
  for event in document.recovery_events {
    lines.push(
      "recovery\t" +
      cst_error_kind_name(event.kind) +
      "\t" +
      cst_snapshot_escape(event.detail_kind) +
      "\t" +
      cst_encode_option_node_id(event.node) +
      "\t" +
      cst_encode_option_token_id(event.token) +
      "\t" +
      event.visible_offset.to_string() +
      "\t" +
      cst_encode_span(event.span) +
      "\t" +
      cst_encode_option_text(event.message),
    )
  }
  cst_join_lines(lines)
}
