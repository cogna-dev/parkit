///|
/// Stable slot source categories emitted by the Phase 1 semantic model.
pub(all) enum GrammarSlotSourceKind {
  RuleReferenceSlot(String)
  TokenReferenceSlot(String)
  StringLiteralSlot(String)
  RangeSlot(String)
  CharSetSlot(String)
  WildcardSlot
  GroupSlot
  ActionSlot
  PredicateSlot
}

///|
/// Stable rule metadata after semantic symbol assignment.
pub struct GrammarRuleSymbol {
  rule_id : Int
  name : String
  kind : GrammarRuleKind
  is_fragment : Bool
  signature : String?
  mode : String?
  declaring_grammar : String
  span : SourceSpan
}

///|
/// Stable alternative metadata keyed by original rule order and alt index.
pub struct GrammarAlternativeSymbol {
  rule_id : Int
  alternative_index : Int
  label : String?
  span : SourceSpan
}

///|
/// Stable direct-element slot metadata used by later CST lowering and origin mapping.
pub struct GrammarSlotSymbol {
  rule_id : Int
  alternative_index : Int
  slot_id : Int
  element_index : Int
  label : ElementLabel?
  source_kind : GrammarSlotSourceKind
  suffix : EbnfSuffix?
  negated : Bool
  span : SourceSpan
}

///|
/// Stable token assignment entry for lexer rules, tokens blocks, and implicit literals.
pub struct GrammarTokenSymbol {
  token_id : Int
  name : String
  literal_name : String?
  implicit : Bool
}

///|
/// Stable channel assignment entry.
pub struct GrammarChannelSymbol {
  channel_id : Int
  name : String
}

///|
/// Stable lexer mode assignment entry.
pub struct GrammarModeSymbol {
  mode_id : Int
  name : String
}

///|
/// Stable semantic contract consumed by normalization, ATN lowering, and CST metadata.
pub struct SemanticModel {
  grammar_name : String
  grammar_kind : GrammarKind
  imports : Array[String]
  options : Array[GrammarOptionEntry]
  named_actions : Array[NamedActionEntry]
  grammar_fingerprint : String
  start_rule_id : Int?
  rules : Array[GrammarRuleSymbol]
  alternatives : Array[GrammarAlternativeSymbol]
  slots : Array[GrammarSlotSymbol]
  tokens : Array[GrammarTokenSymbol]
  channels : Array[GrammarChannelSymbol]
  modes : Array[GrammarModeSymbol]
}

///|
fn grammar_kind_name_for_model(kind : GrammarKind) -> String {
  match kind {
    Combined => "combined"
    Lexer => "lexer"
    Parser => "parser"
  }
}

///|
fn model_grammar_is_parser(kind : GrammarKind) -> Bool {
  match kind {
    Parser => true
    _ => false
  }
}

///|
fn model_grammar_is_lexer(kind : GrammarKind) -> Bool {
  match kind {
    Lexer => true
    _ => false
  }
}

///|
fn model_rule_is_parser(kind : GrammarRuleKind) -> Bool {
  match kind {
    ParserRule => true
    _ => false
  }
}

///|
fn model_rule_is_lexer(kind : GrammarRuleKind) -> Bool {
  match kind {
    LexerRule => true
    _ => false
  }
}

///|
fn contains_text(values : Array[String], wanted : String) -> Bool {
  for value in values {
    if value == wanted {
      return true
    }
  }
  false
}

///|
fn join_lines(lines : Array[String]) -> String {
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
fn label_fingerprint(label : ElementLabel?) -> String {
  match label {
    Some(value) =>
      value.name + ":" + (if value.is_list { "list" } else { "single" })
    None => "-"
  }
}

///|
fn suffix_fingerprint(suffix : EbnfSuffix?) -> String {
  match suffix {
    Some(value) =>
      ebnf_suffix_kind_name(value.kind) +
      ":" +
      (if value.greedy { "greedy" } else { "nongreedy" })
    None => "-"
  }
}

///|
fn slot_source_kind_for_element(
  element : GrammarElement,
) -> GrammarSlotSourceKind {
  match element.kind {
    RuleReferenceElement(rule_ref) => RuleReferenceSlot(rule_ref.name)
    TokenReferenceElement(name) => TokenReferenceSlot(name)
    StringLiteralElement(text) => StringLiteralSlot(text)
    RangeElement(text) => RangeSlot(text)
    CharSetElement(text) => CharSetSlot(text)
    WildcardElement => WildcardSlot
    GroupElement(_) => GroupSlot
    ActionElement(_) => ActionSlot
    PredicateElement(_, _) => PredicateSlot
  }
}

///|
fn collect_string_literals_from_elements(
  elements : Array[GrammarElement],
  into : Array[String],
) -> Unit {
  for element in elements {
    match element.kind {
      StringLiteralElement(text) =>
        if !contains_text(into, text) {
          into.push(text)
        }
      GroupElement(alternatives) =>
        for alternative in alternatives {
          collect_string_literals_from_elements(alternative.elements, into)
        }
      _ => ()
    }
  }
}

///|
fn add_default_channels(grammar : GrammarSpec) -> Array[GrammarChannelSymbol] {
  let channels : Array[GrammarChannelSymbol] = []
  let mut next_channel_id = 0
  if !model_grammar_is_parser(grammar.kind) {
    channels.push({ channel_id: next_channel_id, name: "DEFAULT_TOKEN_CHANNEL" })
    next_channel_id = next_channel_id + 1
    channels.push({ channel_id: next_channel_id, name: "HIDDEN" })
    next_channel_id = next_channel_id + 1
  }
  for channel_name in grammar.channel_names {
    let duplicate = channels.any(fn(existing) { existing.name == channel_name })
    if !duplicate {
      channels.push({ channel_id: next_channel_id, name: channel_name })
      next_channel_id = next_channel_id + 1
    }
  }
  channels
}

///|
fn add_default_modes(grammar : GrammarSpec) -> Array[GrammarModeSymbol] {
  let modes : Array[GrammarModeSymbol] = []
  let mut next_mode_id = 0
  if !model_grammar_is_parser(grammar.kind) {
    modes.push({ mode_id: next_mode_id, name: "DEFAULT_MODE" })
    next_mode_id = next_mode_id + 1
  }
  for mode_name in grammar.modes {
    let duplicate = modes.any(fn(existing) { existing.name == mode_name })
    if !duplicate {
      modes.push({ mode_id: next_mode_id, name: mode_name })
      next_mode_id = next_mode_id + 1
    }
  }
  modes
}

///|
fn collect_rule_symbols(grammar : GrammarSpec) -> Array[GrammarRuleSymbol] {
  let rules : Array[GrammarRuleSymbol] = []
  for index = 0; index < grammar.rules.length(); index = index + 1 {
    let rule = grammar.rules[index]
    rules.push({
      rule_id: index,
      name: rule.name,
      kind: rule.kind,
      is_fragment: rule.is_fragment,
      signature: rule.signature,
      mode: rule.mode,
      declaring_grammar: grammar.name,
      span: rule.span,
    })
  }
  rules
}

///|
fn collect_alternative_symbols(
  grammar : GrammarSpec,
) -> Array[GrammarAlternativeSymbol] {
  let alternatives : Array[GrammarAlternativeSymbol] = []
  for rule_index = 0
      rule_index < grammar.rules.length()
      rule_index = rule_index + 1 {
    let rule = grammar.rules[rule_index]
    for alt_index = 0
        alt_index < rule.alternatives.length()
        alt_index = alt_index + 1 {
      let alternative = rule.alternatives[alt_index]
      alternatives.push({
        rule_id: rule_index,
        alternative_index: alt_index + 1,
        label: alternative.label,
        span: alternative.span,
      })
    }
  }
  alternatives
}

///|
fn collect_slot_symbols(grammar : GrammarSpec) -> Array[GrammarSlotSymbol] {
  let slots : Array[GrammarSlotSymbol] = []
  for rule_index = 0
      rule_index < grammar.rules.length()
      rule_index = rule_index + 1 {
    let rule = grammar.rules[rule_index]
    for alt_index = 0
        alt_index < rule.alternatives.length()
        alt_index = alt_index + 1 {
      let alternative = rule.alternatives[alt_index]
      let mut slot_id = 0
      for element_index = 0
          element_index < alternative.elements.length()
          element_index = element_index + 1 {
        let element = alternative.elements[element_index]
        slots.push({
          rule_id: rule_index,
          alternative_index: alt_index + 1,
          slot_id,
          element_index,
          label: element.label,
          source_kind: slot_source_kind_for_element(element),
          suffix: element.suffix,
          negated: element.negated,
          span: element.span,
        })
        slot_id = slot_id + 1
      }
    }
  }
  slots
}

///|
fn collect_token_symbols(grammar : GrammarSpec) -> Array[GrammarTokenSymbol] {
  let tokens : Array[GrammarTokenSymbol] = []
  let declared_names : Array[String] = []
  let mut next_token_id = 0

  for token_name in grammar.token_names {
    if !contains_text(declared_names, token_name) {
      declared_names.push(token_name)
      tokens.push({
        token_id: next_token_id,
        name: token_name,
        literal_name: None,
        implicit: false,
      })
      next_token_id = next_token_id + 1
    }
  }

  for rule in grammar.rules {
    if model_rule_is_lexer(rule.kind) &&
      !rule.is_fragment &&
      !contains_text(declared_names, rule.name) {
      declared_names.push(rule.name)
      tokens.push({
        token_id: next_token_id,
        name: rule.name,
        literal_name: None,
        implicit: false,
      })
      next_token_id = next_token_id + 1
    }
  }

  let implicit_literals : Array[String] = []
  for rule in grammar.rules {
    if model_rule_is_parser(rule.kind) {
      for alternative in rule.alternatives {
        collect_string_literals_from_elements(
          alternative.elements,
          implicit_literals,
        )
      }
    }
  }
  for index = 0; index < implicit_literals.length(); index = index + 1 {
    let literal = implicit_literals[index]
    tokens.push({
      token_id: next_token_id,
      name: "T__" + index.to_string(),
      literal_name: Some(literal),
      implicit: true,
    })
    next_token_id = next_token_id + 1
  }
  tokens
}

///|
fn find_start_rule_id(
  rules : Array[GrammarRuleSymbol],
  grammar_kind : GrammarKind,
) -> Int? {
  for rule in rules {
    if model_rule_is_parser(rule.kind) {
      return Some(rule.rule_id)
    }
  }
  if model_grammar_is_lexer(grammar_kind) {
    for rule in rules {
      if model_rule_is_lexer(rule.kind) && !rule.is_fragment {
        return Some(rule.rule_id)
      }
    }
  }
  None
}

///|
fn build_semantic_fingerprint(
  grammar : GrammarSpec,
  rules : Array[GrammarRuleSymbol],
  alternatives : Array[GrammarAlternativeSymbol],
  slots : Array[GrammarSlotSymbol],
  tokens : Array[GrammarTokenSymbol],
  channels : Array[GrammarChannelSymbol],
  modes : Array[GrammarModeSymbol],
  start_rule_id : Int?,
) -> String {
  let lines : Array[String] = []
  lines.push("grammar=" + grammar.name)
  lines.push("kind=" + grammar_kind_name_for_model(grammar.kind))
  match start_rule_id {
    Some(value) => lines.push("start_rule_id=" + value.to_string())
    None => lines.push("start_rule_id=-")
  }
  for import_name in grammar.imports {
    lines.push("import=" + import_name)
  }
  for option in grammar.options {
    lines.push("option=" + option.name + "=" + option.value)
  }
  for rule in rules {
    lines.push(
      "rule=" +
      rule.rule_id.to_string() +
      ":" +
      rule.name +
      ":" +
      grammar_rule_kind_name(rule.kind) +
      ":" +
      (if rule.is_fragment { "fragment" } else { "normal" }) +
      ":" +
      (match rule.signature {
        Some(signature) => signature
        None => "-"
      }) +
      ":" +
      (match rule.mode {
        Some(mode_name) => mode_name
        None => "-"
      }),
    )
  }
  for alternative in alternatives {
    lines.push(
      "alt=" +
      alternative.rule_id.to_string() +
      ":" +
      alternative.alternative_index.to_string() +
      ":" +
      (match alternative.label {
        Some(label) => label
        None => "-"
      }),
    )
  }
  for slot in slots {
    lines.push(
      "slot=" +
      slot.rule_id.to_string() +
      ":" +
      slot.alternative_index.to_string() +
      ":" +
      slot.slot_id.to_string() +
      ":" +
      slot.element_index.to_string() +
      ":" +
      grammar_slot_source_kind_name(slot.source_kind) +
      ":" +
      label_fingerprint(slot.label) +
      ":" +
      suffix_fingerprint(slot.suffix) +
      ":" +
      (if slot.negated { "negated" } else { "plain" }),
    )
  }
  for token in tokens {
    lines.push(
      "token=" +
      token.token_id.to_string() +
      ":" +
      token.name +
      ":" +
      (match token.literal_name {
        Some(literal_name) => literal_name
        None => "-"
      }) +
      ":" +
      (if token.implicit { "implicit" } else { "explicit" }),
    )
  }
  for channel in channels {
    lines.push("channel=" + channel.channel_id.to_string() + ":" + channel.name)
  }
  for mode in modes {
    lines.push("mode=" + mode.mode_id.to_string() + ":" + mode.name)
  }
  join_lines(lines)
}

///|
/// Return a stable diagnostic name for one semantic slot source category.
///
/// Example:
/// inspect(grammar_slot_source_kind_name(TokenReferenceSlot("ID")), content="token-ref")
///
/// Notes:
/// - The returned name is intended for diagnostics, tests, and fingerprinting.
/// - Payload text is intentionally omitted from the returned label.
pub fn grammar_slot_source_kind_name(kind : GrammarSlotSourceKind) -> String {
  match kind {
    RuleReferenceSlot(_) => "rule-ref"
    TokenReferenceSlot(_) => "token-ref"
    StringLiteralSlot(_) => "string"
    RangeSlot(_) => "range"
    CharSetSlot(_) => "charset"
    WildcardSlot => "wildcard"
    GroupSlot => "group"
    ActionSlot => "action"
    PredicateSlot => "predicate"
  }
}

///|
/// Build the stable semantic model consumed by normalization and ATN lowering.
///
/// Example:
/// let model = build_semantic_model(grammar)
/// inspect(model.rules.length() > 0, content="true")
///
/// Notes:
/// - Rule ids follow original rule order and remain local to one grammar.
/// - Slot ids are assigned per original alternative over its direct elements.
pub fn build_semantic_model(grammar : GrammarSpec) -> SemanticModel {
  let rules = collect_rule_symbols(grammar)
  let alternatives = collect_alternative_symbols(grammar)
  let slots = collect_slot_symbols(grammar)
  let tokens = collect_token_symbols(grammar)
  let channels = add_default_channels(grammar)
  let modes = add_default_modes(grammar)
  let start_rule_id = find_start_rule_id(rules, grammar.kind)
  {
    grammar_name: grammar.name,
    grammar_kind: grammar.kind,
    imports: grammar.imports,
    options: grammar.options,
    named_actions: grammar.named_actions,
    grammar_fingerprint: build_semantic_fingerprint(
      grammar, rules, alternatives, slots, tokens, channels, modes, start_rule_id,
    ),
    start_rule_id,
    rules,
    alternatives,
    slots,
    tokens,
    channels,
    modes,
  }
}

///|
/// Find stable rule metadata by exact rule name.
///
/// Example:
/// let rule = model.find_rule("expr")
/// inspect(rule is Some(_), content="true")
///
/// Notes:
/// - Rule names are matched exactly and case-sensitively.
/// - Returns `None` when the rule does not exist in this semantic model.
pub fn SemanticModel::find_rule(
  self : SemanticModel,
  rule_name : String,
) -> GrammarRuleSymbol? {
  for rule in self.rules {
    if rule.name == rule_name {
      return Some(rule)
    }
  }
  None
}

///|
/// Return the semantic-model start rule when one is defined.
///
/// Example:
/// let start_rule = model.start_rule()
/// inspect(start_rule is Some(_), content="true")
///
/// Notes:
/// - Parser and combined grammars use the first parser rule as the start rule.
/// - Lexer grammars fall back to the first non-fragment lexer rule.
pub fn SemanticModel::start_rule(self : SemanticModel) -> GrammarRuleSymbol? {
  match self.start_rule_id {
    Some(rule_id) => {
      for rule in self.rules {
        if rule.rule_id == rule_id {
          return Some(rule)
        }
      }
      None
    }
    None => None
  }
}
