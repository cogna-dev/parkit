///|
priv struct NormalizeState {
  next_runtime_alternative_id : Int
}

///|
/// Synthetic runtime-only nodes introduced by normalization.
pub(all) enum NormalizedSyntheticKind {
  LeftRecPrimaryGroup
  LeftRecOperatorGroup
  LeftRecPrecedencePredicate
  LeftRecOperatorLoop
}

///|
/// Public rule identity preserved across normalization and left-recursion rewrites.
pub struct NormalizedRuleOrigin {
  rule_id : Int
  rule_name : String
  declaring_grammar : String
}

///|
/// Public alternative identity preserved across normalization and left-recursion rewrites.
pub struct NormalizedAlternativeOrigin {
  rule_id : Int
  alternative_index : Int
  label : String?
}

///|
/// Public slot identity preserved across normalization and left-recursion rewrites.
pub struct NormalizedSlotOrigin {
  rule_id : Int
  alternative_index : Int
  slot_id : Int
  element_index : Int
  label : ElementLabel?
}

///|
/// Origin metadata attached to normalized elements.
pub struct NormalizedOrigin {
  rule : NormalizedRuleOrigin
  alternative : NormalizedAlternativeOrigin?
  slot : NormalizedSlotOrigin?
  synthetic_kind : NormalizedSyntheticKind?
}

///|
/// One normalized grammar element carrying public-origin metadata.
pub struct NormalizedElement {
  label : ElementLabel?
  negated : Bool
  kind : NormalizedElementKind
  suffix : EbnfSuffix?
  span : SourceSpan
  origin : NormalizedOrigin
}

///|
/// Element kinds preserved after normalization.
pub(all) enum NormalizedElementKind {
  RuleReferenceElement(RuleReference)
  TokenReferenceElement(String)
  StringLiteralElement(String)
  RangeElement(String)
  CharSetElement(String)
  WildcardElement
  GroupElement(Array[NormalizedAlternative])
  ActionElement(String)
  PredicateElement(String, String?)
}

///|
/// One normalized runtime alternative.
pub struct NormalizedAlternative {
  runtime_alternative_id : Int
  public_origin : NormalizedAlternativeOrigin?
  synthetic_kind : NormalizedSyntheticKind?
  elements : Array[NormalizedElement]
  commands : Array[LexerCommandSpec]
  span : SourceSpan
}

///|
/// One normalized rule ready for ATN lowering.
pub struct NormalizedRule {
  rule_id : Int
  name : String
  kind : GrammarRuleKind
  is_fragment : Bool
  signature : String?
  mode : String?
  public_origin : NormalizedRuleOrigin
  alternatives : Array[NormalizedAlternative]
  rewritten : Bool
}

///|
/// Stable normalization output for Phase 1 runtime and CST contracts.
pub struct NormalizedGrammar {
  grammar_name : String
  grammar_kind : GrammarKind
  grammar_fingerprint : String
  start_rule_id : Int?
  rewritten_rule_names : Array[String]
  semantic_model : SemanticModel
  rules : Array[NormalizedRule]
}

///|
fn empty_normalize_state() -> NormalizeState {
  { next_runtime_alternative_id: 0 }
}

///|
fn next_runtime_alternative_id(state : NormalizeState) -> (NormalizeState, Int) {
  let runtime_alternative_id = state.next_runtime_alternative_id
  (
    { next_runtime_alternative_id: runtime_alternative_id + 1 },
    runtime_alternative_id,
  )
}

///|
fn normalize_is_significant_element(element : GrammarElement) -> Bool {
  match element.kind {
    ActionElement(_) => false
    PredicateElement(_, _) => false
    _ => true
  }
}

///|
fn normalize_is_rule_self_reference(
  element : GrammarElement,
  rule_name : String,
) -> Bool {
  match element.kind {
    RuleReferenceElement(rule_ref) => rule_ref.name == rule_name
    _ => false
  }
}

///|
fn find_rule_symbol_or_abort(
  model : SemanticModel,
  rule_name : String,
) -> GrammarRuleSymbol {
  match model.find_rule(rule_name) {
    Some(rule) => rule
    None => abort("expected semantic rule symbol for `" + rule_name + "`")
  }
}

///|
fn find_slot_symbol_or_abort(
  model : SemanticModel,
  rule_id : Int,
  alternative_index : Int,
  element_index : Int,
) -> GrammarSlotSymbol {
  for slot in model.slots {
    if slot.rule_id == rule_id &&
      slot.alternative_index == alternative_index &&
      slot.element_index == element_index {
      return slot
    }
  }
  abort(
    "expected slot for rule_id=" +
    rule_id.to_string() +
    ", alt=" +
    alternative_index.to_string() +
    ", element=" +
    element_index.to_string(),
  )
}

///|
fn make_rule_origin(rule_symbol : GrammarRuleSymbol) -> NormalizedRuleOrigin {
  {
    rule_id: rule_symbol.rule_id,
    rule_name: rule_symbol.name,
    declaring_grammar: rule_symbol.declaring_grammar,
  }
}

///|
fn make_alternative_origin(
  rule_id : Int,
  alternative_index : Int,
  label : String?,
) -> NormalizedAlternativeOrigin {
  { rule_id, alternative_index, label }
}

///|
fn make_slot_origin(slot_symbol : GrammarSlotSymbol) -> NormalizedSlotOrigin {
  {
    rule_id: slot_symbol.rule_id,
    alternative_index: slot_symbol.alternative_index,
    slot_id: slot_symbol.slot_id,
    element_index: slot_symbol.element_index,
    label: slot_symbol.label,
  }
}

///|
fn make_origin(
  rule_origin : NormalizedRuleOrigin,
  alternative_origin : NormalizedAlternativeOrigin?,
  slot_origin : NormalizedSlotOrigin?,
  synthetic_kind : NormalizedSyntheticKind?,
) -> NormalizedOrigin {
  {
    rule: rule_origin,
    alternative: alternative_origin,
    slot: slot_origin,
    synthetic_kind,
  }
}

///|
fn find_rewrite_plan_by_rule_name(
  plans : Array[LeftRecursionRewritePlan],
  rule_name : String,
) -> LeftRecursionRewritePlan? {
  for plan in plans {
    if plan.rule_name == rule_name {
      return Some(plan)
    }
  }
  None
}

///|
fn operator_slot_sequence(
  original_rule : GrammarRuleSpec,
  rule_id : Int,
  alternative_index : Int,
  model : SemanticModel,
) -> Array[GrammarSlotSymbol] {
  let alternative = original_rule.alternatives[alternative_index - 1]
  let slots : Array[GrammarSlotSymbol] = []
  let mut stripped = false
  for element_index = 0
      element_index < alternative.elements.length()
      element_index = element_index + 1 {
    let element = alternative.elements[element_index]
    if !stripped &&
      normalize_is_significant_element(element) &&
      normalize_is_rule_self_reference(element, original_rule.name) {
      stripped = true
    } else {
      slots.push(
        find_slot_symbol_or_abort(
          model, rule_id, alternative_index, element_index,
        ),
      )
    }
  }
  slots
}

///|
fn normalize_nested_group_alternatives(
  state : NormalizeState,
  model : SemanticModel,
  rule_origin : NormalizedRuleOrigin,
  public_origin : NormalizedAlternativeOrigin,
  slot_origin : NormalizedSlotOrigin,
  alternatives : Array[GrammarAlternative],
) -> (NormalizeState, Array[NormalizedAlternative]) {
  let mut state = state
  let normalized : Array[NormalizedAlternative] = []
  for alternative in alternatives {
    let (next_state, runtime_alternative_id) = next_runtime_alternative_id(
      state,
    )
    state = next_state
    let (next_state, elements) = normalize_direct_elements(
      state,
      model,
      rule_origin,
      public_origin,
      Some(slot_origin),
      alternative.elements,
    )
    state = next_state
    normalized.push({
      runtime_alternative_id,
      public_origin: Some(public_origin),
      synthetic_kind: None,
      elements,
      commands: alternative.commands,
      span: alternative.span,
    })
  }
  (state, normalized)
}

///|
fn normalize_element_kind(
  state : NormalizeState,
  model : SemanticModel,
  rule_origin : NormalizedRuleOrigin,
  public_origin : NormalizedAlternativeOrigin,
  slot_origin : NormalizedSlotOrigin,
  element : GrammarElement,
) -> (NormalizeState, NormalizedElementKind) {
  match element.kind {
    RuleReferenceElement(rule_ref) => (state, RuleReferenceElement(rule_ref))
    TokenReferenceElement(name) => (state, TokenReferenceElement(name))
    StringLiteralElement(text) => (state, StringLiteralElement(text))
    RangeElement(text) => (state, RangeElement(text))
    CharSetElement(text) => (state, CharSetElement(text))
    WildcardElement => (state, WildcardElement)
    GroupElement(alternatives) => {
      let (next_state, normalized_alternatives) = normalize_nested_group_alternatives(
        state, model, rule_origin, public_origin, slot_origin, alternatives,
      )
      (next_state, GroupElement(normalized_alternatives))
    }
    ActionElement(text) => (state, ActionElement(text))
    PredicateElement(text, suffix) => (state, PredicateElement(text, suffix))
  }
}

///|
fn normalize_direct_elements(
  state : NormalizeState,
  model : SemanticModel,
  rule_origin : NormalizedRuleOrigin,
  public_origin : NormalizedAlternativeOrigin,
  inherited_slot_origin : NormalizedSlotOrigin?,
  elements : Array[GrammarElement],
) -> (NormalizeState, Array[NormalizedElement]) {
  let mut state = state
  let normalized : Array[NormalizedElement] = []
  for element_index = 0
      element_index < elements.length()
      element_index = element_index + 1 {
    let element = elements[element_index]
    let slot_origin = match inherited_slot_origin {
      Some(value) => value
      None =>
        make_slot_origin(
          find_slot_symbol_or_abort(
            model,
            rule_origin.rule_id,
            public_origin.alternative_index,
            element_index,
          ),
        )
    }
    let (next_state, kind) = normalize_element_kind(
      state, model, rule_origin, public_origin, slot_origin, element,
    )
    state = next_state
    normalized.push({
      label: element.label,
      negated: element.negated,
      kind,
      suffix: element.suffix,
      span: element.span,
      origin: make_origin(
        rule_origin,
        Some(public_origin),
        Some(slot_origin),
        None,
      ),
    })
  }
  (state, normalized)
}

///|
fn normalize_direct_elements_with_slot_map(
  state : NormalizeState,
  model : SemanticModel,
  rule_origin : NormalizedRuleOrigin,
  public_origin : NormalizedAlternativeOrigin,
  slot_map : Array[GrammarSlotSymbol],
  elements : Array[GrammarElement],
) -> (NormalizeState, Array[NormalizedElement]) {
  let mut state = state
  let normalized : Array[NormalizedElement] = []
  for index = 0; index < elements.length(); index = index + 1 {
    let element = elements[index]
    let slot_origin = make_slot_origin(slot_map[index])
    let (next_state, kind) = normalize_element_kind(
      state, model, rule_origin, public_origin, slot_origin, element,
    )
    state = next_state
    normalized.push({
      label: element.label,
      negated: element.negated,
      kind,
      suffix: element.suffix,
      span: element.span,
      origin: make_origin(
        rule_origin,
        Some(public_origin),
        Some(slot_origin),
        None,
      ),
    })
  }
  (state, normalized)
}

///|
fn normalize_plain_rule(
  state : NormalizeState,
  runtime_rule : GrammarRuleSpec,
  original_rule : GrammarRuleSpec,
  rule_symbol : GrammarRuleSymbol,
  model : SemanticModel,
) -> (NormalizeState, NormalizedRule) {
  let mut state = state
  let rule_origin = make_rule_origin(rule_symbol)
  let alternatives : Array[NormalizedAlternative] = []
  for alt_index = 0
      alt_index < runtime_rule.alternatives.length()
      alt_index = alt_index + 1 {
    let runtime_alternative = runtime_rule.alternatives[alt_index]
    let public_origin = make_alternative_origin(
      rule_symbol.rule_id,
      alt_index + 1,
      original_rule.alternatives[alt_index].label,
    )
    let slot_map : Array[GrammarSlotSymbol] = []
    for element_index = 0
        element_index < original_rule.alternatives[alt_index].elements.length()
        element_index = element_index + 1 {
      slot_map.push(
        find_slot_symbol_or_abort(
          model,
          rule_symbol.rule_id,
          alt_index + 1,
          element_index,
        ),
      )
    }
    let (next_state, runtime_alternative_id) = next_runtime_alternative_id(
      state,
    )
    state = next_state
    let (next_state, elements) = normalize_direct_elements_with_slot_map(
      state,
      model,
      rule_origin,
      public_origin,
      slot_map,
      runtime_alternative.elements,
    )
    state = next_state
    alternatives.push({
      runtime_alternative_id,
      public_origin: Some(public_origin),
      synthetic_kind: None,
      elements,
      commands: runtime_alternative.commands,
      span: runtime_alternative.span,
    })
  }
  (
    state,
    {
      rule_id: rule_symbol.rule_id,
      name: runtime_rule.name,
      kind: runtime_rule.kind,
      is_fragment: runtime_rule.is_fragment,
      signature: runtime_rule.signature,
      mode: runtime_rule.mode,
      public_origin: rule_origin,
      alternatives,
      rewritten: false,
    },
  )
}

///|
fn make_synthetic_group_element(
  rule_origin : NormalizedRuleOrigin,
  alternatives : Array[NormalizedAlternative],
  span : SourceSpan,
  suffix : EbnfSuffix?,
  synthetic_kind : NormalizedSyntheticKind,
) -> NormalizedElement {
  {
    label: None,
    negated: false,
    kind: GroupElement(alternatives),
    suffix,
    span,
    origin: make_origin(rule_origin, None, None, Some(synthetic_kind)),
  }
}

///|
fn make_synthetic_precedence_predicate(
  rule_origin : NormalizedRuleOrigin,
  public_origin : NormalizedAlternativeOrigin,
  precedence : Int,
  span : SourceSpan,
) -> NormalizedElement {
  {
    label: None,
    negated: false,
    kind: PredicateElement("{" + precedence.to_string() + " >= $p}", None),
    suffix: None,
    span,
    origin: make_origin(
      rule_origin,
      Some(public_origin),
      None,
      Some(LeftRecPrecedencePredicate),
    ),
  }
}

///|
fn normalize_rewritten_rule(
  state : NormalizeState,
  plan : LeftRecursionRewritePlan,
  original_rule : GrammarRuleSpec,
  rule_symbol : GrammarRuleSymbol,
  model : SemanticModel,
) -> (NormalizeState, NormalizedRule) {
  let mut state = state
  let rule_origin = make_rule_origin(rule_symbol)
  let primary_alternatives : Array[NormalizedAlternative] = []
  for primary in plan.primary_alternatives {
    let public_origin = make_alternative_origin(
      rule_symbol.rule_id,
      primary.original_alt_index,
      primary.label,
    )
    let slot_map : Array[GrammarSlotSymbol] = []
    let original_alternative = original_rule.alternatives[primary.original_alt_index -
      1]
    for element_index = 0
        element_index < original_alternative.elements.length()
        element_index = element_index + 1 {
      slot_map.push(
        find_slot_symbol_or_abort(
          model,
          rule_symbol.rule_id,
          primary.original_alt_index,
          element_index,
        ),
      )
    }
    let (next_state, runtime_alternative_id) = next_runtime_alternative_id(
      state,
    )
    state = next_state
    let (next_state, elements) = normalize_direct_elements_with_slot_map(
      state,
      model,
      rule_origin,
      public_origin,
      slot_map,
      primary.elements,
    )
    state = next_state
    primary_alternatives.push({
      runtime_alternative_id,
      public_origin: Some(public_origin),
      synthetic_kind: Some(LeftRecPrimaryGroup),
      elements,
      commands: [],
      span: primary.span,
    })
  }

  let operator_alternatives : Array[NormalizedAlternative] = []
  for operator_alt in plan.operator_alternatives {
    let public_origin = make_alternative_origin(
      rule_symbol.rule_id,
      operator_alt.original_alt_index,
      operator_alt.label,
    )
    let slot_map = operator_slot_sequence(
      original_rule,
      rule_symbol.rule_id,
      operator_alt.original_alt_index,
      model,
    )
    let (next_state, runtime_alternative_id) = next_runtime_alternative_id(
      state,
    )
    state = next_state
    let (next_state, operator_elements) = normalize_direct_elements_with_slot_map(
      state,
      model,
      rule_origin,
      public_origin,
      slot_map,
      operator_alt.elements,
    )
    state = next_state
    let elements : Array[NormalizedElement] = [
      make_synthetic_precedence_predicate(
        rule_origin,
        public_origin,
        operator_alt.precedence,
        operator_alt.span,
      ),
    ]
    for element in operator_elements {
      elements.push(element)
    }
    operator_alternatives.push({
      runtime_alternative_id,
      public_origin: Some(public_origin),
      synthetic_kind: Some(LeftRecOperatorGroup),
      elements,
      commands: [],
      span: operator_alt.span,
    })
  }

  let (state, runtime_alternative_id) = next_runtime_alternative_id(state)
  let top_level_alternative = {
    runtime_alternative_id,
    public_origin: None,
    synthetic_kind: Some(LeftRecOperatorLoop),
    elements: [
      make_synthetic_group_element(
        rule_origin,
        primary_alternatives,
        original_rule.span,
        None,
        LeftRecPrimaryGroup,
      ),
      make_synthetic_group_element(
        rule_origin,
        operator_alternatives,
        original_rule.span,
        Some({ kind: ZeroOrMoreSuffix, greedy: true }),
        LeftRecOperatorGroup,
      ),
    ],
    commands: [],
    span: original_rule.span,
  }
  (
    state,
    {
      rule_id: rule_symbol.rule_id,
      name: original_rule.name,
      kind: original_rule.kind,
      is_fragment: original_rule.is_fragment,
      signature: Some("[p]"),
      mode: original_rule.mode,
      public_origin: rule_origin,
      alternatives: [top_level_alternative],
      rewritten: true,
    },
  )
}

///|
/// Normalize the current grammar into the runtime-facing Phase 1 IR.
///
/// Example:
/// let summary = analyze_grammar(grammar)
/// let normalized = normalize_grammar(grammar, summary)
/// inspect(normalized is Some(_), content="true")
///
/// Notes:
/// - Returns `None` when the semantic summary does not carry a valid semantic model.
/// - Left-recursive rules are rewritten into a precedence-aware runtime surface while keeping public origins on original rules, alternatives, and slots.
pub fn normalize_grammar(
  grammar : GrammarSpec,
  summary : SemanticSummary,
) -> NormalizedGrammar? {
  let model = match summary.semantic_model {
    Some(value) => value
    None => return None
  }
  let rewrite_plans = plan_left_recursive_rewrites(grammar)
  let rewritten_rule_names : Array[String] = []
  for plan in rewrite_plans {
    rewritten_rule_names.push(plan.rule_name)
  }

  let mut state = empty_normalize_state()
  let rules : Array[NormalizedRule] = []
  for original_rule in grammar.rules {
    let runtime_rule = seed_precedence_arguments_in_rule(
      original_rule, rewritten_rule_names,
    )
    let rule_symbol = find_rule_symbol_or_abort(model, original_rule.name)
    match find_rewrite_plan_by_rule_name(rewrite_plans, original_rule.name) {
      Some(plan) => {
        let (next_state, normalized_rule) = normalize_rewritten_rule(
          state, plan, original_rule, rule_symbol, model,
        )
        state = next_state
        rules.push(normalized_rule)
      }
      None => {
        let (next_state, normalized_rule) = normalize_plain_rule(
          state, runtime_rule, original_rule, rule_symbol, model,
        )
        state = next_state
        rules.push(normalized_rule)
      }
    }
  }
  Some({
    grammar_name: grammar.name,
    grammar_kind: grammar.kind,
    grammar_fingerprint: model.grammar_fingerprint,
    start_rule_id: model.start_rule_id,
    rewritten_rule_names,
    semantic_model: model,
    rules,
  })
}

///|
/// Find one normalized rule by exact rule name.
///
/// Example:
/// let rule = normalized.find_rule("expr")
/// inspect(rule is Some(_), content="true")
///
/// Notes:
/// - Rule names are matched exactly and case-sensitively.
/// - Returns `None` when the normalized grammar does not contain the requested rule.
pub fn NormalizedGrammar::find_rule(
  self : NormalizedGrammar,
  rule_name : String,
) -> NormalizedRule? {
  for rule in self.rules {
    if rule.name == rule_name {
      return Some(rule)
    }
  }
  None
}
