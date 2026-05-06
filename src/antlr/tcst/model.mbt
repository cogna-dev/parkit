///|
/// Supported cardinality kinds for generated typed CST fields.
pub(all) enum TypedCardinality {
  Required
  Optional
  Repeated
  NonEmptyRepeated
}

///|
/// Stable field categories emitted by the typed CST generator.
pub(all) enum TypedFieldKind {
  RuleNodeField(String)
  TokenField(String?, String?)
}

///|
/// Public grammar identity attached to one generated typed CST package.
pub(all) struct TypedGrammarInfo {
  grammar_name : String
  grammar_kind : @antlr.GrammarKind
  start_rule_name : String
  grammar_fingerprint : String
  cst_schema_version : Int
}

///|
/// One generated field inside one typed CST constructor payload.
pub(all) struct TypedFieldModel {
  field_name : String
  slot_id : Int
  element_index : Int
  cardinality : TypedCardinality
  kind : TypedFieldKind
  type_name : String
}

///|
/// One generated constructor mapped from one original grammar alternative.
pub(all) struct TypedConstructorModel {
  alternative_index : Int
  alternative_label : String?
  constructor_name : String
  payload_type_name : String
  fields : Array[TypedFieldModel]
}

///|
/// One generated rule enum mapped from one original parser rule.
pub(all) struct TypedRuleModel {
  rule_id : Int
  rule_name : String
  type_name : String
  constructors : Array[TypedConstructorModel]
}

///|
/// One complete generated typed CST package model.
pub(all) struct TypedPackageModel {
  grammar_source : String
  package_name : String
  grammar : TypedGrammarInfo
  root_rule_name : String
  root_type_name : String
  rules : Array[TypedRuleModel]
}

///|
/// One rendered file emitted by the typed CST generator.
pub(all) struct TypedPackageFile {
  relative_path : String
  content : String
}

///|
fn typed_ascii_lower_char(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' {
    (c.to_int() - 'A'.to_int() + 'a'.to_int()).unsafe_to_char()
  } else {
    c
  }
}

///|
fn typed_ascii_upper_char(c : Char) -> Char {
  if c >= 'a' && c <= 'z' {
    (c.to_int() - 'a'.to_int() + 'A'.to_int()).unsafe_to_char()
  } else {
    c
  }
}

///|
fn typed_is_alphanumeric(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

///|
fn typed_identifier_words(value : String) -> Array[String] {
  let words : Array[String] = []
  let mut current = ""
  for c in value {
    if typed_is_alphanumeric(c) {
      current = current + String::make(1, typed_ascii_lower_char(c))
    } else if current != "" {
      words.push(current)
      current = ""
    }
  }
  if current != "" {
    words.push(current)
  }
  words
}

///|
fn typed_upper_camel(value : String) -> String {
  let words = typed_identifier_words(value)
  if words.length() == 0 {
    return "Generated"
  }
  let mut result = ""
  for word in words {
    if word.length() == 0 {
      ()
    } else {
      result = result +
        String::make(1, typed_ascii_upper_char(word.get_char(0).unwrap())) +
        word[1:word.length()].to_string()
    }
  }
  result
}

///|
fn typed_snake_case(value : String) -> String {
  let words = typed_identifier_words(value)
  if words.length() == 0 {
    return "generated"
  }
  let mut result = words[0]
  for index = 1; index < words.length(); index = index + 1 {
    result = result + "_" + words[index]
  }
  result
}

///|
fn typed_strip_literal_quotes(value : String) -> String {
  if value.length() >= 2 {
    let first = value.get_char(0).unwrap()
    let last = value.get_char(value.length() - 1).unwrap()
    if (first == '\'' && last == '\'') || (first == '"' && last == '"') {
      return value[1:value.length() - 1].to_string()
    }
  }
  value
}

///|
fn typed_literal_token_base_name(literal_text : String) -> String {
  let inner = typed_strip_literal_quotes(literal_text)
  match inner {
    "+" => "plus_token"
    "-" => "minus_token"
    "*" => "star_token"
    "/" => "slash_token"
    "%" => "percent_token"
    "(" => "lparen_token"
    ")" => "rparen_token"
    "{" => "lcurly_token"
    "}" => "rcurly_token"
    "[" => "lbrack_token"
    "]" => "rbrack_token"
    "," => "comma_token"
    "." => "dot_token"
    ";" => "semicolon_token"
    ":" => "colon_token"
    "?" => "question_token"
    "!" => "bang_token"
    "~" => "tilde_token"
    "|" => "pipe_token"
    "&" => "amp_token"
    "^" => "caret_token"
    "=" => "eq_token"
    "<" => "lt_token"
    ">" => "gt_token"
    "<=" => "lte_token"
    ">=" => "gte_token"
    "==" => "eqeq_token"
    "!=" => "neq_token"
    _ => typed_snake_case(inner) + "_token"
  }
}

///|
fn typed_cardinality_for_slot(
  slot : @antlr.GrammarSlotSymbol,
) -> TypedCardinality {
  let list_label = match slot.label {
    Some(label) => label.is_list
    None => false
  }
  match slot.suffix {
    Some(suffix) =>
      match suffix.kind {
        @antlr.OptionalSuffix => Optional
        @antlr.ZeroOrMoreSuffix => Repeated
        @antlr.OneOrMoreSuffix => NonEmptyRepeated
      }
    None => if list_label { NonEmptyRepeated } else { Required }
  }
}

///|
fn typed_rule_type_name(rule_name : String) -> String {
  typed_upper_camel(rule_name) + "Node"
}

///|
fn typed_payload_type_name(
  rule_name : String,
  constructor_name : String,
) -> String {
  typed_upper_camel(rule_name) + constructor_name + "Fields"
}

///|
fn typed_constructor_name(
  alternative : @antlr.GrammarAlternativeSymbol,
) -> String {
  match alternative.label {
    Some(label) => typed_upper_camel(label)
    None => "Alt" + alternative.alternative_index.to_string()
  }
}

///|
fn typed_field_base_name(
  slot : @antlr.GrammarSlotSymbol,
) -> Result[String, String] {
  match slot.label {
    Some(label) => Ok(label.name)
    None =>
      match slot.source_kind {
        @antlr.RuleReferenceSlot(rule_name) => Ok(typed_snake_case(rule_name))
        @antlr.TokenReferenceSlot(token_name) =>
          Ok(typed_snake_case(token_name) + "_token")
        @antlr.StringLiteralSlot(literal_text) =>
          Ok(typed_literal_token_base_name(literal_text))
        @antlr.RangeSlot(_) => Ok("range_token")
        @antlr.CharSetSlot(_) => Ok("charset_token")
        @antlr.WildcardSlot => Ok("wildcard_token")
        @antlr.GroupSlot =>
          Err("typed CST generator does not yet support direct group slots")
        @antlr.ActionSlot =>
          Err(
            "typed CST generator does not lower action slots into typed fields",
          )
        @antlr.PredicateSlot =>
          Err(
            "typed CST generator does not lower predicate slots into typed fields",
          )
      }
  }
}

///|
fn typed_field_model_for_slot(
  slot : @antlr.GrammarSlotSymbol,
) -> Result[TypedFieldModel, String] {
  let field_name = match typed_field_base_name(slot) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let cardinality = typed_cardinality_for_slot(slot)
  match slot.source_kind {
    @antlr.RuleReferenceSlot(rule_name) =>
      Ok({
        field_name,
        slot_id: slot.slot_id,
        element_index: slot.element_index,
        cardinality,
        kind: RuleNodeField(rule_name),
        type_name: typed_rule_type_name(rule_name),
      })
    @antlr.TokenReferenceSlot(token_name) =>
      Ok({
        field_name,
        slot_id: slot.slot_id,
        element_index: slot.element_index,
        cardinality,
        kind: TokenField(Some(token_name), None),
        type_name: "@antlr_tcst.TerminalToken",
      })
    @antlr.StringLiteralSlot(literal_text) =>
      Ok({
        field_name,
        slot_id: slot.slot_id,
        element_index: slot.element_index,
        cardinality,
        kind: TokenField(None, Some(literal_text)),
        type_name: "@antlr_tcst.TerminalToken",
      })
    @antlr.RangeSlot(_) | @antlr.CharSetSlot(_) | @antlr.WildcardSlot =>
      Ok({
        field_name,
        slot_id: slot.slot_id,
        element_index: slot.element_index,
        cardinality,
        kind: TokenField(None, None),
        type_name: "@antlr_tcst.TerminalToken",
      })
    @antlr.GroupSlot =>
      Err("typed CST generator does not yet support direct group slots")
    @antlr.ActionSlot =>
      Err("typed CST generator does not lower action slots into typed fields")
    @antlr.PredicateSlot =>
      Err(
        "typed CST generator does not lower predicate slots into typed fields",
      )
  }
}

///|
fn typed_field_name_count(
  fields : Array[TypedFieldModel],
  name : String,
) -> Int {
  let mut count = 0
  for field in fields {
    if field.field_name == name {
      count = count + 1
    }
  }
  count
}

///|
fn typed_field_name_seen_before(
  fields : Array[TypedFieldModel],
  name : String,
  stop_before : Int,
) -> Int {
  let mut count = 0
  for index = 0; index < stop_before; index = index + 1 {
    if fields[index].field_name == name {
      count = count + 1
    }
  }
  count
}

///|
fn typed_disambiguate_field_names(
  fields : Array[TypedFieldModel],
) -> Array[TypedFieldModel] {
  let renamed : Array[TypedFieldModel] = []
  for index = 0; index < fields.length(); index = index + 1 {
    let field = fields[index]
    let duplicates = typed_field_name_count(fields, field.field_name)
    if duplicates <= 1 {
      renamed.push(field)
    } else {
      let ordinal = typed_field_name_seen_before(
          fields,
          field.field_name,
          index,
        ) +
        1
      renamed.push({
        field_name: field.field_name + "_" + ordinal.to_string(),
        slot_id: field.slot_id,
        element_index: field.element_index,
        cardinality: field.cardinality,
        kind: field.kind,
        type_name: field.type_name,
      })
    }
  }
  renamed
}

///|
fn typed_constructor_model_for_alternative(
  model : @antlr.SemanticModel,
  rule : @antlr.GrammarRuleSymbol,
  alternative : @antlr.GrammarAlternativeSymbol,
) -> Result[TypedConstructorModel, String] {
  let fields : Array[TypedFieldModel] = []
  for slot in model.slots {
    if slot.rule_id == rule.rule_id &&
      slot.alternative_index == alternative.alternative_index {
      match typed_field_model_for_slot(slot) {
        Ok(field) => fields.push(field)
        Err(error) =>
          return Err(
            "typed CST generator cannot lower rule `" +
            rule.name +
            "` alternative " +
            alternative.alternative_index.to_string() +
            ": " +
            error,
          )
      }
    }
  }
  let constructor_name = typed_constructor_name(alternative)
  Ok({
    alternative_index: alternative.alternative_index,
    alternative_label: alternative.label,
    constructor_name,
    payload_type_name: typed_payload_type_name(rule.name, constructor_name),
    fields: typed_disambiguate_field_names(fields),
  })
}

///|
fn typed_rule_model_for_rule(
  model : @antlr.SemanticModel,
  rule : @antlr.GrammarRuleSymbol,
) -> Result[TypedRuleModel, String] {
  let constructors : Array[TypedConstructorModel] = []
  for alternative in model.alternatives {
    if alternative.rule_id == rule.rule_id {
      match typed_constructor_model_for_alternative(model, rule, alternative) {
        Ok(constructor_model) => constructors.push(constructor_model)
        Err(error) => return Err(error)
      }
    }
  }
  Ok({
    rule_id: rule.rule_id,
    rule_name: rule.name,
    type_name: typed_rule_type_name(rule.name),
    constructors,
  })
}

///|
/// Build the typed CST package model for one fixed grammar source.
///
/// Example:
/// let model = build_typed_package_model("grammar Hello; r : 'x' ID ; ID : [a-z]+ ; WS : [ \r\n\t]+ -> skip ;", "cogna-dev/parkit/antlr/generated/hello")
/// inspect(model is Ok(_), content="true")
///
/// Notes:
/// - The function runs the existing frontend pipeline and only succeeds when semantic analysis succeeds.
/// - Lexer-only grammars are rejected because Phase 6 generates typed CST roots only for parser or combined grammars.
pub fn build_typed_package_model(
  source : String,
  package_name : String,
) -> Result[TypedPackageModel, String] {
  let report = @antlr.run_frontend_pipeline(source)
  if report.has_errors() {
    let diagnostics = report.all_diagnostics()
    if diagnostics.length() == 0 {
      return Err("typed CST generator requires a successful frontend pipeline")
    }
    return Err(diagnostics[0].message)
  }
  let model = match report.semantic_model {
    Some(value) => value
    None => return Err("typed CST generator requires a semantic model")
  }
  match model.grammar_kind {
    @antlr.Lexer =>
      return Err(
        "typed CST generator only supports parser and combined grammars",
      )
    _ => ()
  }
  let start_rule = match model.start_rule() {
    Some(value) => value
    None => return Err("typed CST generator requires a start rule")
  }
  let rules : Array[TypedRuleModel] = []
  for rule in model.rules {
    match rule.kind {
      @antlr.ParserRule =>
        match typed_rule_model_for_rule(model, rule) {
          Ok(rule_model) => rules.push(rule_model)
          Err(error) => return Err(error)
        }
      _ => ()
    }
  }
  Ok({
    grammar_source: source,
    package_name,
    grammar: {
      grammar_name: model.grammar_name,
      grammar_kind: model.grammar_kind,
      start_rule_name: start_rule.name,
      grammar_fingerprint: model.grammar_fingerprint,
      cst_schema_version: 1,
    },
    root_rule_name: start_rule.name,
    root_type_name: typed_rule_type_name(start_rule.name),
    rules,
  })
}
