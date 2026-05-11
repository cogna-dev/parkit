///|
/// One runtime ATN configuration recorded by the Phase 2 lexer interpreter.
pub struct LexerAtnConfig {
  state_id : Int
  input_offset : Int
  rule_id : Int?
}

///|
/// Stable wrapper for one deduplicated configuration slice.
pub struct LexerConfigSet {
  configs : Array[LexerAtnConfig]
}

///|
/// Build a deduplicated lexer config set while preserving first-seen order.
///
/// Example:
/// let set = make_lexer_config_set([{ state_id: 1, input_offset: 0, rule_id: None }])
/// inspect(set.configs.length(), content="1")
///
/// Notes:
/// - The result is intended for debugging, caching, and regression serialization.
/// - Duplicate `(state_id, input_offset, rule_id)` tuples are removed.
pub fn make_lexer_config_set(configs : Array[LexerAtnConfig]) -> LexerConfigSet {
  let unique : Array[LexerAtnConfig] = []
  for config in configs {
    if !lexer_config_exists(unique, config) {
      unique.push(config)
    }
  }
  { configs: unique }
}

///|
/// Render one stable signature for config-set comparisons and cache snapshots.
///
/// Example:
/// let signature = make_lexer_config_set([{ state_id: 1, input_offset: 0, rule_id: None }]).signature()
/// inspect(signature, content="1@0@-")
///
/// Notes:
/// - The signature preserves config order after deduplication.
pub fn LexerConfigSet::signature(self : LexerConfigSet) -> String {
  if self.configs.length() == 0 {
    return ""
  }
  let mut signature = render_lexer_config(self.configs[0])
  for index = 1; index < self.configs.length(); index = index + 1 {
    signature = signature + "|" + render_lexer_config(self.configs[index])
  }
  signature
}

///|
fn render_lexer_config(config : LexerAtnConfig) -> String {
  let rule_id = match config.rule_id {
    Some(value) => value.to_string()
    None => "-"
  }
  config.state_id.to_string() +
  "@" +
  config.input_offset.to_string() +
  "@" +
  rule_id
}

///|
fn lexer_config_exists(
  values : Array[LexerAtnConfig],
  wanted : LexerAtnConfig,
) -> Bool {
  for value in values {
    if value.state_id == wanted.state_id &&
      value.input_offset == wanted.input_offset &&
      option_int_equals(value.rule_id, wanted.rule_id) {
      return true
    }
  }
  false
}

///|
fn option_int_equals(left : Int?, right : Int?) -> Bool {
  match (left, right) {
    (Some(lhs), Some(rhs)) => lhs == rhs
    (None, None) => true
    _ => false
  }
}
