///|
priv struct LexerEffects {
  commands : Array[@antlr.LexerCommandSpec]
  action_texts : Array[String]
  action_labels : Array[String]
}

///|
priv struct RuleSuffixMatch {
  end_stream : CharStream
  effects : LexerEffects
  configs : Array[LexerAtnConfig]
}

///|
priv struct CachedSuffixEntry {
  mode_name : String
  state_id : Int
  input_offset : Int
  result : RuleSuffixMatch?
}

///|
priv struct VisitKey {
  state_id : Int
  input_offset : Int
}

///|
priv struct CallKey {
  rule_id : Int
  input_offset : Int
}

///|
priv struct PendingToken {
  start_offset : Int
  start_pos : @antlr.SourcePos
  start_mode_id : Int
  start_mode_name : String
  token_name : String?
  channel_name : String?
}

///|
priv struct RuleCandidate {
  rule_name : String
  emitted_token_name : String
  priority : Int
  implicit : Bool
  matched : RuleSuffixMatch
}

///|
priv struct ModeMatchAttempt {
  candidate : RuleCandidate?
  dfa_entries : Array[LexerDfaEntry]
}

///|
priv struct CommandOutcome {
  skip : Bool
  more : Bool
  token_name : String?
  channel_name : String?
  next_mode_name : String
  next_mode_stack : Array[String]
}

///|
fn empty_effects() -> LexerEffects {
  { commands: [], action_texts: [], action_labels: [] }
}

///|
fn copy_command_specs(
  values : Array[@antlr.LexerCommandSpec],
) -> Array[@antlr.LexerCommandSpec] {
  let copied : Array[@antlr.LexerCommandSpec] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_strings(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_configs(values : Array[LexerAtnConfig]) -> Array[LexerAtnConfig] {
  let copied : Array[LexerAtnConfig] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_visit_keys(values : Array[VisitKey]) -> Array[VisitKey] {
  let copied : Array[VisitKey] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn copy_call_keys(values : Array[CallKey]) -> Array[CallKey] {
  let copied : Array[CallKey] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn combine_effects(left : LexerEffects, right : LexerEffects) -> LexerEffects {
  let commands = copy_command_specs(left.commands)
  for command in right.commands {
    commands.push(command)
  }
  let action_texts = copy_strings(left.action_texts)
  for text in right.action_texts {
    action_texts.push(text)
  }
  let action_labels = copy_strings(left.action_labels)
  for label in right.action_labels {
    action_labels.push(label)
  }
  { commands, action_texts, action_labels }
}

///|
fn effect_with_command(
  effects : LexerEffects,
  command : @antlr.LexerCommandSpec,
) -> LexerEffects {
  combine_effects(effects, {
    commands: [command],
    action_texts: [],
    action_labels: [],
  })
}

///|
fn effect_with_action(
  effects : LexerEffects,
  text : String,
  label : String,
) -> LexerEffects {
  combine_effects(effects, {
    commands: [],
    action_texts: [text],
    action_labels: [label],
  })
}

///|
fn prepend_config(
  config : LexerAtnConfig,
  configs : Array[LexerAtnConfig],
) -> Array[LexerAtnConfig] {
  let values : Array[LexerAtnConfig] = [config]
  for item in configs {
    values.push(item)
  }
  values
}

///|
fn combine_configs(
  left : Array[LexerAtnConfig],
  right : Array[LexerAtnConfig],
) -> Array[LexerAtnConfig] {
  let configs = copy_configs(left)
  for item in right {
    configs.push(item)
  }
  configs
}

///|
fn state_config(state : @antlr.AtnState, stream : CharStream) -> LexerAtnConfig {
  { state_id: state.id, input_offset: stream.offset(), rule_id: state.rule_id }
}

///|
fn decorate_match(
  state : @antlr.AtnState,
  stream : CharStream,
  prefix_effects : LexerEffects,
  suffix : RuleSuffixMatch,
) -> RuleSuffixMatch {
  {
    end_stream: suffix.end_stream,
    effects: combine_effects(prefix_effects, suffix.effects),
    configs: prepend_config(state_config(state, stream), suffix.configs),
  }
}

///|
fn lookup_cached_suffix(
  memo : Array[CachedSuffixEntry],
  mode_name : String,
  state_id : Int,
  input_offset : Int,
) -> (Bool, RuleSuffixMatch?) {
  for entry in memo {
    if entry.mode_name == mode_name &&
      entry.state_id == state_id &&
      entry.input_offset == input_offset {
      return (true, entry.result)
    }
  }
  (false, None)
}

///|
fn record_cached_suffix(
  memo : Array[CachedSuffixEntry],
  mode_name : String,
  state_id : Int,
  input_offset : Int,
  result : RuleSuffixMatch?,
) -> Unit {
  memo.push({ mode_name, state_id, input_offset, result })
}

///|
fn visit_contains(
  values : Array[VisitKey],
  state_id : Int,
  input_offset : Int,
) -> Bool {
  for value in values {
    if value.state_id == state_id && value.input_offset == input_offset {
      return true
    }
  }
  false
}

///|
fn extend_visit_path(
  values : Array[VisitKey],
  state_id : Int,
  input_offset : Int,
) -> Array[VisitKey] {
  let copied = copy_visit_keys(values)
  copied.push({ state_id, input_offset })
  copied
}

///|
fn call_contains(
  values : Array[CallKey],
  rule_id : Int,
  input_offset : Int,
) -> Bool {
  for value in values {
    if value.rule_id == rule_id && value.input_offset == input_offset {
      return true
    }
  }
  false
}

///|
fn extend_call_path(
  values : Array[CallKey],
  rule_id : Int,
  input_offset : Int,
) -> Array[CallKey] {
  let copied = copy_call_keys(values)
  copied.push({ rule_id, input_offset })
  copied
}

///|
fn current_mode_symbol_or_abort(
  atn : @antlr.GrammarAtn,
  mode_name : String,
) -> @antlr.GrammarModeSymbol {
  match atn.find_mode(mode_name) {
    Some(mode_symbol) => mode_symbol
    None => abort("expected lexer mode `" + mode_name + "`")
  }
}

///|
fn default_mode_symbol_or_abort(
  atn : @antlr.GrammarAtn,
) -> @antlr.GrammarModeSymbol {
  match atn.find_mode("DEFAULT_MODE") {
    Some(mode_symbol) => mode_symbol
    None =>
      if atn.public_modes.length() == 0 {
        abort("lexer runtime requires at least one lexer mode")
      } else {
        atn.public_modes[0]
      }
  }
}

///|
fn default_channel_symbol_or_abort(
  atn : @antlr.GrammarAtn,
) -> @antlr.GrammarChannelSymbol {
  match atn.find_channel("DEFAULT_TOKEN_CHANNEL") {
    Some(channel) => channel
    None =>
      if atn.public_channels.length() == 0 {
        abort("lexer runtime requires at least one channel")
      } else {
        atn.public_channels[0]
      }
  }
}

///|
fn public_rule_by_id_or_abort(
  atn : @antlr.GrammarAtn,
  rule_id : Int,
) -> @antlr.GrammarRuleSymbol {
  for rule in atn.public_rules {
    if rule.rule_id == rule_id {
      return rule
    }
  }
  abort("expected public rule metadata for rule id " + rule_id.to_string())
}

///|
fn stack_without_last(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  if values.length() == 0 {
    return copied
  }
  for index = 0; index < values.length() - 1; index = index + 1 {
    copied.push(values[index])
  }
  copied
}

///|
fn stack_last(values : Array[String]) -> String? {
  if values.length() == 0 {
    None
  } else {
    Some(values[values.length() - 1])
  }
}

///|
fn command_arg_value(args : String?) -> String? {
  match args {
    Some(raw_args) => {
      let trimmed = raw_args.trim().to_string()
      if trimmed == "" {
        None
      } else if trimmed.has_prefix("(") &&
        trimmed.has_suffix(")") &&
        trimmed.length() >= 2 {
        let inner = trimmed[1:trimmed.length() - 1]
          .to_string()
          .trim()
          .to_string()
        if inner == "" {
          None
        } else {
          Some(inner)
        }
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn apply_commands(
  commands : Array[@antlr.LexerCommandSpec],
  current_mode_name : String,
  current_mode_stack : Array[String],
) -> CommandOutcome {
  let mut skip = false
  let mut more = false
  let mut token_name : String? = None
  let mut channel_name : String? = None
  let mut next_mode_name = current_mode_name
  let mut next_mode_stack = copy_strings(current_mode_stack)
  for command in commands {
    if command.name == "skip" {
      skip = true
    } else if command.name == "more" {
      more = true
    } else if command.name == "type" {
      token_name = command_arg_value(command.args)
    } else if command.name == "channel" {
      channel_name = command_arg_value(command.args)
    } else if command.name == "pushMode" {
      match command_arg_value(command.args) {
        Some(mode_name) => {
          next_mode_stack.push(next_mode_name)
          next_mode_name = mode_name
        }
        None => ()
      }
    } else if command.name == "popMode" {
      match stack_last(next_mode_stack) {
        Some(mode_name) => {
          next_mode_name = mode_name
          next_mode_stack = stack_without_last(next_mode_stack)
        }
        None => ()
      }
    }
  }
  { skip, more, token_name, channel_name, next_mode_name, next_mode_stack }
}

///|
fn append_action_invocations(
  action_log : Array[LexerActionInvocation],
  effects : LexerEffects,
  rule_name : String,
  span : @antlr.SourceSpan,
) -> Unit {
  for index = 0; index < effects.action_texts.length(); index = index + 1 {
    action_log.push({
      action_text: effects.action_texts[index],
      label: effects.action_labels[index],
      rule_name,
      span,
    })
  }
}

///|
fn append_runtime_diagnostic(
  diagnostics : Array[@antlr.Diagnostic],
  message : String,
  pos : @antlr.SourcePos,
) -> Unit {
  diagnostics.push(
    @antlr.Diagnostic::error(message, @antlr.SourceSpan::point(pos)),
  )
}

///|
fn unescape_antlr_literal(raw : String) -> String {
  if !raw.has_prefix("'") || !raw.has_suffix("'") || raw.length() < 2 {
    return raw
  }
  let mut index = 1
  let end = raw.length() - 1
  let mut text = ""
  while index < end {
    let c = raw.get_char(index).unwrap()
    if c == '\\' && index + 1 < end {
      let escaped = raw.get_char(index + 1).unwrap()
      if escaped == 'n' {
        text = text + "\n"
      } else if escaped == 'r' {
        text = text + "\r"
      } else if escaped == 't' {
        text = text + "\t"
      } else {
        text = text + raw[index + 1:index + 2].to_string()
      }
      index = index + 2
    } else {
      text = text + raw[index:index + 1].to_string()
      index = index + 1
    }
  }
  text
}

///|
fn read_charset_char(raw : String, index : Int) -> (Char, Int) {
  let c = raw.get_char(index).unwrap()
  if c != '\\' || index + 1 >= raw.length() {
    return (c, index + 1)
  }
  let escaped = raw.get_char(index + 1).unwrap()
  if escaped == 'n' {
    ('\n', index + 2)
  } else if escaped == 'r' {
    ('\r', index + 2)
  } else if escaped == 't' {
    ('\t', index + 2)
  } else {
    (escaped, index + 2)
  }
}

///|
fn charset_matches(raw : String, wanted : Char) -> Bool {
  if !raw.has_prefix("[") || !raw.has_suffix("]") || raw.length() < 2 {
    return false
  }
  let mut index = 1
  let end = raw.length() - 1
  while index < end {
    let (start_char, next_index) = read_charset_char(raw, index)
    if next_index < end &&
      raw.get_char(next_index).unwrap() == '-' &&
      next_index + 1 < end {
      let (end_char, after_end) = read_charset_char(raw, next_index + 1)
      if start_char <= wanted && wanted <= end_char {
        return true
      }
      index = after_end
    } else {
      if start_char == wanted {
        return true
      }
      index = next_index
    }
  }
  false
}

///|
fn range_matches(raw : String, wanted : Char) -> Bool {
  let parts = raw.split("..").map(part => part.trim().to_string()).to_array()
  if parts.length() != 2 {
    return false
  }
  let left = unescape_antlr_literal(parts[0])
  let right = unescape_antlr_literal(parts[1])
  if left.length() != 1 || right.length() != 1 {
    return false
  }
  let start_char = left.get_char(0).unwrap()
  let end_char = right.get_char(0).unwrap()
  start_char <= wanted && wanted <= end_char
}

///|
fn simple_label_matches(label : String, wanted : Char) -> Bool {
  if label == "." {
    return true
  }
  if label.has_prefix("[") && label.has_suffix("]") {
    return charset_matches(label, wanted)
  }
  if range_matches(label, wanted) {
    return true
  }
  if label.has_prefix("'") && label.has_suffix("'") {
    let text = unescape_antlr_literal(label)
    return text.length() == 1 && text.get_char(0).unwrap() == wanted
  }
  false
}

///|
fn match_string_literal(
  stream : CharStream,
  raw_literal : String,
) -> CharStream? {
  let text = unescape_antlr_literal(raw_literal)
  if text == "" {
    return Some(stream)
  }
  if stream.starts_with(text) {
    Some(stream.advance_by(text.length()))
  } else {
    None
  }
}

///|
fn match_single_char_by_label(
  stream : CharStream,
  labels : Array[String],
  negated : Bool,
) -> CharStream? {
  if stream.is_eof() {
    return None
  }
  let c = stream.peek_char().unwrap()
  let mut matched = false
  for label in labels {
    if simple_label_matches(label, c) {
      matched = true
      break
    }
  }
  if (matched && !negated) || (!matched && negated) {
    Some(stream.advance())
  } else {
    None
  }
}

///|
fn match_single_char_transition(
  stream : CharStream,
  labels : Array[String],
  default_negated : Bool,
  transition_negated : Bool,
) -> CharStream? {
  match_single_char_by_label(
    stream,
    labels,
    default_negated != transition_negated,
  )
}

///|
fn token_ref_rule_graph(
  atn : @antlr.GrammarAtn,
  rule_name : String,
) -> @antlr.AtnRuleGraph? {
  match atn.find_rule(rule_name) {
    Some(rule_graph) =>
      if @antlr.grammar_rule_kind_name(rule_graph.kind) == "lexer" {
        Some(rule_graph)
      } else {
        None
      }
    None => None
  }
}

///|
fn state_is_nongreedy_choice(state : @antlr.AtnState) -> Bool {
  let kind_name = @antlr.atn_state_kind_name(state.kind)
  state.greedy == false &&
  (
    kind_name == "star-block-start" ||
    kind_name == "loop-back" ||
    kind_name == "loop-entry"
  )
}

///|
fn choose_better_suffix(
  state : @antlr.AtnState,
  current : RuleSuffixMatch?,
  candidate : RuleSuffixMatch?,
) -> RuleSuffixMatch? {
  match candidate {
    None => current
    Some(candidate_match) =>
      match current {
        None => Some(candidate_match)
        Some(current_match) => {
          let candidate_offset = candidate_match.end_stream.offset()
          let current_offset = current_match.end_stream.offset()
          if state_is_nongreedy_choice(state) {
            if candidate_offset < current_offset {
              Some(candidate_match)
            } else {
              current
            }
          } else if candidate_offset > current_offset {
            Some(candidate_match)
          } else {
            current
          }
        }
      }
  }
}

///|
fn choose_better_candidate(
  current : RuleCandidate?,
  candidate : RuleCandidate?,
) -> RuleCandidate? {
  match candidate {
    None => current
    Some(candidate_value) =>
      match current {
        None => Some(candidate_value)
        Some(current_value) => {
          let candidate_length = candidate_value.matched.end_stream.offset()
          let current_length = current_value.matched.end_stream.offset()
          if candidate_length > current_length {
            Some(candidate_value)
          } else if candidate_length < current_length {
            current
          } else if candidate_value.implicit && !current_value.implicit {
            Some(candidate_value)
          } else if !candidate_value.implicit && current_value.implicit {
            current
          } else if candidate_value.priority < current_value.priority {
            Some(candidate_value)
          } else {
            current
          }
        }
      }
  }
}

///|
fn memo_to_dfa_entries(
  atn : @antlr.GrammarAtn,
  values : Array[CachedSuffixEntry],
) -> Array[LexerDfaEntry] {
  let entries : Array[LexerDfaEntry] = []
  for value in values {
    match value.result {
      Some(result) => {
        let config_signature = make_lexer_config_set(result.configs).signature()
        let matched_rule_name = match atn.state(value.state_id) {
          Some(state) => state.rule_name
          None => None
        }
        entries.push({
          mode_name: value.mode_name,
          state_id: value.state_id,
          input_offset: value.input_offset,
          matched_rule_name,
          matched_length: result.end_stream.offset() - value.input_offset,
          config_signature,
        })
      }
      None => ()
    }
  }
  entries
}

///|
fn match_called_rule(
  atn : @antlr.GrammarAtn,
  mode_name : String,
  called_rule_id : Int,
  stream : CharStream,
  hooks : LexerHostHooks,
  memo : Array[CachedSuffixEntry],
  call_path : Array[CallKey],
) -> RuleSuffixMatch? {
  if call_contains(call_path, called_rule_id, stream.offset()) {
    return None
  }
  let rule_graph = match atn.rule_by_id(called_rule_id) {
    Some(rule) => rule
    None => return None
  }
  best_match_from_state(
    atn,
    mode_name,
    rule_graph.stop_state_id,
    rule_graph.start_state_id,
    stream,
    hooks,
    memo,
    [],
    extend_call_path(call_path, called_rule_id, stream.offset()),
  )
}

///|
fn best_match_from_state(
  atn : @antlr.GrammarAtn,
  mode_name : String,
  stop_state_id : Int,
  state_id : Int,
  stream : CharStream,
  hooks : LexerHostHooks,
  memo : Array[CachedSuffixEntry],
  visit_path : Array[VisitKey],
  call_path : Array[CallKey],
) -> RuleSuffixMatch? {
  if state_id == stop_state_id {
    let state = match atn.state(state_id) {
      Some(value) => value
      None => abort("expected stop state `" + state_id.to_string() + "`")
    }
    return Some({
      end_stream: stream,
      effects: empty_effects(),
      configs: [state_config(state, stream)],
    })
  }
  match lookup_cached_suffix(memo, mode_name, state_id, stream.offset()) {
    (true, result) => return result
    _ => ()
  }
  if visit_contains(visit_path, state_id, stream.offset()) {
    return None
  }
  let state = match atn.state(state_id) {
    Some(value) => value
    None => abort("expected ATN state `" + state_id.to_string() + "`")
  }
  let next_visit_path = extend_visit_path(visit_path, state_id, stream.offset())
  let mut best : RuleSuffixMatch? = None
  for transition in atn.outgoing_transitions(state_id) {
    let candidate = match transition.kind {
      @antlr.EpsilonTransition =>
        match
          best_match_from_state(
            atn,
            mode_name,
            stop_state_id,
            transition.target_state_id,
            stream,
            hooks,
            memo,
            next_visit_path,
            call_path,
          ) {
          Some(suffix) =>
            Some(decorate_match(state, stream, empty_effects(), suffix))
          None => None
        }
      @antlr.ActionTransition(text) =>
        match
          best_match_from_state(
            atn,
            mode_name,
            stop_state_id,
            transition.target_state_id,
            stream,
            hooks,
            memo,
            next_visit_path,
            call_path,
          ) {
          Some(suffix) =>
            Some(
              decorate_match(
                state,
                stream,
                effect_with_action(
                  empty_effects(),
                  text,
                  action_binding_label(hooks, text),
                ),
                suffix,
              ),
            )
          None => None
        }
      @antlr.PredicateTransition(text, _) =>
        if predicate_binding_value(hooks, text) {
          match
            best_match_from_state(
              atn,
              mode_name,
              stop_state_id,
              transition.target_state_id,
              stream,
              hooks,
              memo,
              next_visit_path,
              call_path,
            ) {
            Some(suffix) =>
              Some(decorate_match(state, stream, empty_effects(), suffix))
            None => None
          }
        } else {
          None
        }
      @antlr.PrecedenceTransition(_, _) => None
      @antlr.LexerCommandTransition(command) =>
        match
          best_match_from_state(
            atn,
            mode_name,
            stop_state_id,
            transition.target_state_id,
            stream,
            hooks,
            memo,
            next_visit_path,
            call_path,
          ) {
          Some(suffix) =>
            Some(
              decorate_match(
                state,
                stream,
                effect_with_command(empty_effects(), command),
                suffix,
              ),
            )
          None => None
        }
      @antlr.RuleReferenceTransition(rule_call) => {
        let called_rule_id = match rule_call.called_rule_id {
          Some(value) => value
          None =>
            match atn.find_rule(rule_call.rule_ref.name) {
              Some(rule_graph) => rule_graph.rule_id
              None => return None
            }
        }
        match
          match_called_rule(
            atn, mode_name, called_rule_id, stream, hooks, memo, call_path,
          ) {
          Some(called_match) => {
            let follow_state_id = match rule_call.follow_state_id {
              Some(value) => value
              None => transition.target_state_id
            }
            match
              best_match_from_state(
                atn,
                mode_name,
                stop_state_id,
                follow_state_id,
                called_match.end_stream,
                hooks,
                memo,
                next_visit_path,
                call_path,
              ) {
              Some(follow_match) =>
                Some(
                  decorate_match(state, stream, empty_effects(), {
                    end_stream: follow_match.end_stream,
                    effects: combine_effects(
                      called_match.effects,
                      follow_match.effects,
                    ),
                    configs: combine_configs(
                      called_match.configs,
                      follow_match.configs,
                    ),
                  }),
                )
              None => None
            }
          }
          None => None
        }
      }
      @antlr.TokenReferenceTransition(name) =>
        match token_ref_rule_graph(atn, name) {
          Some(rule_graph) =>
            match
              match_called_rule(
                atn,
                mode_name,
                rule_graph.rule_id,
                stream,
                hooks,
                memo,
                call_path,
              ) {
              Some(called_match) =>
                match
                  best_match_from_state(
                    atn,
                    mode_name,
                    stop_state_id,
                    transition.target_state_id,
                    called_match.end_stream,
                    hooks,
                    memo,
                    next_visit_path,
                    call_path,
                  ) {
                  Some(follow_match) =>
                    Some(
                      decorate_match(state, stream, empty_effects(), {
                        end_stream: follow_match.end_stream,
                        effects: combine_effects(
                          called_match.effects,
                          follow_match.effects,
                        ),
                        configs: combine_configs(
                          called_match.configs,
                          follow_match.configs,
                        ),
                      }),
                    )
                  None => None
                }
              None => None
            }
          None => None
        }
      @antlr.StringLiteralTransition(text) =>
        if transition.negated {
          match match_single_char_transition(stream, [text], false, true) {
            Some(next_stream) =>
              match
                best_match_from_state(
                  atn,
                  mode_name,
                  stop_state_id,
                  transition.target_state_id,
                  next_stream,
                  hooks,
                  memo,
                  next_visit_path,
                  call_path,
                ) {
                Some(suffix) =>
                  Some(decorate_match(state, stream, empty_effects(), suffix))
                None => None
              }
            None => None
          }
        } else {
          match match_string_literal(stream, text) {
            Some(next_stream) =>
              match
                best_match_from_state(
                  atn,
                  mode_name,
                  stop_state_id,
                  transition.target_state_id,
                  next_stream,
                  hooks,
                  memo,
                  next_visit_path,
                  call_path,
                ) {
                Some(suffix) =>
                  Some(decorate_match(state, stream, empty_effects(), suffix))
                None => None
              }
            None => None
          }
        }
      @antlr.RangeTransition(text) =>
        match
          match_single_char_transition(
            stream,
            [text],
            false,
            transition.negated,
          ) {
          Some(next_stream) =>
            match
              best_match_from_state(
                atn,
                mode_name,
                stop_state_id,
                transition.target_state_id,
                next_stream,
                hooks,
                memo,
                next_visit_path,
                call_path,
              ) {
              Some(suffix) =>
                Some(decorate_match(state, stream, empty_effects(), suffix))
              None => None
            }
          None => None
        }
      @antlr.CharSetTransition(text) =>
        match
          match_single_char_transition(
            stream,
            [text],
            false,
            transition.negated,
          ) {
          Some(next_stream) =>
            match
              best_match_from_state(
                atn,
                mode_name,
                stop_state_id,
                transition.target_state_id,
                next_stream,
                hooks,
                memo,
                next_visit_path,
                call_path,
              ) {
              Some(suffix) =>
                Some(decorate_match(state, stream, empty_effects(), suffix))
              None => None
            }
          None => None
        }
      @antlr.SetTransition(labels) =>
        match
          match_single_char_transition(
            stream,
            labels,
            false,
            transition.negated,
          ) {
          Some(next_stream) =>
            match
              best_match_from_state(
                atn,
                mode_name,
                stop_state_id,
                transition.target_state_id,
                next_stream,
                hooks,
                memo,
                next_visit_path,
                call_path,
              ) {
              Some(suffix) =>
                Some(decorate_match(state, stream, empty_effects(), suffix))
              None => None
            }
          None => None
        }
      @antlr.NotSetTransition(labels) =>
        match
          match_single_char_transition(stream, labels, true, transition.negated) {
          Some(next_stream) =>
            match
              best_match_from_state(
                atn,
                mode_name,
                stop_state_id,
                transition.target_state_id,
                next_stream,
                hooks,
                memo,
                next_visit_path,
                call_path,
              ) {
              Some(suffix) =>
                Some(decorate_match(state, stream, empty_effects(), suffix))
              None => None
            }
          None => None
        }
      @antlr.WildcardTransition =>
        if stream.is_eof() || transition.negated {
          None
        } else {
          match
            best_match_from_state(
              atn,
              mode_name,
              stop_state_id,
              transition.target_state_id,
              stream.advance(),
              hooks,
              memo,
              next_visit_path,
              call_path,
            ) {
            Some(suffix) =>
              Some(decorate_match(state, stream, empty_effects(), suffix))
            None => None
          }
        }
    }
    best = choose_better_suffix(state, best, candidate)
  }
  record_cached_suffix(memo, mode_name, state_id, stream.offset(), best)
  best
}

///|
fn top_level_rule_candidate(
  atn : @antlr.GrammarAtn,
  mode_name : String,
  stream : CharStream,
  hooks : LexerHostHooks,
  rule_id : Int,
) -> ModeMatchAttempt {
  let rule_symbol = public_rule_by_id_or_abort(atn, rule_id)
  if rule_symbol.is_fragment {
    return { candidate: None, dfa_entries: [] }
  }
  let rule_graph = match atn.rule_by_id(rule_id) {
    Some(rule) => rule
    None => return { candidate: None, dfa_entries: [] }
  }
  let memo : Array[CachedSuffixEntry] = []
  let matched = best_match_from_state(
    atn,
    mode_name,
    rule_graph.stop_state_id,
    rule_graph.start_state_id,
    stream,
    hooks,
    memo,
    [],
    [],
  )
  let dfa_entries = memo_to_dfa_entries(atn, memo)
  match matched {
    Some(result) =>
      if result.end_stream.offset() > stream.offset() {
        {
          candidate: Some({
            rule_name: rule_graph.rule_name,
            emitted_token_name: rule_graph.rule_name,
            priority: rule_id,
            implicit: false,
            matched: result,
          }),
          dfa_entries,
        }
      } else {
        { candidate: None, dfa_entries }
      }
    None => { candidate: None, dfa_entries }
  }
}

///|
fn implicit_literal_candidate(
  stream : CharStream,
  token : @antlr.GrammarTokenSymbol,
) -> RuleCandidate? {
  match token.literal_name {
    Some(raw_literal) =>
      match match_string_literal(stream, raw_literal) {
        Some(next_stream) =>
          if next_stream.offset() > stream.offset() {
            Some({
              rule_name: token.name,
              emitted_token_name: token.name,
              priority: token.token_id,
              implicit: true,
              matched: {
                end_stream: next_stream,
                effects: empty_effects(),
                configs: [],
              },
            })
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
fn best_match_for_mode(
  atn : @antlr.GrammarAtn,
  mode_name : String,
  stream : CharStream,
  hooks : LexerHostHooks,
) -> ModeMatchAttempt {
  let dfa_entries : Array[LexerDfaEntry] = []
  let mut best : RuleCandidate? = None
  match atn.mode_start(mode_name) {
    Some(mode_start) =>
      for rule_id in mode_start.rule_ids {
        let attempt = top_level_rule_candidate(
          atn, mode_name, stream, hooks, rule_id,
        )
        for entry in attempt.dfa_entries {
          dfa_entries.push(entry)
        }
        best = choose_better_candidate(best, attempt.candidate)
      }
    None => ()
  }
  if mode_name == "DEFAULT_MODE" {
    for token in atn.public_tokens {
      if token.implicit {
        best = choose_better_candidate(
          best,
          implicit_literal_candidate(stream, token),
        )
      }
    }
  }
  { candidate: best, dfa_entries }
}

///|
fn token_symbol_or_abort(
  atn : @antlr.GrammarAtn,
  token_name : String,
) -> @antlr.GrammarTokenSymbol {
  match atn.find_token(token_name) {
    Some(token) => token
    None => abort("expected token metadata for `" + token_name + "`")
  }
}

///|
fn channel_symbol_or_abort(
  atn : @antlr.GrammarAtn,
  channel_name : String,
) -> @antlr.GrammarChannelSymbol {
  match atn.find_channel(channel_name) {
    Some(channel) => channel
    None => abort("expected channel metadata for `" + channel_name + "`")
  }
}

///|
fn pending_token_or_start(
  pending : PendingToken?,
  stream : CharStream,
  mode_symbol : @antlr.GrammarModeSymbol,
) -> PendingToken {
  match pending {
    Some(value) => value
    None =>
      {
        start_offset: stream.offset(),
        start_pos: stream.position(),
        start_mode_id: mode_symbol.mode_id,
        start_mode_name: mode_symbol.name,
        token_name: None,
        channel_name: None,
      }
  }
}

///|
/// Lex one input string directly from the stable Phase 1 ATN contract.
///
/// Example:
/// let result = lex_with_atn(atn, "abc", LexerHostHooks::empty())
/// inspect(result.tokens.length() > 0, content="true")
///
/// Notes:
/// - The runtime records EOF as a final token with `is_eof = true`.
/// - Unbound predicates evaluate to `false`, which can surface as lexer diagnostics.
pub fn lex_with_atn(
  atn : @antlr.GrammarAtn,
  source : String,
  hooks : LexerHostHooks,
) -> LexerRunResult {
  let mut stream = CharStream::new(source)
  let initial_mode = default_mode_symbol_or_abort(atn)
  let mut current_mode_name = initial_mode.name
  let mut current_mode_stack : Array[String] = []
  let tokens : Array[LexerToken] = []
  let diagnostics : Array[@antlr.Diagnostic] = []
  let action_log : Array[LexerActionInvocation] = []
  let mut pending : PendingToken? = None
  let mut token_index = 0
  let mut dfa = empty_lexer_dfa()

  while !stream.is_eof() {
    let current_mode = current_mode_symbol_or_abort(atn, current_mode_name)
    let attempt = best_match_for_mode(atn, current_mode_name, stream, hooks)
    dfa = append_dfa_entries(dfa, attempt.dfa_entries)
    match attempt.candidate {
      Some(candidate) => {
        let start_token = pending_token_or_start(pending, stream, current_mode)
        let span = @antlr.SourceSpan::new(
          start_token.start_pos,
          candidate.matched.end_stream.position(),
        )
        append_action_invocations(
          action_log,
          candidate.matched.effects,
          candidate.rule_name,
          span,
        )
        let outcome = apply_commands(
          candidate.matched.effects.commands,
          current_mode_name,
          current_mode_stack,
        )
        if outcome.more {
          pending = Some({
            start_offset: start_token.start_offset,
            start_pos: start_token.start_pos,
            start_mode_id: start_token.start_mode_id,
            start_mode_name: start_token.start_mode_name,
            token_name: match outcome.token_name {
              Some(token_name) => Some(token_name)
              None => start_token.token_name
            },
            channel_name: match outcome.channel_name {
              Some(channel_name) => Some(channel_name)
              None => start_token.channel_name
            },
          })
          stream = candidate.matched.end_stream
          current_mode_name = outcome.next_mode_name
          current_mode_stack = outcome.next_mode_stack
        } else {
          let emitted_token_name = match outcome.token_name {
            Some(token_name) => token_name
            None =>
              match start_token.token_name {
                Some(token_name) => token_name
                None => candidate.emitted_token_name
              }
          }
          let token_symbol = token_symbol_or_abort(atn, emitted_token_name)
          let channel_symbol = match outcome.channel_name {
            Some(channel_name) => channel_symbol_or_abort(atn, channel_name)
            None =>
              match start_token.channel_name {
                Some(channel_name) => channel_symbol_or_abort(atn, channel_name)
                None => default_channel_symbol_or_abort(atn)
              }
          }
          let end_mode = current_mode_symbol_or_abort(atn, current_mode_name)
          let text = stream.slice(
            start_token.start_offset,
            candidate.matched.end_stream.offset(),
          )
          if !outcome.skip {
            tokens.push({
              token_index,
              token_id: token_symbol.token_id,
              token_name: token_symbol.name,
              text,
              channel_id: channel_symbol.channel_id,
              channel_name: channel_symbol.name,
              start_mode_id: start_token.start_mode_id,
              start_mode_name: start_token.start_mode_name,
              end_mode_id: end_mode.mode_id,
              end_mode_name: end_mode.name,
              span,
              implicit: token_symbol.implicit,
              is_eof: false,
            })
            token_index = token_index + 1
          }
          pending = None
          stream = candidate.matched.end_stream
          current_mode_name = outcome.next_mode_name
          current_mode_stack = outcome.next_mode_stack
        }
      }
      None => {
        let pos = stream.position()
        append_runtime_diagnostic(
          diagnostics,
          "no viable lexer alternative in mode `" + current_mode_name + "`",
          pos,
        )
        pending = None
        stream = stream.advance()
      }
    }
  }

  match pending {
    Some(value) =>
      append_runtime_diagnostic(
        diagnostics,
        "unterminated token after `more` command",
        value.start_pos,
      )
    None => ()
  }

  let eof_mode = current_mode_symbol_or_abort(atn, current_mode_name)
  let eof_channel = default_channel_symbol_or_abort(atn)
  let eof_pos = stream.position()
  tokens.push({
    token_index,
    token_id: -1,
    token_name: "EOF",
    text: "",
    channel_id: eof_channel.channel_id,
    channel_name: eof_channel.name,
    start_mode_id: eof_mode.mode_id,
    start_mode_name: eof_mode.name,
    end_mode_id: eof_mode.mode_id,
    end_mode_name: eof_mode.name,
    span: @antlr.SourceSpan::point(eof_pos),
    implicit: false,
    is_eof: true,
  })

  { tokens, diagnostics, action_log, dfa }
}

///|
/// Lex one input string from the serialized Phase 1 ATN format.
///
/// Example:
/// let result = lex_serialized_atn(serialized, "abc", LexerHostHooks::empty())
/// inspect(result is Ok(_), content="true")
///
/// Notes:
/// - This is the entry point used to prove the runtime can start from deserialized ATN data alone.
pub fn lex_serialized_atn(
  serialized_atn : String,
  source : String,
  hooks : LexerHostHooks,
) -> Result[LexerRunResult, String] {
  match @antlr.deserialize_grammar_atn(serialized_atn) {
    Ok(atn) => Ok(lex_with_atn(atn, source, hooks))
    Err(error) => Err(error)
  }
}
