///|
/// Associativity annotation extracted from <assoc=...>.
pub(all) enum OperatorAssociativity {
  LeftAssociative
  RightAssociative
}

///|
/// Classification used by the first left-recursion analysis pass.
pub(all) enum AlternativeRecursionKind {
  BinaryAlternative
  SuffixAlternative
  PrefixAlternative
  PrimaryAlternative
}

///|
/// Per-alternative classification result.
pub struct LeftRecursiveAlternativeInfo {
  alt_index : Int
  kind : AlternativeRecursionKind
  label : String?
  associativity : OperatorAssociativity?
  span : SourceSpan
}

///|
/// Rule-level left-recursion analysis result.
pub struct LeftRecursionAnalysis {
  rule_name : String
  has_immediate_left_recursion : Bool
  binary_alternatives : Array[LeftRecursiveAlternativeInfo]
  suffix_alternatives : Array[LeftRecursiveAlternativeInfo]
  prefix_alternatives : Array[LeftRecursiveAlternativeInfo]
  primary_alternatives : Array[LeftRecursiveAlternativeInfo]
}

///|
/// Rewritten primary-side alternative emitted by the left-recursion planner.
pub struct LeftRecursivePrimaryPlan {
  original_alt_index : Int
  source_kind : AlternativeRecursionKind
  label : String?
  rewritten_recursion_precedence : Int?
  elements : Array[GrammarElement]
  span : SourceSpan
}

///|
/// Rewritten operator-side alternative emitted by the left-recursion planner.
pub struct LeftRecursiveOperatorPlan {
  original_alt_index : Int
  source_kind : AlternativeRecursionKind
  label : String?
  associativity : OperatorAssociativity
  left_recursive_label : ElementLabel?
  precedence : Int
  next_precedence : Int?
  elements : Array[GrammarElement]
  span : SourceSpan
}

///|
/// Structured rewrite plan for a directly left-recursive rule.
pub struct LeftRecursionRewritePlan {
  rule_name : String
  precedence_argument_name : String
  primary_alternatives : Array[LeftRecursivePrimaryPlan]
  operator_alternatives : Array[LeftRecursiveOperatorPlan]
}

///|
/// Materialized synthetic rule produced from a left-recursion rewrite plan.
pub struct LeftRecursionMaterializedRule {
  rule_name : String
  synthetic_source : String
  rewritten_rule : GrammarRuleSpec?
  diagnostics : Array[Diagnostic]
}

///|
fn is_significant_element(element : GrammarElement) -> Bool {
  match element.kind {
    ActionElement(_) => false
    PredicateElement(_, _) => false
    _ => true
  }
}

///|
fn first_significant_element(
  elements : Array[GrammarElement],
) -> GrammarElement? {
  for element in elements {
    if is_significant_element(element) {
      return Some(element)
    }
  }
  None
}

///|
fn last_significant_element(
  elements : Array[GrammarElement],
) -> GrammarElement? {
  let mut index = elements.length() - 1
  while index >= 0 {
    let element = elements[index]
    if is_significant_element(element) {
      return Some(element)
    }
    index = index - 1
  }
  None
}

///|
fn is_rule_self_reference(element : GrammarElement, rule_name : String) -> Bool {
  match element.kind {
    RuleReferenceElement(rule_ref) => rule_ref.name == rule_name
    _ => false
  }
}

///|
fn alternative_associativity(
  alt : GrammarAlternative,
) -> OperatorAssociativity? {
  for option in alt.options {
    if option.name == "assoc" {
      if option.value == "right" {
        return Some(RightAssociative)
      }
      if option.value == "left" {
        return Some(LeftAssociative)
      }
    }
  }
  None
}

///|
fn default_associativity(
  assoc : OperatorAssociativity?,
) -> OperatorAssociativity {
  match assoc {
    Some(value) => value
    None => LeftAssociative
  }
}

///|
fn reverse_elements(values : Array[GrammarElement]) -> Array[GrammarElement] {
  let reversed : Array[GrammarElement] = []
  let mut index = values.length() - 1
  while index >= 0 {
    reversed.push(values[index])
    index = index - 1
  }
  reversed
}

///|
fn reverse_alternatives(
  values : Array[GrammarAlternative],
) -> Array[GrammarAlternative] {
  let reversed : Array[GrammarAlternative] = []
  let mut index = values.length() - 1
  while index >= 0 {
    reversed.push(values[index])
    index = index - 1
  }
  reversed
}

///|
fn precedence_for_alt(total_alts : Int, alt_index : Int) -> Int {
  total_alts - alt_index + 1
}

///|
fn next_precedence_for_alt(
  total_alts : Int,
  alt_index : Int,
  associativity : OperatorAssociativity,
) -> Int {
  let precedence = precedence_for_alt(total_alts, alt_index)
  match associativity {
    RightAssociative => precedence
    LeftAssociative => precedence + 1
  }
}

///|
fn with_precedence_arg(
  rule_ref : RuleReference,
  precedence : Int,
) -> RuleReference {
  { name: rule_ref.name, args: Some("[" + precedence.to_string() + "]") }
}

///|
fn rewrite_last_self_reference_in_element(
  element : GrammarElement,
  rule_name : String,
  precedence : Int,
) -> (GrammarElement, Bool) {
  match element.kind {
    RuleReferenceElement(rule_ref) if rule_ref.name == rule_name =>
      (
        {
          label: element.label,
          negated: element.negated,
          kind: RuleReferenceElement(with_precedence_arg(rule_ref, precedence)),
          suffix: element.suffix,
          span: element.span,
        },
        true,
      )
    GroupElement(alternatives) => {
      let rewritten_alts_reversed : Array[GrammarAlternative] = []
      let mut changed = false
      let mut index = alternatives.length() - 1
      while index >= 0 {
        let alt = alternatives[index]
        if changed {
          rewritten_alts_reversed.push(alt)
        } else {
          let (rewritten_elements, alt_changed) = rewrite_last_self_reference_in_elements(
            alt.elements,
            rule_name,
            precedence,
          )
          if alt_changed {
            rewritten_alts_reversed.push({
              options: alt.options,
              elements: rewritten_elements,
              label: alt.label,
              commands: alt.commands,
              span: alt.span,
            })
            changed = true
          } else {
            rewritten_alts_reversed.push(alt)
          }
        }
        index = index - 1
      }
      (
        {
          label: element.label,
          negated: element.negated,
          kind: GroupElement(reverse_alternatives(rewritten_alts_reversed)),
          suffix: element.suffix,
          span: element.span,
        },
        changed,
      )
    }
    _ => (element, false)
  }
}

///|
fn rewrite_last_self_reference_in_elements(
  elements : Array[GrammarElement],
  rule_name : String,
  precedence : Int,
) -> (Array[GrammarElement], Bool) {
  let rewritten_reversed : Array[GrammarElement] = []
  let mut changed = false
  let mut index = elements.length() - 1
  while index >= 0 {
    let element = elements[index]
    if changed {
      rewritten_reversed.push(element)
    } else {
      let (rewritten_element, changed_here) = rewrite_last_self_reference_in_element(
        element, rule_name, precedence,
      )
      rewritten_reversed.push(rewritten_element)
      changed = changed_here
    }
    index = index - 1
  }
  (reverse_elements(rewritten_reversed), changed)
}

///|
fn strip_immediate_left_recursion(
  elements : Array[GrammarElement],
  rule_name : String,
) -> (Array[GrammarElement], ElementLabel?) {
  let stripped : Array[GrammarElement] = []
  let mut removed = false
  let mut removed_label : ElementLabel? = None
  for element in elements {
    if !removed &&
      is_significant_element(element) &&
      is_rule_self_reference(element, rule_name) {
      removed = true
      removed_label = element.label
    } else {
      stripped.push(element)
    }
  }
  (stripped, removed_label)
}

///|
fn find_alt_info_by_index(
  analysis : LeftRecursionAnalysis,
  alt_index : Int,
) -> LeftRecursiveAlternativeInfo {
  for info in analysis.binary_alternatives {
    if info.alt_index == alt_index {
      return info
    }
  }
  for info in analysis.suffix_alternatives {
    if info.alt_index == alt_index {
      return info
    }
  }
  for info in analysis.prefix_alternatives {
    if info.alt_index == alt_index {
      return info
    }
  }
  for info in analysis.primary_alternatives {
    if info.alt_index == alt_index {
      return info
    }
  }
  abort("expected left-recursive alternative info")
}

///|
pub fn alternative_recursion_kind_name(
  kind : AlternativeRecursionKind,
) -> String {
  match kind {
    BinaryAlternative => "binary"
    SuffixAlternative => "suffix"
    PrefixAlternative => "prefix"
    PrimaryAlternative => "primary"
  }
}

///|
pub fn operator_associativity_name(assoc : OperatorAssociativity) -> String {
  match assoc {
    LeftAssociative => "left"
    RightAssociative => "right"
  }
}

///|
pub fn analyze_left_recursive_rule(
  rule : GrammarRuleSpec,
) -> LeftRecursionAnalysis {
  let binary_alternatives : Array[LeftRecursiveAlternativeInfo] = []
  let suffix_alternatives : Array[LeftRecursiveAlternativeInfo] = []
  let prefix_alternatives : Array[LeftRecursiveAlternativeInfo] = []
  let primary_alternatives : Array[LeftRecursiveAlternativeInfo] = []
  let mut has_immediate_left_recursion = false

  for index = 0; index < rule.alternatives.length(); index = index + 1 {
    let alt = rule.alternatives[index]
    let first_element = first_significant_element(alt.elements)
    let last_element = last_significant_element(alt.elements)
    let first_is_self = match first_element {
      Some(element) => is_rule_self_reference(element, rule.name)
      None => false
    }
    let last_is_self = match last_element {
      Some(element) => is_rule_self_reference(element, rule.name)
      None => false
    }
    let kind = if first_is_self && last_is_self {
      BinaryAlternative
    } else if first_is_self {
      SuffixAlternative
    } else if last_is_self {
      PrefixAlternative
    } else {
      PrimaryAlternative
    }
    if first_is_self {
      has_immediate_left_recursion = true
    }
    let info : LeftRecursiveAlternativeInfo = {
      alt_index: index + 1,
      kind,
      label: alt.label,
      associativity: alternative_associativity(alt),
      span: alt.span,
    }
    match kind {
      BinaryAlternative => binary_alternatives.push(info)
      SuffixAlternative => suffix_alternatives.push(info)
      PrefixAlternative => prefix_alternatives.push(info)
      PrimaryAlternative => primary_alternatives.push(info)
    }
  }

  {
    rule_name: rule.name,
    has_immediate_left_recursion,
    binary_alternatives,
    suffix_alternatives,
    prefix_alternatives,
    primary_alternatives,
  }
}

///|
pub fn analyze_left_recursive_rules(
  grammar : GrammarSpec,
) -> Array[LeftRecursionAnalysis] {
  let analyses : Array[LeftRecursionAnalysis] = []
  for rule in grammar.rules {
    match rule.kind {
      ParserRule => analyses.push(analyze_left_recursive_rule(rule))
      _ => ()
    }
  }
  analyses
}

///|
pub fn plan_left_recursive_rewrite(
  rule : GrammarRuleSpec,
) -> LeftRecursionRewritePlan? {
  let analysis = analyze_left_recursive_rule(rule)
  if !analysis.has_immediate_left_recursion {
    return None
  }

  let primary_alternatives : Array[LeftRecursivePrimaryPlan] = []
  let operator_alternatives : Array[LeftRecursiveOperatorPlan] = []
  let total_alts = rule.alternatives.length()

  for index = 0; index < rule.alternatives.length(); index = index + 1 {
    let alt_index = index + 1
    let alt = rule.alternatives[index]
    let info = find_alt_info_by_index(analysis, alt_index)
    match info.kind {
      PrefixAlternative => {
        let precedence = precedence_for_alt(total_alts, alt_index)
        let (rewritten_elements, _) = rewrite_last_self_reference_in_elements(
          alt.elements,
          rule.name,
          precedence,
        )
        primary_alternatives.push({
          original_alt_index: alt_index,
          source_kind: PrefixAlternative,
          label: info.label,
          rewritten_recursion_precedence: Some(precedence),
          elements: rewritten_elements,
          span: alt.span,
        })
      }
      PrimaryAlternative =>
        primary_alternatives.push({
          original_alt_index: alt_index,
          source_kind: PrimaryAlternative,
          label: info.label,
          rewritten_recursion_precedence: None,
          elements: alt.elements,
          span: alt.span,
        })
      BinaryAlternative => {
        let associativity = default_associativity(info.associativity)
        let precedence = precedence_for_alt(total_alts, alt_index)
        let next_precedence = next_precedence_for_alt(
          total_alts, alt_index, associativity,
        )
        let (stripped_elements, left_recursive_label) = strip_immediate_left_recursion(
          alt.elements,
          rule.name,
        )
        let (rewritten_elements, _) = rewrite_last_self_reference_in_elements(
          stripped_elements,
          rule.name,
          next_precedence,
        )
        operator_alternatives.push({
          original_alt_index: alt_index,
          source_kind: BinaryAlternative,
          label: info.label,
          associativity,
          left_recursive_label,
          precedence,
          next_precedence: Some(next_precedence),
          elements: rewritten_elements,
          span: alt.span,
        })
      }
      SuffixAlternative => {
        let associativity = default_associativity(info.associativity)
        let precedence = precedence_for_alt(total_alts, alt_index)
        let (stripped_elements, left_recursive_label) = strip_immediate_left_recursion(
          alt.elements,
          rule.name,
        )
        operator_alternatives.push({
          original_alt_index: alt_index,
          source_kind: SuffixAlternative,
          label: info.label,
          associativity,
          left_recursive_label,
          precedence,
          next_precedence: None,
          elements: stripped_elements,
          span: alt.span,
        })
      }
    }
  }

  Some({
    rule_name: rule.name,
    precedence_argument_name: "p",
    primary_alternatives,
    operator_alternatives,
  })
}

///|
pub fn plan_left_recursive_rewrites(
  grammar : GrammarSpec,
) -> Array[LeftRecursionRewritePlan] {
  let plans : Array[LeftRecursionRewritePlan] = []
  for rule in grammar.rules {
    match rule.kind {
      ParserRule =>
        match plan_left_recursive_rewrite(rule) {
          Some(plan) => plans.push(plan)
          None => ()
        }
      _ => ()
    }
  }
  plans
}

///|
fn render_ebnf_suffix(suffix : EbnfSuffix?) -> String {
  match suffix {
    Some(value) => {
      let base = match value.kind {
        OptionalSuffix => "?"
        ZeroOrMoreSuffix => "*"
        OneOrMoreSuffix => "+"
      }
      if value.greedy {
        base
      } else {
        base + "?"
      }
    }
    None => ""
  }
}

///|
fn render_element_label(label : ElementLabel?) -> String {
  match label {
    Some(value) => value.name + (if value.is_list { "+=" } else { "=" })
    None => ""
  }
}

///|
fn render_elements_inline(elements : Array[GrammarElement]) -> String {
  let mut rendered = ""
  let mut first = true
  for element in elements {
    let piece = render_grammar_element(element)
    if first {
      first = false
      rendered = piece
    } else {
      rendered = rendered + " " + piece
    }
  }
  rendered
}

///|
fn render_group_alternatives_inline(
  alternatives : Array[GrammarAlternative],
) -> String {
  let mut rendered = ""
  let mut first = true
  for alternative in alternatives {
    let piece = render_elements_inline(alternative.elements)
    if first {
      first = false
      rendered = piece
    } else {
      rendered = rendered + " | " + piece
    }
  }
  rendered
}

///|
fn render_grammar_element(element : GrammarElement) -> String {
  let base = match element.kind {
    RuleReferenceElement(rule_ref) =>
      rule_ref.name +
      (match rule_ref.args {
        Some(args) => args
        None => ""
      })
    TokenReferenceElement(name) => name
    StringLiteralElement(text) => text
    RangeElement(text) => text
    CharSetElement(text) => text
    WildcardElement => "."
    GroupElement(alternatives) =>
      "(" + render_group_alternatives_inline(alternatives) + ")"
    ActionElement(text) => text
    PredicateElement(text, suffix) =>
      text +
      "?" +
      (match suffix {
        Some(raw_suffix) => raw_suffix
        None => ""
      })
  }
  let labeled = render_element_label(element.label) + base
  let negated = if element.negated { "~" + labeled } else { labeled }
  negated + render_ebnf_suffix(element.suffix)
}

///|
fn render_plan_alternatives(texts : Array[String]) -> String {
  if texts.length() == 0 {
    return "()"
  }
  let mut rendered = "(" + texts[0]
  let mut index = 1
  while index < texts.length() {
    rendered = rendered + "\n    | " + texts[index]
    index = index + 1
  }
  rendered + ")"
}

///|
pub fn render_left_recursion_rewrite_rule(
  plan : LeftRecursionRewritePlan,
) -> String {
  let primary_texts : Array[String] = []
  for alternative in plan.primary_alternatives {
    primary_texts.push(render_elements_inline(alternative.elements))
  }
  let operator_texts : Array[String] = []
  for alternative in plan.operator_alternatives {
    operator_texts.push(
      "{" +
      alternative.precedence.to_string() +
      " >= $" +
      plan.precedence_argument_name +
      "}? " +
      render_elements_inline(alternative.elements),
    )
  }
  let mut rendered = plan.rule_name +
    "[" +
    plan.precedence_argument_name +
    "]\n  : " +
    render_plan_alternatives(primary_texts)
  if operator_texts.length() > 0 {
    rendered = rendered +
      "\n    " +
      render_plan_alternatives(operator_texts) +
      "*"
  }
  rendered + "\n  ;"
}

///|
pub fn materialize_left_recursion_rewrite_plan(
  plan : LeftRecursionRewritePlan,
) -> LeftRecursionMaterializedRule {
  let synthetic_source = render_left_recursion_rewrite_rule(plan)
  let outcome = parse_grammar(
    "grammar Synthetic;\n\n" + synthetic_source + "\n",
  )
  let rewritten_rule = match outcome.grammar {
    Some(grammar) if grammar.rules.length() > 0 => Some(grammar.rules[0])
    _ => None
  }
  {
    rule_name: plan.rule_name,
    synthetic_source,
    rewritten_rule,
    diagnostics: outcome.diagnostics,
  }
}

///|
pub fn materialize_left_recursion_rewrites(
  grammar : GrammarSpec,
) -> Array[LeftRecursionMaterializedRule] {
  let materialized : Array[LeftRecursionMaterializedRule] = []
  for plan in plan_left_recursive_rewrites(grammar) {
    materialized.push(materialize_left_recursion_rewrite_plan(plan))
  }
  materialized
}

///|
fn contains_rule_name(names : Array[String], target : String) -> Bool {
  for name in names {
    if name == target {
      return true
    }
  }
  false
}

///|
fn seeded_rule_reference(
  rule_ref : RuleReference,
  rewritten_rule_names : Array[String],
) -> RuleReference {
  if contains_rule_name(rewritten_rule_names, rule_ref.name) {
    match rule_ref.args {
      Some(_) => rule_ref
      None => { name: rule_ref.name, args: Some("[0]") }
    }
  } else {
    rule_ref
  }
}

///|
fn seed_precedence_arguments_in_element(
  element : GrammarElement,
  rewritten_rule_names : Array[String],
) -> GrammarElement {
  let kind = match element.kind {
    RuleReferenceElement(rule_ref) =>
      GrammarElementKind::RuleReferenceElement(
        seeded_rule_reference(rule_ref, rewritten_rule_names),
      )
    GroupElement(alternatives) =>
      GrammarElementKind::GroupElement(
        seed_precedence_arguments_in_alternatives(
          alternatives, rewritten_rule_names,
        ),
      )
    _ => element.kind
  }
  {
    label: element.label,
    negated: element.negated,
    kind,
    suffix: element.suffix,
    span: element.span,
  }
}

///|
fn seed_precedence_arguments_in_alternatives(
  alternatives : Array[GrammarAlternative],
  rewritten_rule_names : Array[String],
) -> Array[GrammarAlternative] {
  let rewritten_alternatives : Array[GrammarAlternative] = []
  for alternative in alternatives {
    let rewritten_elements : Array[GrammarElement] = []
    for element in alternative.elements {
      rewritten_elements.push(
        seed_precedence_arguments_in_element(element, rewritten_rule_names),
      )
    }
    rewritten_alternatives.push({
      options: alternative.options,
      elements: rewritten_elements,
      label: alternative.label,
      commands: alternative.commands,
      span: alternative.span,
    })
  }
  rewritten_alternatives
}

///|
fn seed_precedence_arguments_in_rule(
  rule : GrammarRuleSpec,
  rewritten_rule_names : Array[String],
) -> GrammarRuleSpec {
  {
    name: rule.name,
    kind: rule.kind,
    is_fragment: rule.is_fragment,
    signature: rule.signature,
    mode: rule.mode,
    alternatives: seed_precedence_arguments_in_alternatives(
      rule.alternatives,
      rewritten_rule_names,
    ),
    trailers: rule.trailers,
    span: rule.span,
  }
}

///|
fn find_materialized_rewritten_rule(
  materialized_rules : Array[LeftRecursionMaterializedRule],
  rule_name : String,
) -> GrammarRuleSpec? {
  for materialized_rule in materialized_rules {
    if materialized_rule.rule_name == rule_name {
      return materialized_rule.rewritten_rule
    }
  }
  None
}

///|
pub fn rewrite_left_recursive_grammar(grammar : GrammarSpec) -> GrammarSpec? {
  let materialized_rules = materialize_left_recursion_rewrites(grammar)
  if materialized_rules.length() == 0 {
    return None
  }

  let rewritten_rule_names : Array[String] = []
  for materialized_rule in materialized_rules {
    if materialized_rule.rewritten_rule is None {
      return None
    }
    rewritten_rule_names.push(materialized_rule.rule_name)
  }

  let rewritten_rules : Array[GrammarRuleSpec] = []
  for rule in grammar.rules {
    match find_materialized_rewritten_rule(materialized_rules, rule.name) {
      Some(rewritten_rule) => rewritten_rules.push(rewritten_rule)
      None => rewritten_rules.push(rule)
    }
  }

  let seeded_rules : Array[GrammarRuleSpec] = []
  for rule in rewritten_rules {
    seeded_rules.push(
      seed_precedence_arguments_in_rule(rule, rewritten_rule_names),
    )
  }

  Some({
    kind: grammar.kind,
    name: grammar.name,
    imports: grammar.imports,
    options: grammar.options,
    token_names: grammar.token_names,
    channel_names: grammar.channel_names,
    named_actions: grammar.named_actions,
    modes: grammar.modes,
    rules: seeded_rules,
    span: grammar.span,
  })
}
