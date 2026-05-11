///|
/// Distinguishes the structural roles used by the Phase 1 ATN IR.
pub(all) enum AtnStateKind {
  RuleStartState
  RuleStopState
  BasicState
  BlockStartState
  BlockEndState
  PlusBlockStartState
  StarBlockStartState
  LoopEntryState
  LoopBackState
  LoopEndState
  ModeStartState
  RuleCallState
}

///|
/// One ATN state attached to a specific rule or lexer mode.
pub struct AtnState {
  id : Int
  rule_name : String?
  rule_id : Int?
  mode : String?
  kind : AtnStateKind
  greedy : Bool
  decision_id : Int?
  origin : NormalizedOrigin?
}

///|
/// Decision categories recorded by the Phase 1 ATN contract.
pub(all) enum AtnDecisionKind {
  BlockDecision
  OptionalDecision
  LoopEntryDecision
  LoopBackDecision
  ModeStartDecision
}

///|
/// Stable decision metadata for runtime and CST-facing origin lookups.
pub struct AtnDecision {
  decision_id : Int
  rule_name : String?
  rule_id : Int?
  state_id : Int
  kind : AtnDecisionKind
  alternative_count : Int
  public_alternatives : Array[NormalizedAlternativeOrigin?]
}

///|
/// Aggregated lexer mode start graph metadata.
pub struct AtnModeStart {
  mode_name : String
  state_id : Int
  rule_ids : Array[Int]
}

///|
/// Structured payload for one rule call transition.
pub struct AtnRuleCall {
  rule_ref : RuleReference
  called_rule_id : Int?
  follow_state_id : Int?
}

///|
/// Transition kinds preserved by the Phase 1 grammar-to-ATN lowering step.
pub(all) enum AtnTransitionKind {
  EpsilonTransition
  RuleReferenceTransition(AtnRuleCall)
  TokenReferenceTransition(String)
  StringLiteralTransition(String)
  RangeTransition(String)
  CharSetTransition(String)
  SetTransition(Array[String])
  NotSetTransition(Array[String])
  WildcardTransition
  ActionTransition(String)
  PredicateTransition(String, String?)
  PrecedenceTransition(Int, String)
  LexerCommandTransition(LexerCommandSpec)
}

///|
/// Directed edge between two ATN states.
pub struct AtnTransition {
  source_state_id : Int
  target_state_id : Int
  kind : AtnTransitionKind
  negated : Bool
  order : Int
  origin : NormalizedOrigin?
}

///|
/// Per-rule entry in the Phase 1 grammar ATN.
pub struct AtnRuleGraph {
  rule_id : Int
  rule_name : String
  kind : GrammarRuleKind
  mode : String?
  signature : String?
  start_state_id : Int
  stop_state_id : Int
  state_ids : Array[Int]
  decision_ids : Array[Int]
  rewritten : Bool
}

///|
/// Aggregate ATN IR for the normalized grammar contract.
pub struct GrammarAtn {
  grammar_name : String
  grammar_kind : GrammarKind
  grammar_fingerprint : String
  start_rule_id : Int?
  states : Array[AtnState]
  transitions : Array[AtnTransition]
  rules : Array[AtnRuleGraph]
  decisions : Array[AtnDecision]
  mode_starts : Array[AtnModeStart]
  public_rules : Array[GrammarRuleSymbol]
  public_alternatives : Array[GrammarAlternativeSymbol]
  public_slots : Array[GrammarSlotSymbol]
  public_tokens : Array[GrammarTokenSymbol]
  public_channels : Array[GrammarChannelSymbol]
  public_modes : Array[GrammarModeSymbol]
}

///|
priv struct BuildState {
  semantic_model : SemanticModel
  next_state_id : Int
  next_transition_order : Int
  next_decision_id : Int
  states : Array[AtnState]
  transitions : Array[AtnTransition]
  decisions : Array[AtnDecision]
}

///|
priv struct Fragment {
  start_state_id : Int
  stop_state_id : Int
}

///|
let default_mode_name = "DEFAULT_MODE"

///|
fn atn_rule_is_lexer(kind : GrammarRuleKind) -> Bool {
  match kind {
    LexerRule => true
    _ => false
  }
}

///|
fn atn_grammar_is_lexer(kind : GrammarKind) -> Bool {
  match kind {
    Parser => false
    _ => true
  }
}

///|
fn empty_build_state(semantic_model : SemanticModel) -> BuildState {
  {
    semantic_model,
    next_state_id: 0,
    next_transition_order: 0,
    next_decision_id: 0,
    states: [],
    transitions: [],
    decisions: [],
  }
}

///|
fn mode_name_for_rule(rule : NormalizedRule) -> String? {
  match rule.mode {
    Some(mode_name) => Some(mode_name)
    None =>
      if atn_rule_is_lexer(rule.kind) {
        Some(default_mode_name)
      } else {
        None
      }
  }
}

///|
fn rule_level_origin(rule : NormalizedRule) -> NormalizedOrigin {
  make_origin(rule.public_origin, None, None, None)
}

///|
fn alternative_level_origin(
  rule : NormalizedRule,
  alternative : NormalizedAlternative,
) -> NormalizedOrigin {
  make_origin(
    rule.public_origin,
    alternative.public_origin,
    None,
    alternative.synthetic_kind,
  )
}

///|
fn reserve_decision_id(build_state : BuildState) -> (BuildState, Int) {
  let decision_id = build_state.next_decision_id
  (
    {
      semantic_model: build_state.semantic_model,
      next_state_id: build_state.next_state_id,
      next_transition_order: build_state.next_transition_order,
      next_decision_id: decision_id + 1,
      states: build_state.states,
      transitions: build_state.transitions,
      decisions: build_state.decisions,
    },
    decision_id,
  )
}

///|
fn add_state(
  build_state : BuildState,
  rule_name : String?,
  rule_id : Int?,
  mode : String?,
  kind : AtnStateKind,
  greedy : Bool,
  decision_id : Int?,
  origin : NormalizedOrigin?,
) -> (BuildState, Int) {
  let state_id = build_state.next_state_id
  let states = build_state.states
  states.push({
    id: state_id,
    rule_name,
    rule_id,
    mode,
    kind,
    greedy,
    decision_id,
    origin,
  })
  (
    {
      semantic_model: build_state.semantic_model,
      next_state_id: state_id + 1,
      next_transition_order: build_state.next_transition_order,
      next_decision_id: build_state.next_decision_id,
      states,
      transitions: build_state.transitions,
      decisions: build_state.decisions,
    },
    state_id,
  )
}

///|
fn add_transition(
  build_state : BuildState,
  source_state_id : Int,
  target_state_id : Int,
  kind : AtnTransitionKind,
  negated : Bool,
  origin : NormalizedOrigin?,
) -> BuildState {
  let transitions = build_state.transitions
  transitions.push({
    source_state_id,
    target_state_id,
    kind,
    negated,
    order: build_state.next_transition_order,
    origin,
  })
  {
    semantic_model: build_state.semantic_model,
    next_state_id: build_state.next_state_id,
    next_transition_order: build_state.next_transition_order + 1,
    next_decision_id: build_state.next_decision_id,
    states: build_state.states,
    transitions,
    decisions: build_state.decisions,
  }
}

///|
fn record_decision(
  build_state : BuildState,
  decision_id : Int,
  rule_name : String?,
  rule_id : Int?,
  state_id : Int,
  kind : AtnDecisionKind,
  public_alternatives : Array[NormalizedAlternativeOrigin?],
) -> BuildState {
  let decisions = build_state.decisions
  decisions.push({
    decision_id,
    rule_name,
    rule_id,
    state_id,
    kind,
    alternative_count: public_alternatives.length(),
    public_alternatives,
  })
  {
    semantic_model: build_state.semantic_model,
    next_state_id: build_state.next_state_id,
    next_transition_order: build_state.next_transition_order,
    next_decision_id: build_state.next_decision_id,
    states: build_state.states,
    transitions: build_state.transitions,
    decisions,
  }
}

///|
fn called_rule_id(build_state : BuildState, rule_name : String) -> Int? {
  match build_state.semantic_model.find_rule(rule_name) {
    Some(rule_symbol) => Some(rule_symbol.rule_id)
    None => None
  }
}

///|
fn public_alternative_origins(
  alternatives : Array[NormalizedAlternative],
) -> Array[NormalizedAlternativeOrigin?] {
  let origins : Array[NormalizedAlternativeOrigin?] = []
  for alternative in alternatives {
    origins.push(alternative.public_origin)
  }
  origins
}

///|
fn loop_branch_origins(
  origin : NormalizedOrigin,
) -> Array[NormalizedAlternativeOrigin?] {
  [origin.alternative, None]
}

///|
fn label_text_for_set_element(element : NormalizedElement) -> String? {
  match element.kind {
    TokenReferenceElement(name) => Some(name)
    StringLiteralElement(text) => Some(text)
    RangeElement(text) => Some(text)
    CharSetElement(text) => Some(text)
    WildcardElement => Some(".")
    _ => None
  }
}

///|
fn extract_simple_set_labels(
  alternatives : Array[NormalizedAlternative],
) -> Array[String]? {
  let labels : Array[String] = []
  for alternative in alternatives {
    if alternative.commands.length() != 0 || alternative.elements.length() != 1 {
      return None
    }
    let element = alternative.elements[0]
    match element.suffix {
      Some(_) => return None
      None => ()
    }
    if element.negated {
      return None
    }
    match label_text_for_set_element(element) {
      Some(label) => labels.push(label)
      None => return None
    }
  }
  Some(labels)
}

///|
fn parse_precedence_value(text : String) -> Int? {
  let trimmed = text.trim().to_string()
  if !trimmed.has_prefix("{") || !trimmed.has_suffix("}") {
    return None
  }
  let inner = trimmed[1:trimmed.length() - 1].to_string().trim().to_string()
  let fields = inner
    .split(" ")
    .map(field => field.trim().to_string())
    .to_array()
  if fields.length() != 3 || fields[1] != ">=" || fields[2] != "$p" {
    return None
  }
  parse_decimal_int(fields[0])
}

///|
fn epsilon_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  origin : NormalizedOrigin?,
) -> (BuildState, Fragment) {
  let (build_state, start_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    BasicState,
    true,
    None,
    origin,
  )
  let (build_state, stop_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    BasicState,
    true,
    None,
    origin,
  )
  let build_state = add_transition(
    build_state,
    start_state_id,
    stop_state_id,
    EpsilonTransition,
    false,
    origin,
  )
  (build_state, { start_state_id, stop_state_id })
}

///|
fn labeled_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  kind : AtnTransitionKind,
  negated : Bool,
  source_kind : AtnStateKind,
  origin : NormalizedOrigin?,
) -> (BuildState, Fragment) {
  let (build_state, start_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    source_kind,
    true,
    None,
    origin,
  )
  let (build_state, stop_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    BasicState,
    true,
    None,
    origin,
  )
  let build_state = add_transition(
    build_state, start_state_id, stop_state_id, kind, negated, origin,
  )
  (build_state, { start_state_id, stop_state_id })
}

///|
fn build_rule_reference_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  element : NormalizedElement,
  rule_ref : RuleReference,
) -> (BuildState, Fragment) {
  let (build_state, start_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    RuleCallState,
    true,
    None,
    Some(element.origin),
  )
  let (build_state, stop_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    BasicState,
    true,
    None,
    Some(element.origin),
  )
  let build_state = add_transition(
    build_state,
    start_state_id,
    stop_state_id,
    RuleReferenceTransition({
      rule_ref,
      called_rule_id: called_rule_id(build_state, rule_ref.name),
      follow_state_id: Some(stop_state_id),
    }),
    false,
    Some(element.origin),
  )
  (build_state, { start_state_id, stop_state_id })
}

///|
fn build_alternative_set(
  build_state : BuildState,
  rule : NormalizedRule,
  alternatives : Array[NormalizedAlternative],
  state_kind : AtnStateKind,
  decision_kind : AtnDecisionKind,
  origin : NormalizedOrigin?,
) -> (BuildState, Fragment) {
  let (build_state, decision_id) = reserve_decision_id(build_state)
  let (build_state, block_start_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    state_kind,
    true,
    Some(decision_id),
    origin,
  )
  let (build_state, block_end_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    BlockEndState,
    true,
    None,
    origin,
  )
  let mut build_state = record_decision(
    build_state,
    decision_id,
    Some(rule.name),
    Some(rule.rule_id),
    block_start_state_id,
    decision_kind,
    public_alternative_origins(alternatives),
  )
  if alternatives.length() == 0 {
    build_state = add_transition(
      build_state,
      block_start_state_id,
      block_end_state_id,
      EpsilonTransition,
      false,
      origin,
    )
    return (
      build_state,
      {
        start_state_id: block_start_state_id,
        stop_state_id: block_end_state_id,
      },
    )
  }
  for alternative in alternatives {
    let (next_state, alternative_fragment) = build_alternative_fragment(
      build_state, rule, alternative,
    )
    build_state = add_transition(
      next_state,
      block_start_state_id,
      alternative_fragment.start_state_id,
      EpsilonTransition,
      false,
      Some(alternative_level_origin(rule, alternative)),
    )
    build_state = add_transition(
      build_state,
      alternative_fragment.stop_state_id,
      block_end_state_id,
      EpsilonTransition,
      false,
      Some(alternative_level_origin(rule, alternative)),
    )
  }
  (
    build_state,
    { start_state_id: block_start_state_id, stop_state_id: block_end_state_id },
  )
}

///|
fn build_group_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  element : NormalizedElement,
  alternatives : Array[NormalizedAlternative],
) -> (BuildState, Fragment) {
  match extract_simple_set_labels(alternatives) {
    Some(labels) =>
      labeled_fragment(
        build_state,
        rule,
        if element.negated {
          NotSetTransition(labels)
        } else {
          SetTransition(labels)
        },
        false,
        BasicState,
        Some(element.origin),
      )
    None =>
      build_alternative_set(
        build_state,
        rule,
        alternatives,
        BlockStartState,
        BlockDecision,
        Some(element.origin),
      )
  }
}

///|
fn build_atom_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  element : NormalizedElement,
) -> (BuildState, Fragment) {
  match element.kind {
    RuleReferenceElement(rule_ref) =>
      build_rule_reference_fragment(build_state, rule, element, rule_ref)
    TokenReferenceElement(name) =>
      labeled_fragment(
        build_state,
        rule,
        TokenReferenceTransition(name),
        element.negated,
        BasicState,
        Some(element.origin),
      )
    StringLiteralElement(text) =>
      labeled_fragment(
        build_state,
        rule,
        StringLiteralTransition(text),
        element.negated,
        BasicState,
        Some(element.origin),
      )
    RangeElement(text) =>
      labeled_fragment(
        build_state,
        rule,
        RangeTransition(text),
        element.negated,
        BasicState,
        Some(element.origin),
      )
    CharSetElement(text) =>
      labeled_fragment(
        build_state,
        rule,
        CharSetTransition(text),
        element.negated,
        BasicState,
        Some(element.origin),
      )
    WildcardElement =>
      labeled_fragment(
        build_state,
        rule,
        WildcardTransition,
        element.negated,
        BasicState,
        Some(element.origin),
      )
    GroupElement(alternatives) =>
      build_group_fragment(build_state, rule, element, alternatives)
    ActionElement(text) =>
      labeled_fragment(
        build_state,
        rule,
        ActionTransition(text),
        false,
        BasicState,
        Some(element.origin),
      )
    PredicateElement(text, suffix) => {
      let precedence = match element.origin.synthetic_kind {
        Some(LeftRecPrecedencePredicate) => parse_precedence_value(text)
        _ => None
      }
      match precedence {
        Some(value) =>
          labeled_fragment(
            build_state,
            rule,
            PrecedenceTransition(value, text),
            false,
            BasicState,
            Some(element.origin),
          )
        None =>
          labeled_fragment(
            build_state,
            rule,
            PredicateTransition(text, suffix),
            false,
            BasicState,
            Some(element.origin),
          )
      }
    }
  }
}

///|
fn wrap_fragment_with_suffix(
  build_state : BuildState,
  rule : NormalizedRule,
  inner : Fragment,
  origin : NormalizedOrigin,
  suffix : EbnfSuffix,
) -> (BuildState, Fragment) {
  match suffix.kind {
    OptionalSuffix => {
      let (build_state, decision_id) = reserve_decision_id(build_state)
      let (build_state, block_start_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        BlockStartState,
        suffix.greedy,
        Some(decision_id),
        Some(origin),
      )
      let (build_state, block_end_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        BlockEndState,
        suffix.greedy,
        None,
        Some(origin),
      )
      let mut build_state = record_decision(
        build_state,
        decision_id,
        Some(rule.name),
        Some(rule.rule_id),
        block_start_state_id,
        OptionalDecision,
        loop_branch_origins(origin),
      )
      build_state = add_transition(
        build_state,
        block_start_state_id,
        inner.start_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        block_start_state_id,
        block_end_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        inner.stop_state_id,
        block_end_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      (
        build_state,
        {
          start_state_id: block_start_state_id,
          stop_state_id: block_end_state_id,
        },
      )
    }
    ZeroOrMoreSuffix => {
      let (build_state, entry_decision_id) = reserve_decision_id(build_state)
      let (build_state, star_start_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        StarBlockStartState,
        suffix.greedy,
        Some(entry_decision_id),
        Some(origin),
      )
      let (build_state, loop_back_decision_id) = reserve_decision_id(
        build_state,
      )
      let (build_state, loop_back_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        LoopBackState,
        suffix.greedy,
        Some(loop_back_decision_id),
        Some(origin),
      )
      let (build_state, loop_end_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        LoopEndState,
        suffix.greedy,
        None,
        Some(origin),
      )
      let mut build_state = record_decision(
        build_state,
        entry_decision_id,
        Some(rule.name),
        Some(rule.rule_id),
        star_start_state_id,
        LoopEntryDecision,
        loop_branch_origins(origin),
      )
      build_state = record_decision(
        build_state,
        loop_back_decision_id,
        Some(rule.name),
        Some(rule.rule_id),
        loop_back_state_id,
        LoopBackDecision,
        loop_branch_origins(origin),
      )
      build_state = add_transition(
        build_state,
        star_start_state_id,
        inner.start_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        star_start_state_id,
        loop_end_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        inner.stop_state_id,
        loop_back_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        loop_back_state_id,
        inner.start_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        loop_back_state_id,
        loop_end_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      (
        build_state,
        {
          start_state_id: star_start_state_id,
          stop_state_id: loop_end_state_id,
        },
      )
    }
    OneOrMoreSuffix => {
      let (build_state, plus_start_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        PlusBlockStartState,
        suffix.greedy,
        None,
        Some(origin),
      )
      let (build_state, loop_back_decision_id) = reserve_decision_id(
        build_state,
      )
      let (build_state, loop_back_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        LoopBackState,
        suffix.greedy,
        Some(loop_back_decision_id),
        Some(origin),
      )
      let (build_state, loop_end_state_id) = add_state(
        build_state,
        Some(rule.name),
        Some(rule.rule_id),
        mode_name_for_rule(rule),
        LoopEndState,
        suffix.greedy,
        None,
        Some(origin),
      )
      let mut build_state = record_decision(
        build_state,
        loop_back_decision_id,
        Some(rule.name),
        Some(rule.rule_id),
        loop_back_state_id,
        LoopBackDecision,
        loop_branch_origins(origin),
      )
      build_state = add_transition(
        build_state,
        plus_start_state_id,
        inner.start_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        inner.stop_state_id,
        loop_back_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        loop_back_state_id,
        inner.start_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      build_state = add_transition(
        build_state,
        loop_back_state_id,
        loop_end_state_id,
        EpsilonTransition,
        false,
        Some(origin),
      )
      (
        build_state,
        {
          start_state_id: plus_start_state_id,
          stop_state_id: loop_end_state_id,
        },
      )
    }
  }
}

///|
fn build_element_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  element : NormalizedElement,
) -> (BuildState, Fragment) {
  let (build_state, inner) = build_atom_fragment(build_state, rule, element)
  match element.suffix {
    Some(suffix) =>
      wrap_fragment_with_suffix(
        build_state,
        rule,
        inner,
        element.origin,
        suffix,
      )
    None => (build_state, inner)
  }
}

///|
fn build_command_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  alternative : NormalizedAlternative,
  command : LexerCommandSpec,
) -> (BuildState, Fragment) {
  labeled_fragment(
    build_state,
    rule,
    LexerCommandTransition(command),
    false,
    BasicState,
    Some(alternative_level_origin(rule, alternative)),
  )
}

///|
fn stitch_fragments(
  build_state : BuildState,
  left : Fragment,
  right : Fragment,
  origin : NormalizedOrigin?,
) -> (BuildState, Fragment) {
  let build_state = add_transition(
    build_state,
    left.stop_state_id,
    right.start_state_id,
    EpsilonTransition,
    false,
    origin,
  )
  (
    build_state,
    { start_state_id: left.start_state_id, stop_state_id: right.stop_state_id },
  )
}

///|
fn build_alternative_fragment(
  build_state : BuildState,
  rule : NormalizedRule,
  alternative : NormalizedAlternative,
) -> (BuildState, Fragment) {
  let mut build_state = build_state
  let mut fragment : Fragment? = None
  let alternative_origin = Some(alternative_level_origin(rule, alternative))
  for element in alternative.elements {
    let (next_state, element_fragment) = build_element_fragment(
      build_state, rule, element,
    )
    build_state = next_state
    match fragment {
      Some(existing_fragment) => {
        let (next_state, stitched_fragment) = stitch_fragments(
          build_state, existing_fragment, element_fragment, alternative_origin,
        )
        build_state = next_state
        fragment = Some(stitched_fragment)
      }
      None => fragment = Some(element_fragment)
    }
  }
  for command in alternative.commands {
    let (next_state, command_fragment) = build_command_fragment(
      build_state, rule, alternative, command,
    )
    build_state = next_state
    match fragment {
      Some(existing_fragment) => {
        let (next_state, stitched_fragment) = stitch_fragments(
          build_state, existing_fragment, command_fragment, alternative_origin,
        )
        build_state = next_state
        fragment = Some(stitched_fragment)
      }
      None => fragment = Some(command_fragment)
    }
  }
  match fragment {
    Some(result) => (build_state, result)
    None => epsilon_fragment(build_state, rule, alternative_origin)
  }
}

///|
fn build_rule_graph(
  build_state : BuildState,
  rule : NormalizedRule,
) -> (BuildState, AtnRuleGraph) {
  let initial_state_id = build_state.next_state_id
  let initial_decision_id = build_state.next_decision_id
  let (build_state, start_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    RuleStartState,
    true,
    None,
    Some(rule_level_origin(rule)),
  )
  let (build_state, stop_state_id) = add_state(
    build_state,
    Some(rule.name),
    Some(rule.rule_id),
    mode_name_for_rule(rule),
    RuleStopState,
    true,
    None,
    Some(rule_level_origin(rule)),
  )
  let (build_state, alternatives_fragment) = build_alternative_set(
    build_state,
    rule,
    rule.alternatives,
    BlockStartState,
    BlockDecision,
    Some(rule_level_origin(rule)),
  )
  let build_state = add_transition(
    build_state,
    start_state_id,
    alternatives_fragment.start_state_id,
    EpsilonTransition,
    false,
    Some(rule_level_origin(rule)),
  )
  let build_state = add_transition(
    build_state,
    alternatives_fragment.stop_state_id,
    stop_state_id,
    EpsilonTransition,
    false,
    Some(rule_level_origin(rule)),
  )
  let state_ids : Array[Int] = []
  for state_id = initial_state_id
      state_id < build_state.next_state_id
      state_id = state_id + 1 {
    state_ids.push(state_id)
  }
  let decision_ids : Array[Int] = []
  for decision_id = initial_decision_id
      decision_id < build_state.next_decision_id
      decision_id = decision_id + 1 {
    decision_ids.push(decision_id)
  }
  (
    build_state,
    {
      rule_id: rule.rule_id,
      rule_name: rule.name,
      kind: rule.kind,
      mode: mode_name_for_rule(rule),
      signature: rule.signature,
      start_state_id,
      stop_state_id,
      state_ids,
      decision_ids,
      rewritten: rule.rewritten,
    },
  )
}

///|
fn find_rule_graph_by_id(
  rule_graphs : Array[AtnRuleGraph],
  rule_id : Int,
) -> AtnRuleGraph {
  for rule_graph in rule_graphs {
    if rule_graph.rule_id == rule_id {
      return rule_graph
    }
  }
  abort("expected ATN rule graph for rule id " + rule_id.to_string())
}

///|
fn build_mode_starts(
  build_state : BuildState,
  normalized : NormalizedGrammar,
  rule_graphs : Array[AtnRuleGraph],
) -> (BuildState, Array[AtnModeStart]) {
  if !atn_grammar_is_lexer(normalized.grammar_kind) {
    return (build_state, [])
  }
  let mut build_state = build_state
  let mode_starts : Array[AtnModeStart] = []
  for mode_symbol in normalized.semantic_model.modes {
    let rule_ids : Array[Int] = []
    for rule_graph in rule_graphs {
      if atn_rule_is_lexer(rule_graph.kind) {
        match rule_graph.mode {
          Some(mode_name) if mode_name == mode_symbol.name =>
            rule_ids.push(rule_graph.rule_id)
          _ => ()
        }
      }
    }
    if rule_ids.length() == 0 {
      continue
    }
    let (next_state, decision_id) = reserve_decision_id(build_state)
    build_state = next_state
    let (next_state, state_id) = add_state(
      build_state,
      None,
      None,
      Some(mode_symbol.name),
      ModeStartState,
      true,
      Some(decision_id),
      None,
    )
    build_state = next_state
    let public_alternatives : Array[NormalizedAlternativeOrigin?] = []
    for _ in rule_ids {
      public_alternatives.push(None)
    }
    build_state = record_decision(
      build_state,
      decision_id,
      None,
      None,
      state_id,
      ModeStartDecision,
      public_alternatives,
    )
    for rule_id in rule_ids {
      let rule_graph = find_rule_graph_by_id(rule_graphs, rule_id)
      build_state = add_transition(
        build_state,
        state_id,
        rule_graph.start_state_id,
        EpsilonTransition,
        false,
        None,
      )
    }
    mode_starts.push({ mode_name: mode_symbol.name, state_id, rule_ids })
  }
  (build_state, mode_starts)
}

///|
/// Return a stable diagnostic name for one ATN state kind.
///
/// Example:
/// inspect(atn_state_kind_name(RuleStartState), content="rule-start")
///
/// Notes:
/// - This is intended for diagnostics, tests, and serializer output.
/// - The returned name omits rule-specific metadata.
pub fn atn_state_kind_name(kind : AtnStateKind) -> String {
  match kind {
    RuleStartState => "rule-start"
    RuleStopState => "rule-stop"
    BasicState => "basic"
    BlockStartState => "block-start"
    BlockEndState => "block-end"
    PlusBlockStartState => "plus-block-start"
    StarBlockStartState => "star-block-start"
    LoopEntryState => "loop-entry"
    LoopBackState => "loop-back"
    LoopEndState => "loop-end"
    ModeStartState => "mode-start"
    RuleCallState => "rule-call"
  }
}

///|
/// Return a stable diagnostic name for one ATN decision kind.
///
/// Example:
/// inspect(atn_decision_kind_name(BlockDecision), content="block")
///
/// Notes:
/// - The returned name is stable for tests and serialization.
/// - Decision payloads remain on `AtnDecision` itself.
pub fn atn_decision_kind_name(kind : AtnDecisionKind) -> String {
  match kind {
    BlockDecision => "block"
    OptionalDecision => "optional"
    LoopEntryDecision => "loop-entry"
    LoopBackDecision => "loop-back"
    ModeStartDecision => "mode-start"
  }
}

///|
/// Return a stable diagnostic name for one ATN transition kind.
///
/// Example:
/// inspect(atn_transition_kind_name(EpsilonTransition), content="epsilon")
///
/// Notes:
/// - Payload details are intentionally omitted from the returned name.
/// - Use pattern matching on `AtnTransitionKind` when you need the original payload.
pub fn atn_transition_kind_name(kind : AtnTransitionKind) -> String {
  match kind {
    EpsilonTransition => "epsilon"
    RuleReferenceTransition(_) => "rule-ref"
    TokenReferenceTransition(_) => "token-ref"
    StringLiteralTransition(_) => "string"
    RangeTransition(_) => "range"
    CharSetTransition(_) => "charset"
    SetTransition(_) => "set"
    NotSetTransition(_) => "not-set"
    WildcardTransition => "wildcard"
    ActionTransition(_) => "action"
    PredicateTransition(_, _) => "predicate"
    PrecedenceTransition(_, _) => "precedence"
    LexerCommandTransition(_) => "lexer-command"
  }
}

///|
/// Find the rule graph for one rule name inside the grammar ATN.
///
/// Example:
/// let rule_graph = atn.find_rule("expr")
/// inspect(rule_graph is Some(_), content="true")
///
/// Notes:
/// - Returns `None` when the rule name is absent.
/// - Rule names are matched exactly and case-sensitively.
pub fn GrammarAtn::find_rule(
  self : GrammarAtn,
  rule_name : String,
) -> AtnRuleGraph? {
  for rule in self.rules {
    if rule.rule_name == rule_name {
      return Some(rule)
    }
  }
  None
}

///|
/// Find the rule graph for one numeric rule identifier.
///
/// Example:
/// let rule_graph = atn.rule_by_id(0)
/// inspect(rule_graph is Some(_), content="true")
///
/// Notes:
/// - Rule ids are local to one `GrammarAtn` instance.
/// - Returns `None` when the id is unknown.
pub fn GrammarAtn::rule_by_id(
  self : GrammarAtn,
  rule_id : Int,
) -> AtnRuleGraph? {
  for rule in self.rules {
    if rule.rule_id == rule_id {
      return Some(rule)
    }
  }
  None
}

///|
/// Resolve one ATN state by numeric identifier.
///
/// Example:
/// let state = atn.state(0)
/// inspect(state is Some(_), content="true")
///
/// Notes:
/// - State ids are local to one `GrammarAtn` instance.
/// - Returns `None` when the id is unknown.
pub fn GrammarAtn::state(self : GrammarAtn, state_id : Int) -> AtnState? {
  for state in self.states {
    if state.id == state_id {
      return Some(state)
    }
  }
  None
}

///|
/// Resolve one recorded ATN decision by numeric identifier.
///
/// Example:
/// let decision = atn.decision(0)
/// inspect(decision is Some(_), content="true")
///
/// Notes:
/// - Decision ids are local to one `GrammarAtn` instance.
/// - Returns `None` when the id is unknown.
pub fn GrammarAtn::decision(
  self : GrammarAtn,
  decision_id : Int,
) -> AtnDecision? {
  for decision in self.decisions {
    if decision.decision_id == decision_id {
      return Some(decision)
    }
  }
  None
}

///|
/// Resolve one mode start entry by exact lexer mode name.
///
/// Example:
/// let mode_start = atn.mode_start("DEFAULT_MODE")
/// inspect(mode_start is Some(_), content="true")
///
/// Notes:
/// - Mode names are matched exactly and case-sensitively.
/// - Returns `None` when the grammar has no such lexer mode start.
pub fn GrammarAtn::mode_start(
  self : GrammarAtn,
  mode_name : String,
) -> AtnModeStart? {
  for mode_start in self.mode_starts {
    if mode_start.mode_name == mode_name {
      return Some(mode_start)
    }
  }
  None
}

///|
/// Resolve stable token metadata by exact token name.
///
/// Example:
/// let token = atn.find_token("ID")
/// inspect(token is Some(_), content="true")
///
/// Notes:
/// - Token names are matched exactly and case-sensitively.
/// - Returns `None` when the token is absent from the public metadata.
pub fn GrammarAtn::find_token(
  self : GrammarAtn,
  token_name : String,
) -> GrammarTokenSymbol? {
  for token in self.public_tokens {
    if token.name == token_name {
      return Some(token)
    }
  }
  None
}

///|
/// Resolve stable channel metadata by exact channel name.
///
/// Example:
/// let channel = atn.find_channel("HIDDEN")
/// inspect(channel is Some(_), content="true")
///
/// Notes:
/// - Channel names are matched exactly and case-sensitively.
/// - Returns `None` when the channel is absent from the public metadata.
pub fn GrammarAtn::find_channel(
  self : GrammarAtn,
  channel_name : String,
) -> GrammarChannelSymbol? {
  for channel in self.public_channels {
    if channel.name == channel_name {
      return Some(channel)
    }
  }
  None
}

///|
/// Resolve stable lexer mode metadata by exact mode name.
///
/// Example:
/// let mode = atn.find_mode("DEFAULT_MODE")
/// inspect(mode is Some(_), content="true")
///
/// Notes:
/// - Mode names are matched exactly and case-sensitively.
/// - Returns `None` when the mode is absent from the public metadata.
pub fn GrammarAtn::find_mode(
  self : GrammarAtn,
  mode_name : String,
) -> GrammarModeSymbol? {
  for mode in self.public_modes {
    if mode.name == mode_name {
      return Some(mode)
    }
  }
  None
}

///|
/// Return all outgoing transitions from one state.
///
/// Example:
/// let transitions = atn.outgoing_transitions(rule_graph.start_state_id)
/// inspect(transitions.length() > 0, content="true")
///
/// Notes:
/// - The implementation preserves lowering order on `AtnTransition.order`.
/// - This method performs a linear scan and is intended for inspection, tests, and early runtime work.
pub fn GrammarAtn::outgoing_transitions(
  self : GrammarAtn,
  state_id : Int,
) -> Array[AtnTransition] {
  let transitions : Array[AtnTransition] = []
  for transition in self.transitions {
    if transition.source_state_id == state_id {
      transitions.push(transition)
    }
  }
  transitions
}

///|
/// Lower one normalized grammar into the Phase 1 ATN contract.
///
/// Example:
/// let atn = build_grammar_atn_from_normalized(normalized)
/// inspect(atn.rules.length() > 0, content="true")
///
/// Notes:
/// - The input must already carry stable public rule, alternative, and slot origins.
/// - The returned ATN is runtime-oriented; it is not wire-compatible with ANTLR's serialized ATN format.
pub fn build_grammar_atn_from_normalized(
  normalized : NormalizedGrammar,
) -> GrammarAtn {
  let mut build_state = empty_build_state(normalized.semantic_model)
  let rule_graphs : Array[AtnRuleGraph] = []
  for rule in normalized.rules {
    let (next_state, rule_graph) = build_rule_graph(build_state, rule)
    build_state = next_state
    rule_graphs.push(rule_graph)
  }
  let (build_state, mode_starts) = build_mode_starts(
    build_state, normalized, rule_graphs,
  )
  {
    grammar_name: normalized.grammar_name,
    grammar_kind: normalized.grammar_kind,
    grammar_fingerprint: normalized.grammar_fingerprint,
    start_rule_id: normalized.start_rule_id,
    states: build_state.states,
    transitions: build_state.transitions,
    rules: rule_graphs,
    decisions: build_state.decisions,
    mode_starts,
    public_rules: normalized.semantic_model.rules,
    public_alternatives: normalized.semantic_model.alternatives,
    public_slots: normalized.semantic_model.slots,
    public_tokens: normalized.semantic_model.tokens,
    public_channels: normalized.semantic_model.channels,
    public_modes: normalized.semantic_model.modes,
  }
}

///|
/// Lower the current parsed grammar subset into the Phase 1 ATN IR.
///
/// Example:
/// let grammar = expect_parsed("grammar Hello; r : 'x' ;")
/// let atn = build_grammar_atn(grammar)
/// inspect(atn.rules.length(), content="1")
///
/// Notes:
/// - This now routes through semantic analysis and normalization before ATN lowering.
/// - The function aborts when semantic analysis fails, because the Phase 1 ATN contract requires stable public metadata.
pub fn build_grammar_atn(grammar : GrammarSpec) -> GrammarAtn {
  let summary = analyze_grammar(grammar)
  if summary.diagnostics.length() != 0 {
    abort(
      "cannot build ATN with semantic errors: " + summary.diagnostics[0].message,
    )
  }
  match normalize_grammar(grammar, summary) {
    Some(normalized) => build_grammar_atn_from_normalized(normalized)
    None => abort("cannot build ATN without a normalized grammar")
  }
}
