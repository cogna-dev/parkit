///|
/// One parser ATN configuration recorded by the Phase 3 interpreter.
pub struct ParserAtnConfig {
  state_id : Int
  alternative_index : Int
  input_offset : Int
  context_id : Int
  precedence : Int
}

///|
/// Stable wrapper for one deduplicated parser-config slice.
pub struct ParserConfigSet {
  configs : Array[ParserAtnConfig]
}

///|
fn parser_copy_configs(
  values : Array[ParserAtnConfig],
) -> Array[ParserAtnConfig] {
  let copied : Array[ParserAtnConfig] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_config_exists(
  values : Array[ParserAtnConfig],
  wanted : ParserAtnConfig,
) -> Bool {
  for value in values {
    if value.state_id == wanted.state_id &&
      value.alternative_index == wanted.alternative_index &&
      value.input_offset == wanted.input_offset &&
      value.context_id == wanted.context_id &&
      value.precedence == wanted.precedence {
      return true
    }
  }
  false
}

///|
fn parser_render_config(
  config : ParserAtnConfig,
  contexts : PredictionContextArena,
) -> String {
  config.state_id.to_string() +
  "@" +
  config.alternative_index.to_string() +
  "@" +
  config.input_offset.to_string() +
  "@" +
  contexts.render_context(config.context_id) +
  "@" +
  config.precedence.to_string()
}

///|
/// Build a deduplicated parser config set while preserving first-seen order.
///
/// Example:
/// let set = make_parser_config_set([])
/// inspect(set.configs.length(), content="0")
///
/// Notes:
/// - Duplicate `(state, alt, input, context, precedence)` tuples are removed.
/// - The result is intended for decision tracing, DFA entries, and regression snapshots.
pub fn make_parser_config_set(
  configs : Array[ParserAtnConfig],
) -> ParserConfigSet {
  let unique : Array[ParserAtnConfig] = []
  for config in configs {
    if !parser_config_exists(unique, config) {
      unique.push(config)
    }
  }
  { configs: unique }
}

///|
/// Render one stable signature for parser-config comparisons and DFA traces.
///
/// Example:
/// let signature = make_parser_config_set([]).signature(new_prediction_context_arena())
/// inspect(signature, content="")
///
/// Notes:
/// - Context ids are rendered through the supplied prediction-context arena.
pub fn ParserConfigSet::signature(
  self : ParserConfigSet,
  contexts : PredictionContextArena,
) -> String {
  if self.configs.length() == 0 {
    return ""
  }
  let mut signature = parser_render_config(self.configs[0], contexts)
  for index = 1; index < self.configs.length(); index = index + 1 {
    signature = signature +
      "|" +
      parser_render_config(self.configs[index], contexts)
  }
  signature
}
