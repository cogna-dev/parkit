///|
let atn_serialization_version = 1

///|
fn join_atn_lines(lines : Array[String]) -> String {
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
fn join_atn_fields(fields : Array[String]) -> String {
  if fields.length() == 0 {
    return ""
  }
  let mut result = fields[0]
  for index = 1; index < fields.length(); index = index + 1 {
    result = result + "\t" + fields[index]
  }
  result
}

///|
fn join_with_separator(values : Array[String], separator : String) -> String {
  if values.length() == 0 {
    return ""
  }
  let mut result = values[0]
  for index = 1; index < values.length(); index = index + 1 {
    result = result + separator + values[index]
  }
  result
}

///|
fn split_atn_fields(line : String) -> Array[String] {
  line.split("\t").map(field => field.to_string()).to_array()
}

///|
fn hex_digit(value : Int) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('A'.to_int() + value - 10).unsafe_to_char()
  }
}

///|
fn decode_hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn escape_atn_field(text : String) -> String {
  let mut result = ""
  for c in text {
    if c == '%' || c == '\t' || c == '\n' || c == '|' || c == ',' || c == ':' {
      let code = c.to_int()
      result = result +
        "%" +
        String::make(1, hex_digit(code / 16)) +
        String::make(1, hex_digit(code % 16))
    } else {
      result = result + String::make(1, c)
    }
  }
  result
}

///|
fn unescape_atn_field(text : String) -> Result[String, String] {
  let mut result = ""
  let mut index = 0
  while index < text.length() {
    let c = text.get_char(index).unwrap()
    if c != '%' {
      result = result + String::make(1, c)
      index = index + 1
      continue
    }
    if index + 2 >= text.length() {
      return Err("unterminated percent escape")
    }
    let hi = text.get_char(index + 1).unwrap()
    let lo = text.get_char(index + 2).unwrap()
    let hi_value = match decode_hex_digit(hi) {
      Some(value) => value
      None => return Err("invalid hex escape")
    }
    let lo_value = match decode_hex_digit(lo) {
      Some(value) => value
      None => return Err("invalid hex escape")
    }
    result = result +
      String::make(1, (hi_value * 16 + lo_value).unsafe_to_char())
    index = index + 3
  }
  Ok(result)
}

///|
fn parse_decimal_int(text : String) -> Int? {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return None
  }
  let mut sign = 1
  let mut index = 0
  if trimmed.has_prefix("-") {
    sign = -1
    index = 1
    if trimmed.length() == 1 {
      return None
    }
  }
  let mut value = 0
  while index < trimmed.length() {
    let c = trimmed.get_char(index).unwrap()
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + c.to_int() - '0'.to_int()
    index = index + 1
  }
  Some(sign * value)
}

///|
fn encode_bool_field(value : Bool) -> String {
  if value {
    "1"
  } else {
    "0"
  }
}

///|
fn decode_bool_field(raw : String) -> Result[Bool, String] {
  if raw == "1" {
    Ok(true)
  } else if raw == "0" {
    Ok(false)
  } else {
    Err("invalid bool field")
  }
}

///|
fn encode_string_field(value : String) -> String {
  escape_atn_field(value)
}

///|
fn decode_string_field(raw : String) -> Result[String, String] {
  unescape_atn_field(raw)
}

///|
fn encode_option_string_field(value : String?) -> String {
  match value {
    Some(inner) => "1:" + escape_atn_field(inner)
    None => "0:"
  }
}

///|
fn decode_option_string_field(raw : String) -> Result[String?, String] {
  if raw.has_prefix("0:") {
    Ok(None)
  } else if raw.has_prefix("1:") {
    match unescape_atn_field(raw[2:raw.length()].to_string()) {
      Ok(value) => Ok(Some(value))
      Err(error) => Err(error)
    }
  } else {
    Err("invalid option-string field")
  }
}

///|
fn encode_option_int_field(value : Int?) -> String {
  match value {
    Some(inner) => "1:" + inner.to_string()
    None => "0:"
  }
}

///|
fn decode_option_int_field(raw : String) -> Result[Int?, String] {
  if raw.has_prefix("0:") {
    Ok(None)
  } else if raw.has_prefix("1:") {
    match parse_decimal_int(raw[2:raw.length()].to_string()) {
      Some(value) => Ok(Some(value))
      None => Err("invalid option-int field")
    }
  } else {
    Err("invalid option-int field")
  }
}

///|
fn encode_string_array_field(values : Array[String]) -> String {
  let encoded : Array[String] = []
  for value in values {
    encoded.push(escape_atn_field(value))
  }
  join_with_separator(encoded, "|")
}

///|
fn decode_string_array_field(raw : String) -> Result[Array[String], String] {
  if raw == "" {
    return Ok([])
  }
  let values : Array[String] = []
  for item in raw.split("|") {
    match unescape_atn_field(item.to_string()) {
      Ok(value) => values.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(values)
}

///|
fn encode_int_array_field(values : Array[Int]) -> String {
  let encoded : Array[String] = []
  for value in values {
    encoded.push(value.to_string())
  }
  join_with_separator(encoded, ",")
}

///|
fn decode_int_array_field(raw : String) -> Result[Array[Int], String] {
  if raw == "" {
    return Ok([])
  }
  let values : Array[Int] = []
  for item in raw.split(",") {
    match parse_decimal_int(item.to_string()) {
      Some(value) => values.push(value)
      None => return Err("invalid int array field")
    }
  }
  Ok(values)
}

///|
fn encode_span_field(span : SourceSpan) -> String {
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
fn decode_span_field(raw : String) -> Result[SourceSpan, String] {
  let values = match decode_int_array_field(raw) {
    Ok(parsed) => parsed
    Err(error) => return Err(error)
  }
  if values.length() != 6 {
    return Err("invalid span field")
  }
  Ok(
    SourceSpan::new(
      SourcePos::new(values[0], values[1], values[2]),
      SourcePos::new(values[3], values[4], values[5]),
    ),
  )
}

///|
fn synthetic_kind_name(kind : NormalizedSyntheticKind) -> String {
  match kind {
    LeftRecPrimaryGroup => "left-rec-primary-group"
    LeftRecOperatorGroup => "left-rec-operator-group"
    LeftRecPrecedencePredicate => "left-rec-precedence-predicate"
    LeftRecOperatorLoop => "left-rec-operator-loop"
  }
}

///|
fn decode_synthetic_kind(
  raw : String,
) -> Result[NormalizedSyntheticKind, String] {
  if raw == "left-rec-primary-group" {
    Ok(LeftRecPrimaryGroup)
  } else if raw == "left-rec-operator-group" {
    Ok(LeftRecOperatorGroup)
  } else if raw == "left-rec-precedence-predicate" {
    Ok(LeftRecPrecedencePredicate)
  } else if raw == "left-rec-operator-loop" {
    Ok(LeftRecOperatorLoop)
  } else {
    Err("unknown synthetic kind")
  }
}

///|
fn encode_alt_origin_field(origin : NormalizedAlternativeOrigin?) -> String {
  match origin {
    Some(value) =>
      "1:" +
      value.rule_id.to_string() +
      "," +
      value.alternative_index.to_string() +
      "," +
      encode_option_string_field(value.label)
    None => "0:"
  }
}

///|
fn decode_alt_origin_field(
  raw : String,
) -> Result[NormalizedAlternativeOrigin?, String] {
  if raw.has_prefix("0:") {
    return Ok(None)
  }
  if !raw.has_prefix("1:") {
    return Err("invalid alt-origin field")
  }
  let parts = raw[2:raw.length()]
    .to_string()
    .split(",")
    .map(part => part.to_string())
    .to_array()
  if parts.length() != 3 {
    return Err("invalid alt-origin field")
  }
  let rule_id = match parse_decimal_int(parts[0]) {
    Some(value) => value
    None => return Err("invalid alt-origin rule id")
  }
  let alternative_index = match parse_decimal_int(parts[1]) {
    Some(value) => value
    None => return Err("invalid alt-origin alternative index")
  }
  let label = match decode_option_string_field(parts[2]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(Some({ rule_id, alternative_index, label }))
}

///|
fn encode_alt_origin_array_field(
  values : Array[NormalizedAlternativeOrigin?],
) -> String {
  let encoded : Array[String] = []
  for value in values {
    encoded.push(encode_alt_origin_field(value))
  }
  join_with_separator(encoded, "|")
}

///|
fn decode_alt_origin_array_field(
  raw : String,
) -> Result[Array[NormalizedAlternativeOrigin?], String] {
  if raw == "" {
    return Ok([])
  }
  let values : Array[NormalizedAlternativeOrigin?] = []
  for item in raw.split("|") {
    match decode_alt_origin_field(item.to_string()) {
      Ok(value) => values.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(values)
}

///|
fn encode_origin_field(origin : NormalizedOrigin?) -> String {
  match origin {
    Some(value) =>
      "1:" +
      value.rule.rule_id.to_string() +
      "," +
      encode_string_field(value.rule.rule_name) +
      "," +
      encode_string_field(value.rule.declaring_grammar) +
      "," +
      encode_option_int_field(
        match value.alternative {
          Some(alternative) => Some(alternative.alternative_index)
          None => None
        },
      ) +
      "," +
      encode_option_string_field(
        match value.alternative {
          Some(alternative) => alternative.label
          None => None
        },
      ) +
      "," +
      encode_option_int_field(
        match value.slot {
          Some(slot) => Some(slot.slot_id)
          None => None
        },
      ) +
      "," +
      encode_option_int_field(
        match value.slot {
          Some(slot) => Some(slot.alternative_index)
          None => None
        },
      ) +
      "," +
      encode_option_int_field(
        match value.slot {
          Some(slot) => Some(slot.element_index)
          None => None
        },
      ) +
      "," +
      encode_option_string_field(
        match value.slot {
          Some(slot) =>
            match slot.label {
              Some(label) => Some(label.name)
              None => None
            }
          None => None
        },
      ) +
      "," +
      encode_option_string_field(
        match value.slot {
          Some(slot) =>
            match slot.label {
              Some(label) => Some(if label.is_list { "list" } else { "single" })
              None => None
            }
          None => None
        },
      ) +
      "," +
      encode_option_string_field(
        match value.synthetic_kind {
          Some(kind) => Some(synthetic_kind_name(kind))
          None => None
        },
      )
    None => "0:"
  }
}

///|
fn decode_origin_field(raw : String) -> Result[NormalizedOrigin?, String] {
  if raw.has_prefix("0:") {
    return Ok(None)
  }
  if !raw.has_prefix("1:") {
    return Err("invalid origin field")
  }
  let parts = raw[2:raw.length()]
    .to_string()
    .split(",")
    .map(part => part.to_string())
    .to_array()
  if parts.length() != 11 {
    return Err("invalid origin field")
  }
  let rule_id = match parse_decimal_int(parts[0]) {
    Some(value) => value
    None => return Err("invalid origin rule id")
  }
  let rule_name = match decode_string_field(parts[1]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let declaring_grammar = match decode_string_field(parts[2]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let alternative_index = match decode_option_int_field(parts[3]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let alternative_label = match decode_option_string_field(parts[4]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let slot_id = match decode_option_int_field(parts[5]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let slot_alternative_index = match decode_option_int_field(parts[6]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let slot_element_index = match decode_option_int_field(parts[7]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let slot_label_name = match decode_option_string_field(parts[8]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let slot_label_kind = match decode_option_string_field(parts[9]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let synthetic_kind = match decode_option_string_field(parts[10]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let alternative = match alternative_index {
    Some(index) =>
      Some({ rule_id, alternative_index: index, label: alternative_label })
    None => None
  }
  let slot = match (slot_id, slot_alternative_index, slot_element_index) {
    (Some(id), Some(alt_index), Some(element_index)) =>
      Some({
        rule_id,
        alternative_index: alt_index,
        slot_id: id,
        element_index,
        label: match (slot_label_name, slot_label_kind) {
          (Some(name), Some(kind)) => Some({ name, is_list: kind == "list" })
          _ => None
        },
      })
    _ => None
  }
  let synthetic = match synthetic_kind {
    Some(kind_name) =>
      match decode_synthetic_kind(kind_name) {
        Ok(value) => Some(value)
        Err(error) => return Err(error)
      }
    None => None
  }
  Ok(
    Some({
      rule: { rule_id, rule_name, declaring_grammar },
      alternative,
      slot,
      synthetic_kind: synthetic,
    }),
  )
}

///|
fn encode_slot_source_kind_fields(
  kind : GrammarSlotSourceKind,
) -> (String, String) {
  match kind {
    RuleReferenceSlot(name) => ("rule-ref", encode_string_field(name))
    TokenReferenceSlot(name) => ("token-ref", encode_string_field(name))
    StringLiteralSlot(text) => ("string", encode_string_field(text))
    RangeSlot(text) => ("range", encode_string_field(text))
    CharSetSlot(text) => ("charset", encode_string_field(text))
    WildcardSlot => ("wildcard", "")
    GroupSlot => ("group", "")
    ActionSlot => ("action", "")
    PredicateSlot => ("predicate", "")
  }
}

///|
fn decode_slot_source_kind_field(
  kind_name : String,
  payload : String,
) -> Result[GrammarSlotSourceKind, String] {
  let decoded_payload = match decode_string_field(payload) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if kind_name == "rule-ref" {
    Ok(RuleReferenceSlot(decoded_payload))
  } else if kind_name == "token-ref" {
    Ok(TokenReferenceSlot(decoded_payload))
  } else if kind_name == "string" {
    Ok(StringLiteralSlot(decoded_payload))
  } else if kind_name == "range" {
    Ok(RangeSlot(decoded_payload))
  } else if kind_name == "charset" {
    Ok(CharSetSlot(decoded_payload))
  } else if kind_name == "wildcard" {
    Ok(WildcardSlot)
  } else if kind_name == "group" {
    Ok(GroupSlot)
  } else if kind_name == "action" {
    Ok(ActionSlot)
  } else if kind_name == "predicate" {
    Ok(PredicateSlot)
  } else {
    Err("unknown slot source kind")
  }
}

///|
fn encode_transition_payload(kind : AtnTransitionKind) -> Array[String] {
  match kind {
    EpsilonTransition => ["epsilon", "", "", "", "", ""]
    RuleReferenceTransition(rule_call) =>
      [
        "rule-ref",
        encode_string_field(rule_call.rule_ref.name),
        encode_option_string_field(rule_call.rule_ref.args),
        encode_option_int_field(rule_call.called_rule_id),
        encode_option_int_field(rule_call.follow_state_id),
        "",
      ]
    TokenReferenceTransition(name) =>
      ["token-ref", encode_string_field(name), "", "", "", ""]
    StringLiteralTransition(text) =>
      ["string", encode_string_field(text), "", "", "", ""]
    RangeTransition(text) =>
      ["range", encode_string_field(text), "", "", "", ""]
    CharSetTransition(text) =>
      ["charset", encode_string_field(text), "", "", "", ""]
    SetTransition(values) =>
      ["set", encode_string_array_field(values), "", "", "", ""]
    NotSetTransition(values) =>
      ["not-set", encode_string_array_field(values), "", "", "", ""]
    WildcardTransition => ["wildcard", "", "", "", "", ""]
    ActionTransition(text) =>
      ["action", encode_string_field(text), "", "", "", ""]
    PredicateTransition(text, suffix) =>
      [
        "predicate",
        encode_string_field(text),
        encode_option_string_field(suffix),
        "",
        "",
        "",
      ]
    PrecedenceTransition(precedence, text) =>
      [
        "precedence",
        precedence.to_string(),
        encode_string_field(text),
        "",
        "",
        "",
      ]
    LexerCommandTransition(command) =>
      [
        "lexer-command",
        encode_string_field(command.name),
        encode_option_string_field(command.args),
        encode_span_field(command.span),
        "",
        "",
      ]
  }
}

///|
fn decode_transition_payload(
  kind_name : String,
  payload1 : String,
  payload2 : String,
  payload3 : String,
  payload4 : String,
  payload5 : String,
) -> Result[AtnTransitionKind, String] {
  if kind_name == "epsilon" {
    return Ok(EpsilonTransition)
  }
  if kind_name == "rule-ref" {
    let name = match decode_string_field(payload1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let args = match decode_option_string_field(payload2) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let called_rule_id = match decode_option_int_field(payload3) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let follow_state_id = match decode_option_int_field(payload4) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return Ok(
      RuleReferenceTransition({
        rule_ref: { name, args },
        called_rule_id,
        follow_state_id,
      }),
    )
  }
  if kind_name == "token-ref" {
    return Ok(
      TokenReferenceTransition(
        match decode_string_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "string" {
    return Ok(
      StringLiteralTransition(
        match decode_string_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "range" {
    return Ok(
      RangeTransition(
        match decode_string_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "charset" {
    return Ok(
      CharSetTransition(
        match decode_string_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "set" {
    return Ok(
      SetTransition(
        match decode_string_array_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "not-set" {
    return Ok(
      NotSetTransition(
        match decode_string_array_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "wildcard" {
    return Ok(WildcardTransition)
  }
  if kind_name == "action" {
    return Ok(
      ActionTransition(
        match decode_string_field(payload1) {
          Ok(value) => value
          Err(error) => return Err(error)
        },
      ),
    )
  }
  if kind_name == "predicate" {
    let text = match decode_string_field(payload1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let suffix = match decode_option_string_field(payload2) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return Ok(PredicateTransition(text, suffix))
  }
  if kind_name == "precedence" {
    let precedence = match parse_decimal_int(payload1) {
      Some(value) => value
      None => return Err("invalid precedence payload")
    }
    let text = match decode_string_field(payload2) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return Ok(PrecedenceTransition(precedence, text))
  }
  if kind_name == "lexer-command" {
    let name = match decode_string_field(payload1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let args = match decode_option_string_field(payload2) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let span = match decode_span_field(payload3) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    return Ok(LexerCommandTransition({ name, args, span }))
  }
  let _ = payload5
  Err("unknown transition kind")
}

///|
/// Serialize the Phase 1 ATN contract into a stable line-oriented text format.
///
/// Example:
/// let serialized = serialize_grammar_atn(atn)
/// inspect(serialized.length() > 0, content="true")
///
/// Notes:
/// - The format is intended for tests, snapshots, and Phase 1 deserialization smoke checks.
/// - It preserves public metadata, decision metadata, mode starts, states, transitions, and rule graphs.
pub fn serialize_grammar_atn(atn : GrammarAtn) -> String {
  let lines : Array[String] = []
  lines.push(join_atn_fields(["ATN", atn_serialization_version.to_string()]))
  lines.push(
    join_atn_fields([
      "grammar",
      encode_string_field(atn.grammar_name),
      encode_string_field(grammar_kind_name_for_model(atn.grammar_kind)),
      encode_string_field(atn.grammar_fingerprint),
      encode_option_int_field(atn.start_rule_id),
    ]),
  )
  for rule in atn.public_rules {
    lines.push(
      join_atn_fields([
        "public-rule",
        rule.rule_id.to_string(),
        encode_string_field(rule.name),
        encode_string_field(grammar_rule_kind_name(rule.kind)),
        encode_bool_field(rule.is_fragment),
        encode_option_string_field(rule.signature),
        encode_option_string_field(rule.mode),
        encode_string_field(rule.declaring_grammar),
        encode_span_field(rule.span),
      ]),
    )
  }
  for alternative in atn.public_alternatives {
    lines.push(
      join_atn_fields([
        "public-alt",
        alternative.rule_id.to_string(),
        alternative.alternative_index.to_string(),
        encode_option_string_field(alternative.label),
        encode_span_field(alternative.span),
      ]),
    )
  }
  for slot in atn.public_slots {
    let (slot_kind_name, slot_payload) = encode_slot_source_kind_fields(
      slot.source_kind,
    )
    lines.push(
      join_atn_fields([
        "public-slot",
        slot.rule_id.to_string(),
        slot.alternative_index.to_string(),
        slot.slot_id.to_string(),
        slot.element_index.to_string(),
        encode_option_string_field(
          match slot.label {
            Some(label) => Some(label.name)
            None => None
          },
        ),
        encode_option_string_field(
          match slot.label {
            Some(label) => Some(if label.is_list { "list" } else { "single" })
            None => None
          },
        ),
        encode_string_field(slot_kind_name),
        slot_payload,
        encode_option_string_field(
          match slot.suffix {
            Some(suffix) => Some(ebnf_suffix_kind_name(suffix.kind))
            None => None
          },
        ),
        encode_option_string_field(
          match slot.suffix {
            Some(suffix) =>
              Some(if suffix.greedy { "greedy" } else { "nongreedy" })
            None => None
          },
        ),
        encode_bool_field(slot.negated),
        encode_span_field(slot.span),
      ]),
    )
  }
  for token in atn.public_tokens {
    lines.push(
      join_atn_fields([
        "public-token",
        token.token_id.to_string(),
        encode_string_field(token.name),
        encode_option_string_field(token.literal_name),
        encode_bool_field(token.implicit),
      ]),
    )
  }
  for channel in atn.public_channels {
    lines.push(
      join_atn_fields([
        "public-channel",
        channel.channel_id.to_string(),
        encode_string_field(channel.name),
      ]),
    )
  }
  for mode in atn.public_modes {
    lines.push(
      join_atn_fields([
        "public-mode",
        mode.mode_id.to_string(),
        encode_string_field(mode.name),
      ]),
    )
  }
  for state in atn.states {
    lines.push(
      join_atn_fields([
        "state",
        state.id.to_string(),
        encode_option_string_field(state.rule_name),
        encode_option_int_field(state.rule_id),
        encode_option_string_field(state.mode),
        encode_string_field(atn_state_kind_name(state.kind)),
        encode_bool_field(state.greedy),
        encode_option_int_field(state.decision_id),
        encode_origin_field(state.origin),
      ]),
    )
  }
  for transition in atn.transitions {
    let payload = encode_transition_payload(transition.kind)
    lines.push(
      join_atn_fields([
        "transition",
        transition.source_state_id.to_string(),
        transition.target_state_id.to_string(),
        encode_string_field(payload[0]),
        encode_bool_field(transition.negated),
        transition.order.to_string(),
        payload[1],
        payload[2],
        payload[3],
        payload[4],
        payload[5],
        encode_origin_field(transition.origin),
      ]),
    )
  }
  for rule in atn.rules {
    lines.push(
      join_atn_fields([
        "rule-graph",
        rule.rule_id.to_string(),
        encode_string_field(rule.rule_name),
        encode_string_field(grammar_rule_kind_name(rule.kind)),
        encode_option_string_field(rule.mode),
        encode_option_string_field(rule.signature),
        rule.start_state_id.to_string(),
        rule.stop_state_id.to_string(),
        encode_int_array_field(rule.state_ids),
        encode_int_array_field(rule.decision_ids),
        encode_bool_field(rule.rewritten),
      ]),
    )
  }
  for decision in atn.decisions {
    lines.push(
      join_atn_fields([
        "decision",
        decision.decision_id.to_string(),
        encode_option_string_field(decision.rule_name),
        encode_option_int_field(decision.rule_id),
        decision.state_id.to_string(),
        encode_string_field(atn_decision_kind_name(decision.kind)),
        encode_alt_origin_array_field(decision.public_alternatives),
      ]),
    )
  }
  for mode_start in atn.mode_starts {
    lines.push(
      join_atn_fields([
        "mode-start",
        encode_string_field(mode_start.mode_name),
        mode_start.state_id.to_string(),
        encode_int_array_field(mode_start.rule_ids),
      ]),
    )
  }
  join_atn_lines(lines)
}
