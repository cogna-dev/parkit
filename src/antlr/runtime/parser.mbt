///|
priv struct ParserMatch {
  end_stream : ParserTokenStream
  events : Array[ParserEvent]
  recovery_events : Array[ParserRecoveryEvent]
  diagnostics : Array[@antlr.Diagnostic]
  dfa_entries : Array[ParserDfaEntry]
  configs : Array[ParserAtnConfig]
  full_context_fallbacks : Int
  ambiguities : Int
}

///|
priv struct ParserRuleMemoEntry {
  rule_id : Int
  input_offset : Int
  precedence : Int
  depth : Int
  context_id : Int
  result : ParserMatch?
}

///|
priv struct ParserVisitKey {
  state_id : Int
  input_offset : Int
  precedence : Int
  depth : Int
  context_id : Int
}

///|
priv struct ParserCallKey {
  rule_id : Int
  input_offset : Int
  precedence : Int
}

///|
fn parser_copy_events(values : Array[ParserEvent]) -> Array[ParserEvent] {
  let copied : Array[ParserEvent] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_copy_recovery_events(
  values : Array[ParserRecoveryEvent],
) -> Array[ParserRecoveryEvent] {
  let copied : Array[ParserRecoveryEvent] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_copy_diagnostics(
  values : Array[@antlr.Diagnostic],
) -> Array[@antlr.Diagnostic] {
  let copied : Array[@antlr.Diagnostic] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_copy_dfa_entries_for_match(
  values : Array[ParserDfaEntry],
) -> Array[ParserDfaEntry] {
  let copied : Array[ParserDfaEntry] = []
  for value in values {
    copied.push({
      decision_id: value.decision_id,
      input_offset: value.input_offset,
      lookahead_token_name: value.lookahead_token_name,
      chosen_alternative: value.chosen_alternative,
      ambiguous_alternatives: parser_copy_dfa_alt_values(
        value.ambiguous_alternatives,
      ),
      used_full_context: value.used_full_context,
      config_signature: value.config_signature,
    })
  }
  copied
}

///|
fn parser_copy_match(match_value : ParserMatch) -> ParserMatch {
  {
    end_stream: match_value.end_stream,
    events: parser_copy_events(match_value.events),
    recovery_events: parser_copy_recovery_events(match_value.recovery_events),
    diagnostics: parser_copy_diagnostics(match_value.diagnostics),
    dfa_entries: parser_copy_dfa_entries_for_match(match_value.dfa_entries),
    configs: parser_copy_configs(match_value.configs),
    full_context_fallbacks: match_value.full_context_fallbacks,
    ambiguities: match_value.ambiguities,
  }
}

///|
fn parser_concat_events(
  left : Array[ParserEvent],
  right : Array[ParserEvent],
) -> Array[ParserEvent] {
  let values = parser_copy_events(left)
  for item in right {
    values.push(item)
  }
  values
}

///|
fn parser_concat_recovery_events(
  left : Array[ParserRecoveryEvent],
  right : Array[ParserRecoveryEvent],
) -> Array[ParserRecoveryEvent] {
  let values = parser_copy_recovery_events(left)
  for item in right {
    values.push(item)
  }
  values
}

///|
fn parser_concat_diagnostics(
  left : Array[@antlr.Diagnostic],
  right : Array[@antlr.Diagnostic],
) -> Array[@antlr.Diagnostic] {
  let values = parser_copy_diagnostics(left)
  for item in right {
    values.push(item)
  }
  values
}

///|
fn parser_concat_dfa_entries(
  left : Array[ParserDfaEntry],
  right : Array[ParserDfaEntry],
) -> Array[ParserDfaEntry] {
  let values = parser_copy_dfa_entries_for_match(left)
  for item in right {
    values.push(item)
  }
  values
}

///|
fn parser_concat_configs(
  left : Array[ParserAtnConfig],
  right : Array[ParserAtnConfig],
) -> Array[ParserAtnConfig] {
  let values = parser_copy_configs(left)
  for item in right {
    values.push(item)
  }
  values
}

///|
fn parser_empty_match(stream : ParserTokenStream) -> ParserMatch {
  {
    end_stream: stream,
    events: [],
    recovery_events: [],
    diagnostics: [],
    dfa_entries: [],
    configs: [],
    full_context_fallbacks: 0,
    ambiguities: 0,
  }
}

///|
fn parser_match_with_prefixed_event(
  event : ParserEvent,
  match_value : ParserMatch,
) -> ParserMatch {
  {
    end_stream: match_value.end_stream,
    events: parser_concat_events([event], match_value.events),
    recovery_events: parser_copy_recovery_events(match_value.recovery_events),
    diagnostics: parser_copy_diagnostics(match_value.diagnostics),
    dfa_entries: parser_copy_dfa_entries_for_match(match_value.dfa_entries),
    configs: parser_copy_configs(match_value.configs),
    full_context_fallbacks: match_value.full_context_fallbacks,
    ambiguities: match_value.ambiguities,
  }
}

///|
fn parser_match_with_suffixed_event(
  match_value : ParserMatch,
  event : ParserEvent,
) -> ParserMatch {
  {
    end_stream: match_value.end_stream,
    events: parser_concat_events(match_value.events, [event]),
    recovery_events: parser_copy_recovery_events(match_value.recovery_events),
    diagnostics: parser_copy_diagnostics(match_value.diagnostics),
    dfa_entries: parser_copy_dfa_entries_for_match(match_value.dfa_entries),
    configs: parser_copy_configs(match_value.configs),
    full_context_fallbacks: match_value.full_context_fallbacks,
    ambiguities: match_value.ambiguities,
  }
}

///|
fn parser_match_with_prefixed_config(
  config : ParserAtnConfig,
  match_value : ParserMatch,
) -> ParserMatch {
  {
    end_stream: match_value.end_stream,
    events: parser_copy_events(match_value.events),
    recovery_events: parser_copy_recovery_events(match_value.recovery_events),
    diagnostics: parser_copy_diagnostics(match_value.diagnostics),
    dfa_entries: parser_copy_dfa_entries_for_match(match_value.dfa_entries),
    configs: parser_concat_configs([config], match_value.configs),
    full_context_fallbacks: match_value.full_context_fallbacks,
    ambiguities: match_value.ambiguities,
  }
}

///|
fn parser_combine_matches(
  left : ParserMatch,
  right : ParserMatch,
) -> ParserMatch {
  {
    end_stream: right.end_stream,
    events: parser_concat_events(left.events, right.events),
    recovery_events: parser_concat_recovery_events(
      left.recovery_events,
      right.recovery_events,
    ),
    diagnostics: parser_concat_diagnostics(left.diagnostics, right.diagnostics),
    dfa_entries: parser_concat_dfa_entries(left.dfa_entries, right.dfa_entries),
    configs: parser_concat_configs(left.configs, right.configs),
    full_context_fallbacks: left.full_context_fallbacks +
    right.full_context_fallbacks,
    ambiguities: left.ambiguities + right.ambiguities,
  }
}

///|
fn parser_match_score(match_value : ParserMatch) -> Int {
  match_value.end_stream.visible_offset()
}

///|
fn parser_state_config(
  state : @antlr.AtnState,
  input_offset : Int,
  alternative_index : Int,
  context_id : Int,
  precedence : Int,
) -> ParserAtnConfig {
  {
    state_id: state.id,
    alternative_index,
    input_offset,
    context_id,
    precedence,
  }
}

///|
fn parser_point_span(stream : ParserTokenStream) -> @antlr.SourceSpan {
  @antlr.SourceSpan::point(stream.lt(1).span.start)
}

///|
fn parser_span_between(
  start_stream : ParserTokenStream,
  end_stream : ParserTokenStream,
) -> @antlr.SourceSpan {
  @antlr.SourceSpan::new(
    start_stream.lt(1).span.start,
    end_stream.lt(1).span.start,
  )
}

///|
fn parser_enter_rule_event(
  rule_graph : @antlr.AtnRuleGraph,
  stream : ParserTokenStream,
  depth : Int,
) -> ParserEvent {
  {
    kind: EnterRule,
    rule_id: Some(rule_graph.rule_id),
    rule_name: Some(rule_graph.rule_name),
    alternative_index: None,
    label: None,
    slot_id: None,
    element_index: None,
    token_index: Some(stream.lt(1).token_index),
    token_name: Some(stream.lt(1).token_name),
    text: None,
    message: None,
    visible_offset: stream.visible_offset(),
    depth,
    recovered: false,
    span: parser_point_span(stream),
  }
}

///|
fn parser_exit_rule_event(
  rule_graph : @antlr.AtnRuleGraph,
  start_stream : ParserTokenStream,
  end_stream : ParserTokenStream,
  depth : Int,
  success : Bool,
) -> ParserEvent {
  {
    kind: ExitRule,
    rule_id: Some(rule_graph.rule_id),
    rule_name: Some(rule_graph.rule_name),
    alternative_index: None,
    label: None,
    slot_id: None,
    element_index: None,
    token_index: Some(end_stream.lt(1).token_index),
    token_name: Some(end_stream.lt(1).token_name),
    text: None,
    message: Some(if success { "ok" } else { "fail" }),
    visible_offset: end_stream.visible_offset(),
    depth,
    recovered: !success,
    span: parser_span_between(start_stream, end_stream),
  }
}

///|
fn parser_commit_alternative_event(
  rule_graph : @antlr.AtnRuleGraph,
  alternative_origin : @antlr.NormalizedAlternativeOrigin,
  stream : ParserTokenStream,
  depth : Int,
) -> ParserEvent {
  {
    kind: CommitAlternative,
    rule_id: Some(rule_graph.rule_id),
    rule_name: Some(rule_graph.rule_name),
    alternative_index: Some(alternative_origin.alternative_index),
    label: alternative_origin.label,
    slot_id: None,
    element_index: None,
    token_index: Some(stream.lt(1).token_index),
    token_name: Some(stream.lt(1).token_name),
    text: None,
    message: None,
    visible_offset: stream.visible_offset(),
    depth,
    recovered: false,
    span: parser_point_span(stream),
  }
}

///|
fn parser_consume_token_event(
  rule_graph : @antlr.AtnRuleGraph,
  origin : @antlr.NormalizedOrigin?,
  token : LexerToken,
  stream : ParserTokenStream,
  depth : Int,
  recovered : Bool,
) -> ParserEvent {
  let slot_id = match origin {
    Some(value) =>
      match value.slot {
        Some(slot_origin) => Some(slot_origin.slot_id)
        None => None
      }
    None => None
  }
  let element_index = match origin {
    Some(value) =>
      match value.slot {
        Some(slot_origin) => Some(slot_origin.element_index)
        None => None
      }
    None => None
  }
  let alternative_index = match origin {
    Some(value) =>
      match value.alternative {
        Some(alternative_origin) => Some(alternative_origin.alternative_index)
        None => None
      }
    None => None
  }
  let label = match origin {
    Some(value) =>
      match value.slot {
        Some(slot_origin) =>
          match slot_origin.label {
            Some(element_label) => Some(element_label.name)
            None => None
          }
        None => None
      }
    None => None
  }
  {
    kind: ConsumeToken,
    rule_id: Some(rule_graph.rule_id),
    rule_name: Some(rule_graph.rule_name),
    alternative_index,
    label,
    slot_id,
    element_index,
    token_index: Some(token.token_index),
    token_name: Some(token.token_name),
    text: Some(token.text),
    message: None,
    visible_offset: stream.visible_offset(),
    depth,
    recovered,
    span: token.span,
  }
}

///|
fn parser_action_event(
  rule_graph : @antlr.AtnRuleGraph,
  text : String,
  label : String,
  stream : ParserTokenStream,
  depth : Int,
) -> ParserEvent {
  {
    kind: Action,
    rule_id: Some(rule_graph.rule_id),
    rule_name: Some(rule_graph.rule_name),
    alternative_index: None,
    label: Some(label),
    slot_id: None,
    element_index: None,
    token_index: Some(stream.lt(1).token_index),
    token_name: Some(stream.lt(1).token_name),
    text: Some(text),
    message: None,
    visible_offset: stream.visible_offset(),
    depth,
    recovered: false,
    span: parser_point_span(stream),
  }
}

///|
fn parser_recovery_trace_event(
  kind : ParserRecoveryKind,
  token : LexerToken,
  message : String,
  stream : ParserTokenStream,
  depth : Int,
) -> ParserEvent {
  {
    kind: Recovery,
    rule_id: None,
    rule_name: None,
    alternative_index: None,
    label: Some(parser_recovery_kind_name(kind)),
    slot_id: None,
    element_index: None,
    token_index: Some(token.token_index),
    token_name: Some(token.token_name),
    text: Some(token.text),
    message: Some(message),
    visible_offset: stream.visible_offset(),
    depth,
    recovered: true,
    span: token.span,
  }
}

///|
fn parser_recovery_record(
  kind : ParserRecoveryKind,
  token : LexerToken,
  message : String,
  stream : ParserTokenStream,
) -> ParserRecoveryEvent {
  {
    kind,
    token_index: Some(token.token_index),
    token_name: Some(token.token_name),
    message,
    visible_offset: stream.visible_offset(),
    span: token.span,
  }
}

///|
fn parser_runtime_diagnostic(
  message : String,
  span : @antlr.SourceSpan,
) -> @antlr.Diagnostic {
  @antlr.Diagnostic::error(message, span)
}

///|
fn parser_copy_visit_keys(
  values : Array[ParserVisitKey],
) -> Array[ParserVisitKey] {
  let copied : Array[ParserVisitKey] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_visit_contains(
  values : Array[ParserVisitKey],
  state_id : Int,
  input_offset : Int,
  precedence : Int,
  depth : Int,
  context_id : Int,
) -> Bool {
  for value in values {
    if value.state_id == state_id &&
      value.input_offset == input_offset &&
      value.precedence == precedence &&
      value.depth == depth &&
      value.context_id == context_id {
      return true
    }
  }
  false
}

///|
fn parser_extend_visit_path(
  values : Array[ParserVisitKey],
  state_id : Int,
  input_offset : Int,
  precedence : Int,
  depth : Int,
  context_id : Int,
) -> Array[ParserVisitKey] {
  let copied = parser_copy_visit_keys(values)
  copied.push({ state_id, input_offset, precedence, depth, context_id })
  copied
}

///|
fn parser_copy_call_keys(values : Array[ParserCallKey]) -> Array[ParserCallKey] {
  let copied : Array[ParserCallKey] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn parser_call_contains(
  values : Array[ParserCallKey],
  rule_id : Int,
  input_offset : Int,
  precedence : Int,
) -> Bool {
  for value in values {
    if value.rule_id == rule_id &&
      value.input_offset == input_offset &&
      value.precedence == precedence {
      return true
    }
  }
  false
}

///|
fn parser_extend_call_path(
  values : Array[ParserCallKey],
  rule_id : Int,
  input_offset : Int,
  precedence : Int,
) -> Array[ParserCallKey] {
  let copied = parser_copy_call_keys(values)
  copied.push({ rule_id, input_offset, precedence })
  copied
}

///|
fn parser_lookup_rule_memo(
  memo : Array[ParserRuleMemoEntry],
  rule_id : Int,
  input_offset : Int,
  precedence : Int,
  depth : Int,
  context_id : Int,
) -> (Bool, ParserMatch?) {
  for entry in memo {
    if entry.rule_id == rule_id &&
      entry.input_offset == input_offset &&
      entry.precedence == precedence &&
      entry.depth == depth &&
      entry.context_id == context_id {
      match entry.result {
        Some(match_value) => return (true, Some(parser_copy_match(match_value)))
        None => return (true, None)
      }
    }
  }
  (false, None)
}

///|
fn parser_record_rule_memo(
  memo : Array[ParserRuleMemoEntry],
  rule_id : Int,
  input_offset : Int,
  precedence : Int,
  depth : Int,
  context_id : Int,
  result : ParserMatch?,
) -> Unit {
  memo.push({
    rule_id,
    input_offset,
    precedence,
    depth,
    context_id,
    result: match result {
      Some(match_value) => Some(parser_copy_match(match_value))
      None => None
    },
  })
}

///|
fn parser_parse_precedence_arg(args : String?) -> Int {
  match args {
    Some(raw_args) => {
      let trimmed = raw_args.trim().to_string()
      if trimmed.has_prefix("[") &&
        trimmed.has_suffix("]") &&
        trimmed.length() >= 2 {
        @string.parse_int(trimmed[1:trimmed.length() - 1].to_string().trim()) catch {
          _ => 0
        }
      } else {
        0
      }
    }
    None => 0
  }
}

///|
fn parser_read_charset_char(raw : String, index : Int) -> (Char, Int) {
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
fn parser_charset_matches(raw : String, wanted : Char) -> Bool {
  if !raw.has_prefix("[") || !raw.has_suffix("]") || raw.length() < 2 {
    return false
  }
  let mut index = 1
  let end = raw.length() - 1
  while index < end {
    let (start_char, next_index) = parser_read_charset_char(raw, index)
    if next_index < end &&
      raw.get_char(next_index).unwrap() == '-' &&
      next_index + 1 < end {
      let (end_char, after_end) = parser_read_charset_char(raw, next_index + 1)
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
fn parser_range_matches(raw : String, wanted : Char) -> Bool {
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
fn parser_simple_label_matches(token : LexerToken, label : String) -> Bool {
  if token.is_eof {
    return label == "EOF"
  }
  if label == "." {
    return true
  }
  if token.text.length() == 1 {
    let c = token.text.get_char(0).unwrap()
    if parser_range_matches(label, c) {
      return true
    }
  }
  if label.has_prefix("[") && label.has_suffix("]") {
    return token.text.length() == 1 &&
      parser_charset_matches(label, token.text.get_char(0).unwrap())
  }
  if label.has_prefix("'") && label.has_suffix("'") {
    return token.text == unescape_antlr_literal(label)
  }
  token.token_name == label
}

///|
fn parser_labels_match_token(
  token : LexerToken,
  labels : Array[String],
  negated : Bool,
) -> Bool {
  let mut matched = false
  for label in labels {
    if parser_simple_label_matches(token, label) {
      matched = true
      break
    }
  }
  if negated {
    !matched && !token.is_eof
  } else {
    matched
  }
}

///|
fn parser_transition_matches_token(
  transition : @antlr.AtnTransition,
  token : LexerToken,
) -> Bool {
  let matched = match transition.kind {
    @antlr.TokenReferenceTransition(name) => token.token_name == name
    @antlr.StringLiteralTransition(text) =>
      parser_simple_label_matches(token, text)
    @antlr.RangeTransition(text) =>
      parser_labels_match_token(token, [text], false)
    @antlr.CharSetTransition(text) =>
      parser_labels_match_token(token, [text], false)
    @antlr.SetTransition(labels) =>
      parser_labels_match_token(token, labels, false)
    @antlr.NotSetTransition(labels) =>
      parser_labels_match_token(token, labels, true)
    @antlr.WildcardTransition => !token.is_eof
    _ => false
  }
  if transition.negated {
    !matched && !token.is_eof
  } else {
    matched
  }
}

///|
fn parser_transition_expected_text(kind : @antlr.AtnTransitionKind) -> String {
  match kind {
    @antlr.TokenReferenceTransition(name) => name
    @antlr.StringLiteralTransition(text) => text
    @antlr.RangeTransition(text) => text
    @antlr.CharSetTransition(text) => text
    @antlr.SetTransition(labels) => labels.join(" | ")
    @antlr.NotSetTransition(labels) => "~(" + labels.join(" | ") + ")"
    @antlr.WildcardTransition => "."
    @antlr.RuleReferenceTransition(rule_call) => rule_call.rule_ref.name
    @antlr.PredicateTransition(text, _) => text
    @antlr.PrecedenceTransition(_, text) => text
    @antlr.ActionTransition(text) => text
    @antlr.EpsilonTransition => "<epsilon>"
    @antlr.LexerCommandTransition(command) => command.name
  }
}

///|
fn parser_rule_graph_or_abort(
  atn : @antlr.GrammarAtn,
  rule_id : Int,
) -> @antlr.AtnRuleGraph {
  match atn.rule_by_id(rule_id) {
    Some(rule_graph) => rule_graph
    None =>
      abort("expected parser rule graph for rule id " + rule_id.to_string())
  }
}

///|
fn parser_transition_can_match_lookahead(
  atn : @antlr.GrammarAtn,
  transition : @antlr.AtnTransition,
  token : LexerToken,
  hooks : ParserHostHooks,
  precedence : Int,
  visited_state_ids : Array[Int],
) -> Bool {
  match transition.kind {
    @antlr.EpsilonTransition =>
      parser_state_can_match_lookahead(
        atn,
        transition.target_state_id,
        token,
        hooks,
        precedence,
        visited_state_ids,
      )
    @antlr.ActionTransition(_) =>
      parser_state_can_match_lookahead(
        atn,
        transition.target_state_id,
        token,
        hooks,
        precedence,
        visited_state_ids,
      )
    @antlr.PredicateTransition(text, _) =>
      parser_predicate_binding_value(hooks, text) &&
      parser_state_can_match_lookahead(
        atn,
        transition.target_state_id,
        token,
        hooks,
        precedence,
        visited_state_ids,
      )
    @antlr.PrecedenceTransition(required_precedence, _) =>
      required_precedence >= precedence &&
      parser_state_can_match_lookahead(
        atn,
        transition.target_state_id,
        token,
        hooks,
        precedence,
        visited_state_ids,
      )
    @antlr.RuleReferenceTransition(rule_call) => {
      let called_rule_id = match rule_call.called_rule_id {
        Some(value) => value
        None =>
          match atn.find_rule(rule_call.rule_ref.name) {
            Some(rule_graph) => rule_graph.rule_id
            None => return false
          }
      }
      let called_rule = parser_rule_graph_or_abort(atn, called_rule_id)
      parser_state_can_match_lookahead(
        atn,
        called_rule.start_state_id,
        token,
        hooks,
        parser_parse_precedence_arg(rule_call.rule_ref.args),
        visited_state_ids,
      )
    }
    _ => parser_transition_matches_token(transition, token)
  }
}

///|
fn parser_state_contains(values : Array[Int], wanted : Int) -> Bool {
  for value in values {
    if value == wanted {
      return true
    }
  }
  false
}

///|
fn parser_extend_state_ids(values : Array[Int], wanted : Int) -> Array[Int] {
  let copied : Array[Int] = []
  for value in values {
    copied.push(value)
  }
  copied.push(wanted)
  copied
}

///|
fn parser_state_can_match_lookahead(
  atn : @antlr.GrammarAtn,
  state_id : Int,
  token : LexerToken,
  hooks : ParserHostHooks,
  precedence : Int,
  visited_state_ids : Array[Int],
) -> Bool {
  if parser_state_contains(visited_state_ids, state_id) {
    return false
  }
  let state = match atn.state(state_id) {
    Some(value) => value
    None => return false
  }
  match state.kind {
    @antlr.RuleStopState => return true
    _ => ()
  }
  let next_visited = parser_extend_state_ids(visited_state_ids, state_id)
  for transition in atn.outgoing_transitions(state_id) {
    if parser_transition_can_match_lookahead(
        atn, transition, token, hooks, precedence, next_visited,
      ) {
      return true
    }
  }
  false
}

///|
fn parser_match_rule(
  atn : @antlr.GrammarAtn,
  rule_id : Int,
  stream : ParserTokenStream,
  hooks : ParserHostHooks,
  memo : Array[ParserRuleMemoEntry],
  contexts : PredictionContextArena,
  depth : Int,
  precedence : Int,
  context_id : Int,
  call_path : Array[ParserCallKey],
) -> ParserMatch? {
  match
    parser_lookup_rule_memo(
      memo,
      rule_id,
      stream.visible_offset(),
      precedence,
      depth,
      context_id,
    ) {
    (true, result) => return result
    _ => ()
  }
  if parser_call_contains(
      call_path,
      rule_id,
      stream.visible_offset(),
      precedence,
    ) {
    return None
  }
  let rule_graph = parser_rule_graph_or_abort(atn, rule_id)
  let enter_event = parser_enter_rule_event(rule_graph, stream, depth)
  let body = parser_match_state(
    atn,
    rule_graph,
    rule_graph.stop_state_id,
    rule_graph.start_state_id,
    stream,
    hooks,
    memo,
    contexts,
    depth,
    precedence,
    context_id,
    [],
    parser_extend_call_path(
      call_path,
      rule_id,
      stream.visible_offset(),
      precedence,
    ),
  )
  let result = match body {
    Some(body_match) => {
      let with_enter = parser_match_with_prefixed_event(enter_event, body_match)
      Some(
        parser_match_with_suffixed_event(
          with_enter,
          parser_exit_rule_event(
            rule_graph,
            stream,
            body_match.end_stream,
            depth,
            true,
          ),
        ),
      )
    }
    None => None
  }
  parser_record_rule_memo(
    memo,
    rule_id,
    stream.visible_offset(),
    precedence,
    depth,
    context_id,
    result,
  )
  result
}

///|
fn parser_choose_better_match(
  current : ParserMatch?,
  candidate : ParserMatch?,
) -> ParserMatch? {
  match candidate {
    None => current
    Some(candidate_match) =>
      match current {
        None => Some(candidate_match)
        Some(current_match) =>
          if parser_match_score(candidate_match) >
            parser_match_score(current_match) {
            Some(candidate_match)
          } else {
            current
          }
      }
  }
}

///|
fn parser_match_state(
  atn : @antlr.GrammarAtn,
  rule_graph : @antlr.AtnRuleGraph,
  stop_state_id : Int,
  state_id : Int,
  stream : ParserTokenStream,
  hooks : ParserHostHooks,
  memo : Array[ParserRuleMemoEntry],
  contexts : PredictionContextArena,
  depth : Int,
  precedence : Int,
  context_id : Int,
  visit_path : Array[ParserVisitKey],
  call_path : Array[ParserCallKey],
) -> ParserMatch? {
  if state_id == stop_state_id {
    let state = match atn.state(state_id) {
      Some(value) => value
      None => abort("expected parser stop state `" + state_id.to_string() + "`")
    }
    return Some(
      parser_match_with_prefixed_config(
        parser_state_config(
          state,
          stream.visible_offset(),
          0,
          context_id,
          precedence,
        ),
        parser_empty_match(stream),
      ),
    )
  }
  if parser_visit_contains(
      visit_path,
      state_id,
      stream.visible_offset(),
      precedence,
      depth,
      context_id,
    ) {
    return None
  }
  let state = match atn.state(state_id) {
    Some(value) => value
    None => abort("expected parser state `" + state_id.to_string() + "`")
  }
  let next_visit_path = parser_extend_visit_path(
    visit_path,
    state_id,
    stream.visible_offset(),
    precedence,
    depth,
    context_id,
  )
  match state.decision_id {
    Some(decision_id) =>
      parser_match_decision_state(
        atn, rule_graph, state, decision_id, stop_state_id, stream, hooks, memo,
        contexts, depth, precedence, context_id, next_visit_path, call_path,
      )
    None => {
      let mut best : ParserMatch? = None
      for transition in atn.outgoing_transitions(state_id) {
        let candidate = parser_match_transition_and_continue(
          atn, rule_graph, state, transition, stop_state_id, stream, hooks, memo,
          contexts, depth, precedence, context_id, next_visit_path, call_path,
        )
        best = parser_choose_better_match(best, candidate)
      }
      match best {
        Some(best_match) =>
          Some(
            parser_match_with_prefixed_config(
              parser_state_config(
                state,
                stream.visible_offset(),
                0,
                context_id,
                precedence,
              ),
              best_match,
            ),
          )
        None => None
      }
    }
  }
}

///|
fn parser_match_decision_state(
  atn : @antlr.GrammarAtn,
  rule_graph : @antlr.AtnRuleGraph,
  state : @antlr.AtnState,
  decision_id : Int,
  stop_state_id : Int,
  stream : ParserTokenStream,
  hooks : ParserHostHooks,
  memo : Array[ParserRuleMemoEntry],
  contexts : PredictionContextArena,
  depth : Int,
  precedence : Int,
  context_id : Int,
  visit_path : Array[ParserVisitKey],
  call_path : Array[ParserCallKey],
) -> ParserMatch? {
  let decision = match atn.decision(decision_id) {
    Some(value) => value
    None => abort("expected parser decision `" + decision_id.to_string() + "`")
  }
  let transitions = atn.outgoing_transitions(state.id)
  let lookahead_token = stream.lt(1)
  let shallow_candidates : Array[Int] = []
  for index = 0; index < transitions.length(); index = index + 1 {
    if parser_transition_can_match_lookahead(
        atn,
        transitions[index],
        lookahead_token,
        hooks,
        precedence,
        [],
      ) {
      shallow_candidates.push(index + 1)
    }
  }
  let used_full_context = shallow_candidates.length() > 1
  let successful_alternatives : Array[Int] = []
  let mut best : ParserMatch? = None
  let mut best_alternative : Int? = None
  for index = 0; index < transitions.length(); index = index + 1 {
    let transition = transitions[index]
    let alternative_number = index + 1
    match
      parser_match_transition_and_continue(
        atn, rule_graph, state, transition, stop_state_id, stream, hooks, memo, contexts,
        depth, precedence, context_id, visit_path, call_path,
      ) {
      Some(candidate_match) => {
        successful_alternatives.push(alternative_number)
        let candidate_with_alt = if alternative_number <=
          decision.public_alternatives.length() {
          match decision.public_alternatives[alternative_number - 1] {
            Some(alternative_origin) =>
              parser_match_with_prefixed_event(
                parser_commit_alternative_event(
                  rule_graph, alternative_origin, stream, depth,
                ),
                candidate_match,
              )
            None => candidate_match
          }
        } else {
          candidate_match
        }
        match best {
          Some(current_best) =>
            if parser_match_score(candidate_with_alt) >
              parser_match_score(current_best) {
              best = Some(candidate_with_alt)
              best_alternative = Some(alternative_number)
            }
          None => {
            best = Some(candidate_with_alt)
            best_alternative = Some(alternative_number)
          }
        }
      }
      None => ()
    }
  }
  match best {
    Some(best_match) => {
      let best_score = parser_match_score(best_match)
      let ambiguous_alternatives : Array[Int] = []
      for alternative_number in successful_alternatives {
        let transition = transitions[alternative_number - 1]
        match
          parser_match_transition_and_continue(
            atn, rule_graph, state, transition, stop_state_id, stream, hooks, memo,
            contexts, depth, precedence, context_id, visit_path, call_path,
          ) {
          Some(candidate_match) =>
            if parser_match_score(candidate_match) == best_score {
              ambiguous_alternatives.push(alternative_number)
            }
          None => ()
        }
      }
      let with_config = parser_match_with_prefixed_config(
        parser_state_config(
          state,
          stream.visible_offset(),
          match best_alternative {
            Some(value) => value
            None => 0
          },
          context_id,
          precedence,
        ),
        best_match,
      )
      let dfa_entry = {
        decision_id,
        input_offset: stream.visible_offset(),
        lookahead_token_name: lookahead_token.token_name,
        chosen_alternative: best_alternative,
        ambiguous_alternatives,
        used_full_context,
        config_signature: make_parser_config_set(with_config.configs).signature(
          contexts,
        ),
      }
      Some({
        end_stream: with_config.end_stream,
        events: parser_copy_events(with_config.events),
        recovery_events: parser_copy_recovery_events(
          with_config.recovery_events,
        ),
        diagnostics: parser_copy_diagnostics(with_config.diagnostics),
        dfa_entries: parser_concat_dfa_entries(with_config.dfa_entries, [
          dfa_entry,
        ]),
        configs: parser_copy_configs(with_config.configs),
        full_context_fallbacks: with_config.full_context_fallbacks +
        (if used_full_context { 1 } else { 0 }),
        ambiguities: with_config.ambiguities +
        (if ambiguous_alternatives.length() > 1 { 1 } else { 0 }),
      })
    }
    None => None
  }
}

///|
fn parser_match_transition_and_continue(
  atn : @antlr.GrammarAtn,
  rule_graph : @antlr.AtnRuleGraph,
  _state : @antlr.AtnState,
  transition : @antlr.AtnTransition,
  stop_state_id : Int,
  stream : ParserTokenStream,
  hooks : ParserHostHooks,
  memo : Array[ParserRuleMemoEntry],
  contexts : PredictionContextArena,
  depth : Int,
  precedence : Int,
  context_id : Int,
  visit_path : Array[ParserVisitKey],
  call_path : Array[ParserCallKey],
) -> ParserMatch? {
  match transition.kind {
    @antlr.EpsilonTransition =>
      parser_match_state(
        atn,
        rule_graph,
        stop_state_id,
        transition.target_state_id,
        stream,
        hooks,
        memo,
        contexts,
        depth,
        precedence,
        context_id,
        visit_path,
        call_path,
      )
    @antlr.ActionTransition(text) =>
      match
        parser_match_state(
          atn,
          rule_graph,
          stop_state_id,
          transition.target_state_id,
          stream,
          hooks,
          memo,
          contexts,
          depth,
          precedence,
          context_id,
          visit_path,
          call_path,
        ) {
        Some(suffix) =>
          Some(
            parser_match_with_prefixed_event(
              parser_action_event(
                rule_graph,
                text,
                parser_action_binding_label(hooks, text),
                stream,
                depth,
              ),
              suffix,
            ),
          )
        None => None
      }
    @antlr.PredicateTransition(text, _) =>
      if parser_predicate_binding_value(hooks, text) {
        parser_match_state(
          atn,
          rule_graph,
          stop_state_id,
          transition.target_state_id,
          stream,
          hooks,
          memo,
          contexts,
          depth,
          precedence,
          context_id,
          visit_path,
          call_path,
        )
      } else {
        None
      }
    @antlr.PrecedenceTransition(required_precedence, _) =>
      if required_precedence >= precedence {
        parser_match_state(
          atn,
          rule_graph,
          stop_state_id,
          transition.target_state_id,
          stream,
          hooks,
          memo,
          contexts,
          depth,
          precedence,
          context_id,
          visit_path,
          call_path,
        )
      } else {
        None
      }
    @antlr.RuleReferenceTransition(rule_call) => {
      let called_rule_id = match rule_call.called_rule_id {
        Some(value) => value
        None =>
          match atn.find_rule(rule_call.rule_ref.name) {
            Some(called_rule) => called_rule.rule_id
            None => return None
          }
      }
      let child_context_id = parser_prediction_context_child(
        contexts,
        context_id,
        match rule_call.follow_state_id {
          Some(value) => value
          None => transition.target_state_id
        },
      )
      match
        parser_match_rule(
          atn,
          called_rule_id,
          stream,
          hooks,
          memo,
          contexts,
          depth + 1,
          parser_parse_precedence_arg(rule_call.rule_ref.args),
          child_context_id,
          call_path,
        ) {
        Some(called_match) =>
          match
            parser_match_state(
              atn,
              rule_graph,
              stop_state_id,
              match rule_call.follow_state_id {
                Some(value) => value
                None => transition.target_state_id
              },
              called_match.end_stream,
              hooks,
              memo,
              contexts,
              depth,
              precedence,
              context_id,
              visit_path,
              call_path,
            ) {
            Some(follow_match) =>
              Some(parser_combine_matches(called_match, follow_match))
            None => None
          }
        None => None
      }
    }
    _ => {
      let token = stream.lt(1)
      if parser_transition_matches_token(transition, token) {
        match
          parser_match_state(
            atn,
            rule_graph,
            stop_state_id,
            transition.target_state_id,
            stream.consume(),
            hooks,
            memo,
            contexts,
            depth,
            precedence,
            context_id,
            visit_path,
            call_path,
          ) {
          Some(suffix) =>
            Some(
              parser_match_with_prefixed_event(
                parser_consume_token_event(
                  rule_graph,
                  transition.origin,
                  token,
                  stream,
                  depth,
                  false,
                ),
                suffix,
              ),
            )
          None => None
        }
      } else if !token.is_eof &&
        parser_transition_matches_token(transition, stream.lt(2)) {
        let deleted_token = token
        let matched_token = stream.lt(2)
        let message = "deleted unexpected token `" +
          deleted_token.token_name +
          "` while matching `" +
          parser_transition_expected_text(transition.kind) +
          "`"
        match
          parser_match_state(
            atn,
            rule_graph,
            stop_state_id,
            transition.target_state_id,
            stream.advance_by(2),
            hooks,
            memo,
            contexts,
            depth,
            precedence,
            context_id,
            visit_path,
            call_path,
          ) {
          Some(suffix) => {
            let with_diag = {
              end_stream: suffix.end_stream,
              events: parser_copy_events(suffix.events),
              recovery_events: parser_copy_recovery_events(
                suffix.recovery_events,
              ),
              diagnostics: parser_concat_diagnostics(
                [parser_runtime_diagnostic(message, deleted_token.span)],
                suffix.diagnostics,
              ),
              dfa_entries: parser_copy_dfa_entries_for_match(suffix.dfa_entries),
              configs: parser_copy_configs(suffix.configs),
              full_context_fallbacks: suffix.full_context_fallbacks,
              ambiguities: suffix.ambiguities,
            }
            let with_recovery = {
              end_stream: with_diag.end_stream,
              events: parser_concat_events(
                [
                  parser_recovery_trace_event(
                    DeletedToken,
                    deleted_token,
                    message,
                    stream,
                    depth,
                  ),
                ],
                with_diag.events,
              ),
              recovery_events: parser_concat_recovery_events(
                [
                  parser_recovery_record(
                    DeletedToken,
                    deleted_token,
                    message,
                    stream,
                  ),
                ],
                with_diag.recovery_events,
              ),
              diagnostics: parser_copy_diagnostics(with_diag.diagnostics),
              dfa_entries: parser_copy_dfa_entries_for_match(
                with_diag.dfa_entries,
              ),
              configs: parser_copy_configs(with_diag.configs),
              full_context_fallbacks: with_diag.full_context_fallbacks,
              ambiguities: with_diag.ambiguities,
            }
            Some(
              parser_match_with_prefixed_event(
                parser_consume_token_event(
                  rule_graph,
                  transition.origin,
                  matched_token,
                  stream.consume(),
                  depth,
                  true,
                ),
                with_recovery,
              ),
            )
          }
          None => None
        }
      } else {
        None
      }
    }
  }
}

///|
fn parser_find_start_rule(atn : @antlr.GrammarAtn) -> @antlr.AtnRuleGraph? {
  match atn.start_rule_id {
    Some(rule_id) => Some(parser_rule_graph_or_abort(atn, rule_id))
    None => None
  }
}

///|
fn parser_failure_result(
  atn : @antlr.GrammarAtn,
  tokens : Array[LexerToken],
  message : String,
) -> ParserRunResult {
  let stream = ParserTokenStream::new(tokens)
  let start_rule = match parser_find_start_rule(atn) {
    Some(rule_graph) => rule_graph
    None => abort("parser runtime requires a parser start rule")
  }
  let diagnostic = parser_runtime_diagnostic(message, parser_point_span(stream))
  {
    success: false,
    start_rule_id: start_rule.rule_id,
    start_rule_name: start_rule.rule_name,
    tokens,
    events: [
      parser_enter_rule_event(start_rule, stream, 0),
      parser_exit_rule_event(start_rule, stream, stream, 0, false),
    ],
    recovery_events: [],
    diagnostics: [diagnostic],
    dfa: empty_parser_dfa(),
    consumed_visible_tokens: 0,
    full_context_fallbacks: 0,
    ambiguities: 0,
  }
}

///|
/// Parse one Phase 2 token stream directly from the stable Phase 1 ATN contract.
///
/// Example:
/// let parsed = parse_with_atn(atn, lexer_result.tokens, ParserHostHooks::empty())
/// inspect(parsed.start_rule_name.length() > 0, content="true")
///
/// Notes:
/// - The parser consumes only default-channel tokens plus EOF, while retaining the full token table on the result.
/// - Recovery is currently correctness-first and intentionally minimal: deleted unexpected tokens and trailing-token fences are recorded explicitly.
pub fn parse_with_atn(
  atn : @antlr.GrammarAtn,
  tokens : Array[LexerToken],
  hooks : ParserHostHooks,
) -> ParserRunResult {
  let start_rule = match parser_find_start_rule(atn) {
    Some(rule_graph) => rule_graph
    None =>
      return parser_failure_result(
        atn, tokens, "parser runtime requires a parser start rule",
      )
  }
  let stream = ParserTokenStream::new(tokens)
  let contexts = new_prediction_context_arena()
  let memo : Array[ParserRuleMemoEntry] = []
  match
    parser_match_rule(
      atn,
      start_rule.rule_id,
      stream,
      hooks,
      memo,
      contexts,
      0,
      if start_rule.signature == Some("[p]") {
        0
      } else {
        0
      },
      contexts.empty_context_id(),
      [],
    ) {
    Some(match_value) => {
      let recovery_events = parser_copy_recovery_events(
        match_value.recovery_events,
      )
      let diagnostics = parser_copy_diagnostics(match_value.diagnostics)
      let events = parser_copy_events(match_value.events)
      let mut end_stream = match_value.end_stream
      while !end_stream.is_eof() {
        let token = end_stream.lt(1)
        let message = "unexpected trailing token `" + token.token_name + "`"
        recovery_events.push(
          parser_recovery_record(UnexpectedToken, token, message, end_stream),
        )
        diagnostics.push(parser_runtime_diagnostic(message, token.span))
        events.push(
          parser_recovery_trace_event(
            UnexpectedToken,
            token,
            message,
            end_stream,
            0,
          ),
        )
        end_stream = end_stream.consume()
      }
      {
        success: diagnostics.length() == 0 && recovery_events.length() == 0,
        start_rule_id: start_rule.rule_id,
        start_rule_name: start_rule.rule_name,
        tokens,
        events,
        recovery_events,
        diagnostics,
        dfa: append_parser_dfa_entries(
          empty_parser_dfa(),
          match_value.dfa_entries,
        ),
        consumed_visible_tokens: end_stream.visible_offset(),
        full_context_fallbacks: match_value.full_context_fallbacks,
        ambiguities: match_value.ambiguities,
      }
    }
    None =>
      parser_failure_result(
        atn,
        tokens,
        "no viable parser alternative in rule `" + start_rule.rule_name + "`",
      )
  }
}

///|
/// Parse one Phase 2 token stream from the serialized Phase 1 ATN format.
///
/// Example:
/// let parsed = parse_serialized_atn(serialized_atn, lexer_result.tokens, ParserHostHooks::empty())
/// inspect(parsed is Ok(_), content="true")
///
/// Notes:
/// - This proves the parser runtime can start from deserialized ATN data alone.
pub fn parse_serialized_atn(
  serialized_atn : String,
  tokens : Array[LexerToken],
  hooks : ParserHostHooks,
) -> Result[ParserRunResult, String] {
  match @antlr.deserialize_grammar_atn(serialized_atn) {
    Ok(atn) => Ok(parse_with_atn(atn, tokens, hooks))
    Err(error) => Err(error)
  }
}
