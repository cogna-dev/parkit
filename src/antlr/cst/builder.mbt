///|
priv struct BuilderSlotCount {
  slot_id : Int
  count : Int
}

///|
priv struct BuilderPendingChild {
  child_id : CstNodeId
  recovered : Bool
}

///|
priv struct BuilderRuleFrame {
  node_id : CstNodeId
  rule : CstRuleRef
  alternative : CstAlternativeRef?
  ordered_slots : Array[@antlr.GrammarSlotSymbol]
  slot_counts : Array[BuilderSlotCount]
  last_element_index : Int
  last_slot_id : Int?
  pending_children : Array[BuilderPendingChild]
}

///|
fn cst_public_rule_ref(atn : @antlr.GrammarAtn, rule_id : Int) -> CstRuleRef? {
  for rule in atn.public_rules {
    if rule.rule_id == rule_id {
      return Some({
        rule_id: rule.rule_id,
        rule_name: rule.name,
        declaring_grammar: rule.declaring_grammar,
      })
    }
  }
  None
}

///|
fn cst_public_alternative_ref(
  atn : @antlr.GrammarAtn,
  rule : CstRuleRef,
  alternative_index : Int,
) -> CstAlternativeRef? {
  for alternative in atn.public_alternatives {
    if alternative.rule_id == rule.rule_id &&
      alternative.alternative_index == alternative_index {
      return Some({
        rule,
        alternative_index,
        alternative_label: alternative.label,
      })
    }
  }
  None
}

///|
fn cst_slot_source_kind_from_public(
  kind : @antlr.GrammarSlotSourceKind,
) -> CstSlotSourceKind {
  match kind {
    @antlr.RuleReferenceSlot(name) => RuleRef(name)
    @antlr.TokenReferenceSlot(name) => TokenRef(name)
    @antlr.StringLiteralSlot(text) => Literal(text)
    @antlr.RangeSlot(text) => Range(text)
    @antlr.CharSetSlot(text) => CharSet(text)
    @antlr.WildcardSlot => Wildcard
    @antlr.GroupSlot => Group
    @antlr.ActionSlot => Action
    @antlr.PredicateSlot => Predicate
  }
}

///|
fn cst_public_slot_ref(
  atn : @antlr.GrammarAtn,
  alternative : CstAlternativeRef,
  slot_id : Int,
) -> CstSlotRef? {
  for slot in atn.public_slots {
    if slot.rule_id == alternative.rule.rule_id &&
      slot.alternative_index == alternative.alternative_index &&
      slot.slot_id == slot_id {
      return Some({
        alternative,
        slot_id: slot.slot_id,
        element_index: slot.element_index,
        label: match slot.label {
          Some(label) => Some(label.name)
          None => None
        },
        source_kind: cst_slot_source_kind_from_public(slot.source_kind),
      })
    }
  }
  None
}

///|
fn cst_public_slots_for_alternative(
  atn : @antlr.GrammarAtn,
  alternative : CstAlternativeRef,
) -> Array[@antlr.GrammarSlotSymbol] {
  let slots : Array[@antlr.GrammarSlotSymbol] = []
  for slot in atn.public_slots {
    if slot.rule_id == alternative.rule.rule_id &&
      slot.alternative_index == alternative.alternative_index {
      slots.push(slot)
    }
  }
  slots
}

///|
fn cst_find_slot_symbol(
  ordered_slots : Array[@antlr.GrammarSlotSymbol],
  slot_id : Int,
) -> @antlr.GrammarSlotSymbol? {
  for slot in ordered_slots {
    if slot.slot_id == slot_id {
      return Some(slot)
    }
  }
  None
}

///|
fn cst_slot_is_repeatable(slot : @antlr.GrammarSlotSymbol) -> Bool {
  match slot.suffix {
    Some(suffix) =>
      match suffix.kind {
        @antlr.ZeroOrMoreSuffix => true
        @antlr.OneOrMoreSuffix => true
        _ => false
      }
    None => false
  }
}

///|
fn cst_slot_matches_rule_name(
  slot : @antlr.GrammarSlotSymbol,
  rule_name : String,
) -> Bool {
  match slot.source_kind {
    @antlr.RuleReferenceSlot(name) => name == rule_name
    _ => false
  }
}

///|
fn cst_copy_slot_counts(
  values : Array[BuilderSlotCount],
) -> Array[BuilderSlotCount] {
  let copied : Array[BuilderSlotCount] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn cst_copy_pending_children(
  values : Array[BuilderPendingChild],
) -> Array[BuilderPendingChild] {
  let copied : Array[BuilderPendingChild] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn cst_slot_occurrence_count(frame : BuilderRuleFrame, slot_id : Int) -> Int {
  for count in frame.slot_counts {
    if count.slot_id == slot_id {
      return count.count
    }
  }
  0
}

///|
fn cst_increment_slot_occurrence(
  counts : Array[BuilderSlotCount],
  slot_id : Int,
) -> Int {
  for index = 0; index < counts.length(); index = index + 1 {
    if counts[index].slot_id == slot_id {
      let occurrence_index = counts[index].count
      counts[index] = { slot_id, count: occurrence_index + 1 }
      return occurrence_index
    }
  }
  counts.push({ slot_id, count: 1 })
  0
}

///|
fn cst_builder_record_slot_use(
  frame : BuilderRuleFrame,
  slot : @antlr.GrammarSlotSymbol,
) -> (BuilderRuleFrame, Int) {
  let counts = cst_copy_slot_counts(frame.slot_counts)
  let occurrence_index = cst_increment_slot_occurrence(counts, slot.slot_id)
  (
    {
      node_id: frame.node_id,
      rule: frame.rule,
      alternative: frame.alternative,
      ordered_slots: frame.ordered_slots,
      slot_counts: counts,
      last_element_index: slot.element_index,
      last_slot_id: Some(slot.slot_id),
      pending_children: frame.pending_children,
    },
    occurrence_index,
  )
}

///|
fn cst_builder_choose_rule_slot(
  frame : BuilderRuleFrame,
  child_rule_name : String,
) -> @antlr.GrammarSlotSymbol? {
  match frame.last_slot_id {
    Some(last_slot_id) =>
      match cst_find_slot_symbol(frame.ordered_slots, last_slot_id) {
        Some(last_slot) =>
          if last_slot.element_index == frame.last_element_index &&
            cst_slot_is_repeatable(last_slot) &&
            cst_slot_matches_rule_name(last_slot, child_rule_name) {
            return Some(last_slot)
          }
        None => ()
      }
    None => ()
  }
  for slot in frame.ordered_slots {
    if !cst_slot_matches_rule_name(slot, child_rule_name) {
      continue
    }
    if slot.element_index < frame.last_element_index {
      continue
    }
    if cst_slot_occurrence_count(frame, slot.slot_id) == 0 {
      return Some(slot)
    }
    if cst_slot_is_repeatable(slot) &&
      slot.element_index == frame.last_element_index &&
      frame.last_slot_id == Some(slot.slot_id) {
      return Some(slot)
    }
  }
  None
}

///|
fn cst_token_matches_slot(
  slot : @antlr.GrammarSlotSymbol,
  token : CstTokenRecord,
) -> Bool {
  match slot.source_kind {
    @antlr.TokenReferenceSlot(name) => token.symbolic_name == Some(name)
    @antlr.StringLiteralSlot(text) => token.literal_name == Some(text)
    @antlr.GroupSlot => true
    @antlr.WildcardSlot => true
    _ => false
  }
}

///|
fn cst_builder_choose_token_slot(
  frame : BuilderRuleFrame,
  token : CstTokenRecord,
  slot_id : Int?,
) -> @antlr.GrammarSlotSymbol? {
  match slot_id {
    Some(explicit_slot_id) =>
      match cst_find_slot_symbol(frame.ordered_slots, explicit_slot_id) {
        Some(slot) => return Some(slot)
        None => ()
      }
    None => ()
  }
  match frame.last_slot_id {
    Some(last_slot_id) =>
      match cst_find_slot_symbol(frame.ordered_slots, last_slot_id) {
        Some(last_slot) =>
          if last_slot.element_index == frame.last_element_index &&
            cst_slot_is_repeatable(last_slot) &&
            cst_token_matches_slot(last_slot, token) {
            return Some(last_slot)
          }
        None => ()
      }
    None => ()
  }
  for slot in frame.ordered_slots {
    if !cst_token_matches_slot(slot, token) {
      continue
    }
    if slot.element_index < frame.last_element_index {
      continue
    }
    if cst_slot_occurrence_count(frame, slot.slot_id) == 0 {
      return Some(slot)
    }
    if cst_slot_is_repeatable(slot) &&
      slot.element_index == frame.last_element_index &&
      frame.last_slot_id == Some(slot.slot_id) {
      return Some(slot)
    }
  }
  None
}

///|
fn cst_channel_id_for_token(
  atn : @antlr.GrammarAtn,
  channel_name : String,
) -> Int {
  match atn.find_channel(channel_name) {
    Some(channel) => channel.channel_id
    None =>
      if channel_name == "DEFAULT_TOKEN_CHANNEL" {
        0
      } else if channel_name == "HIDDEN" {
        1
      } else {
        -1
      }
  }
}

///|
fn cst_token_record_from_lexer_token(
  atn : @antlr.GrammarAtn,
  token : @antlr_runtime.LexerToken,
) -> CstTokenRecord {
  let public_token = atn.find_token(token.token_name)
  {
    id: CstTokenId(token.token_index),
    token_kind_id: token.token_id,
    symbolic_name: match public_token {
      Some(value) => Some(value.name)
      None => Some(token.token_name)
    },
    literal_name: match public_token {
      Some(value) => value.literal_name
      None => None
    },
    channel: cst_channel_id_for_token(atn, token.channel_name),
    channel_name: token.channel_name,
    mode: Some(token.start_mode_name),
    lexeme: token.text,
    span: token.span,
    synthetic: false,
    implicit_literal: token.implicit,
    eof: token.is_eof,
  }
}

///|
fn cst_build_token_records(
  atn : @antlr.GrammarAtn,
  tokens : Array[@antlr_runtime.LexerToken],
) -> Array[CstTokenRecord] {
  let records : Array[CstTokenRecord] = []
  for token in tokens {
    records.push(cst_token_record_from_lexer_token(atn, token))
  }
  records
}

///|
fn cst_push_node(nodes : Array[CstNode], node : CstNode) -> CstNodeId {
  let node_id = CstNodeId(nodes.length())
  nodes.push(node)
  node_id
}

///|
fn cst_rule_node_or_abort(
  nodes : Array[CstNode],
  node_id : CstNodeId,
) -> CstRuleNode {
  match nodes[node_id.0] {
    Rule(rule_node) => rule_node
    _ => abort("expected rule node " + node_id.0.to_string())
  }
}

///|
fn cst_node_span_internal(
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  node_id : CstNodeId,
) -> @antlr.SourceSpan {
  match nodes[node_id.0] {
    Rule(rule_node) => rule_node.span
    Token(token_node) => tokens[token_node.token.0].span
    Error(error_node) => error_node.span
  }
}

///|
fn cst_span_cover(
  left : @antlr.SourceSpan,
  right : @antlr.SourceSpan,
) -> @antlr.SourceSpan {
  @antlr.SourceSpan::new(left.start, right.end)
}

///|
fn cst_span_for_attached_children(
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  children : Array[CstChildEdge],
  fallback : @antlr.SourceSpan,
) -> @antlr.SourceSpan {
  if children.length() == 0 {
    return fallback
  }
  let mut span = cst_node_span_internal(nodes, tokens, children[0].child)
  for index = 1; index < children.length(); index = index + 1 {
    span = cst_span_cover(
      span,
      cst_node_span_internal(nodes, tokens, children[index].child),
    )
  }
  span
}

///|
fn cst_span_for_pending_children(
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  pending_children : Array[BuilderPendingChild],
  fallback : @antlr.SourceSpan,
) -> @antlr.SourceSpan {
  if pending_children.length() == 0 {
    return fallback
  }
  let mut span = cst_node_span_internal(
    nodes,
    tokens,
    pending_children[0].child_id,
  )
  for index = 1; index < pending_children.length(); index = index + 1 {
    span = cst_span_cover(
      span,
      cst_node_span_internal(nodes, tokens, pending_children[index].child_id),
    )
  }
  span
}

///|
fn cst_node_recovered(nodes : Array[CstNode], node_id : CstNodeId) -> Bool {
  match nodes[node_id.0] {
    Rule(rule_node) => rule_node.recovered
    Error(_) => true
    Token(_) => false
  }
}

///|
fn cst_store_rule_node(
  nodes : Array[CstNode],
  node_id : CstNodeId,
  rule_node : CstRuleNode,
) -> Unit {
  nodes[node_id.0] = Rule(rule_node)
}

///|
fn cst_mark_rule_node_recovered(
  nodes : Array[CstNode],
  node_id : CstNodeId,
) -> Unit {
  let rule_node = cst_rule_node_or_abort(nodes, node_id)
  cst_store_rule_node(nodes, node_id, {
    rule: rule_node.rule,
    alternative: rule_node.alternative,
    span: rule_node.span,
    children: rule_node.children,
    recovered: true,
  })
}

///|
fn cst_add_child_edge(
  nodes : Array[CstNode],
  parent_id : CstNodeId,
  edge : CstChildEdge,
) -> Unit {
  let rule_node = cst_rule_node_or_abort(nodes, parent_id)
  let children = cst_copy_child_edges(rule_node.children)
  children.push(edge)
  cst_store_rule_node(nodes, parent_id, {
    rule: rule_node.rule,
    alternative: rule_node.alternative,
    span: rule_node.span,
    children,
    recovered: rule_node.recovered || edge.recovered,
  })
}

///|
fn cst_builder_buffer_child(
  frame : BuilderRuleFrame,
  child_id : CstNodeId,
  recovered : Bool,
) -> BuilderRuleFrame {
  let pending_children = cst_copy_pending_children(frame.pending_children)
  pending_children.push({ child_id, recovered })
  {
    node_id: frame.node_id,
    rule: frame.rule,
    alternative: frame.alternative,
    ordered_slots: frame.ordered_slots,
    slot_counts: frame.slot_counts,
    last_element_index: frame.last_element_index,
    last_slot_id: frame.last_slot_id,
    pending_children,
  }
}

///|
fn cst_builder_attach_child_with_slot_symbol(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  frame : BuilderRuleFrame,
  slot_symbol : @antlr.GrammarSlotSymbol,
  child_id : CstNodeId,
  recovered : Bool,
) -> Result[BuilderRuleFrame, String] {
  let alternative = match frame.alternative {
    Some(value) => value
    None => return Err("missing committed alternative before attaching child")
  }
  let slot_ref = match
    cst_public_slot_ref(atn, alternative, slot_symbol.slot_id) {
    Some(value) => value
    None =>
      return Err(
        "missing public slot metadata for rule `" +
        frame.rule.rule_name +
        "` slot " +
        slot_symbol.slot_id.to_string(),
      )
  }
  let (updated_frame, occurrence_index) = cst_builder_record_slot_use(
    frame, slot_symbol,
  )
  cst_add_child_edge(nodes, frame.node_id, {
    child: child_id,
    slot: slot_ref,
    occurrence_index,
    recovered,
  })
  Ok(updated_frame)
}

///|
fn cst_mark_parent_edge_recovered(
  nodes : Array[CstNode],
  parent_id : CstNodeId,
  child_id : CstNodeId,
) -> Unit {
  let rule_node = cst_rule_node_or_abort(nodes, parent_id)
  let children = cst_copy_child_edges(rule_node.children)
  for index = 0; index < children.length(); index = index + 1 {
    if children[index].child.0 == child_id.0 {
      let edge = children[index]
      children[index] = {
        child: edge.child,
        slot: edge.slot,
        occurrence_index: edge.occurrence_index,
        recovered: true,
      }
    }
  }
  cst_store_rule_node(nodes, parent_id, {
    rule: rule_node.rule,
    alternative: rule_node.alternative,
    span: rule_node.span,
    children,
    recovered: true,
  })
}

///|
fn cst_builder_apply_alternative(
  atn : @antlr.GrammarAtn,
  frame : BuilderRuleFrame,
  alternative : CstAlternativeRef,
) -> BuilderRuleFrame {
  {
    node_id: frame.node_id,
    rule: frame.rule,
    alternative: Some(alternative),
    ordered_slots: cst_public_slots_for_alternative(atn, alternative),
    slot_counts: frame.slot_counts,
    last_element_index: frame.last_element_index,
    last_slot_id: frame.last_slot_id,
    pending_children: frame.pending_children,
  }
}

///|
fn cst_builder_ensure_alternative_from_index(
  atn : @antlr.GrammarAtn,
  frame : BuilderRuleFrame,
  alternative_index : Int,
) -> Result[BuilderRuleFrame, String] {
  match frame.alternative {
    Some(_) => Ok(frame)
    None =>
      match cst_public_alternative_ref(atn, frame.rule, alternative_index) {
        Some(alternative) =>
          Ok(cst_builder_apply_alternative(atn, frame, alternative))
        None =>
          Err(
            "missing public alternative metadata for rule `" +
            frame.rule.rule_name +
            "` alt " +
            alternative_index.to_string(),
          )
      }
  }
}

///|
fn cst_builder_attach_rule_child(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  parent_frame : BuilderRuleFrame,
  child_id : CstNodeId,
  child_rule_name : String,
  recovered : Bool,
) -> Result[BuilderRuleFrame, String] {
  match parent_frame.alternative {
    Some(_) => ()
    None =>
      return Err(
        "missing committed alternative before entering child rule `" +
        child_rule_name +
        "` under `" +
        parent_frame.rule.rule_name +
        "`",
      )
  }
  let slot_symbol = match
    cst_builder_choose_rule_slot(parent_frame, child_rule_name) {
    Some(slot) => slot
    None =>
      return Err(
        "failed to infer CST rule slot for child rule `" +
        child_rule_name +
        "` under `" +
        parent_frame.rule.rule_name +
        "`",
      )
  }
  cst_builder_attach_child_with_slot_symbol(
    atn, nodes, parent_frame, slot_symbol, child_id, recovered,
  )
}

///|
fn cst_builder_attach_token_child(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  frame : BuilderRuleFrame,
  slot_id : Int?,
  child_id : CstNodeId,
  recovered : Bool,
) -> Result[BuilderRuleFrame, String] {
  let token_node = match nodes[child_id.0] {
    Token(value) => value
    _ => return Err("expected token child while attaching token")
  }
  let slot_symbol = match
    cst_builder_choose_token_slot(frame, tokens[token_node.token.0], slot_id) {
    Some(value) => value
    None =>
      return Err(
        "failed to infer CST token slot for rule `" + frame.rule.rule_name + "`",
      )
  }
  cst_builder_attach_child_with_slot_symbol(
    atn, nodes, frame, slot_symbol, child_id, recovered,
  )
}

///|
fn cst_pending_child_matches_slot(
  slot : @antlr.GrammarSlotSymbol,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  child : BuilderPendingChild,
) -> Bool {
  match nodes[child.child_id.0] {
    Rule(rule_node) =>
      cst_slot_matches_rule_name(slot, rule_node.rule.rule_name)
    Token(token_node) =>
      cst_token_matches_slot(slot, tokens[token_node.token.0])
    Error(_) => false
  }
}

///|
fn cst_pending_children_fit_alternative(
  slots : Array[@antlr.GrammarSlotSymbol],
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  pending_children : Array[BuilderPendingChild],
) -> Bool {
  let mut slot_index = 0
  for child in pending_children {
    while slot_index < slots.length() {
      match slots[slot_index].source_kind {
        @antlr.ActionSlot => slot_index = slot_index + 1
        @antlr.PredicateSlot => slot_index = slot_index + 1
        _ => break
      }
    }
    if slot_index >= slots.length() {
      return false
    }
    if !cst_pending_child_matches_slot(slots[slot_index], nodes, tokens, child) {
      return false
    }
    if !cst_slot_is_repeatable(slots[slot_index]) {
      slot_index = slot_index + 1
    }
  }
  true
}

///|
fn cst_infer_pending_alternative(
  atn : @antlr.GrammarAtn,
  rule : CstRuleRef,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  pending_children : Array[BuilderPendingChild],
) -> CstAlternativeRef? {
  for alternative in atn.public_alternatives {
    if alternative.rule_id != rule.rule_id {
      continue
    }
    let candidate = {
      rule,
      alternative_index: alternative.alternative_index,
      alternative_label: alternative.label,
    }
    if cst_pending_children_fit_alternative(
        cst_public_slots_for_alternative(atn, candidate),
        nodes,
        tokens,
        pending_children,
      ) {
      return Some(candidate)
    }
  }
  None
}

///|
fn cst_builder_flush_pending_children(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  frame : BuilderRuleFrame,
) -> Result[BuilderRuleFrame, String] {
  let pending_children = cst_copy_pending_children(frame.pending_children)
  let mut current = {
    node_id: frame.node_id,
    rule: frame.rule,
    alternative: frame.alternative,
    ordered_slots: frame.ordered_slots,
    slot_counts: frame.slot_counts,
    last_element_index: frame.last_element_index,
    last_slot_id: frame.last_slot_id,
    pending_children: [],
  }
  for child in pending_children {
    current = match nodes[child.child_id.0] {
      Rule(rule_node) =>
        match
          cst_builder_attach_rule_child(
            atn,
            nodes,
            current,
            child.child_id,
            rule_node.rule.rule_name,
            child.recovered,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      Token(_) =>
        match
          cst_builder_attach_token_child(
            atn,
            nodes,
            tokens,
            current,
            None,
            child.child_id,
            child.recovered,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
      Error(_) =>
        return Err("unexpected error node in pending CST child buffer")
    }
  }
  Ok(current)
}

///|
fn cst_left_recursive_self_slot(
  frame : BuilderRuleFrame,
  ordered_slots : Array[@antlr.GrammarSlotSymbol],
) -> @antlr.GrammarSlotSymbol? {
  for slot in ordered_slots {
    if slot.element_index != 0 {
      continue
    }
    if cst_slot_matches_rule_name(slot, frame.rule.rule_name) {
      return Some(slot)
    }
  }
  None
}

///|
fn cst_builder_materialize_pending_subtree(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  frame : BuilderRuleFrame,
  fallback_span : @antlr.SourceSpan,
) -> Result[CstNodeId, String] {
  let pending_children = cst_copy_pending_children(frame.pending_children)
  let alternative = match
    cst_infer_pending_alternative(
      atn,
      frame.rule,
      nodes,
      tokens,
      pending_children,
    ) {
    Some(value) => value
    None =>
      return Err(
        "failed to infer original alternative for pending CST prefix of `" +
        frame.rule.rule_name +
        "`",
      )
  }
  let node_id = cst_push_node(
    nodes,
    Rule({
      rule: frame.rule,
      alternative: Some(alternative),
      span: cst_span_for_pending_children(
        nodes, tokens, pending_children, fallback_span,
      ),
      children: [],
      recovered: false,
    }),
  )
  let child_frame = {
    node_id,
    rule: frame.rule,
    alternative: Some(alternative),
    ordered_slots: cst_public_slots_for_alternative(atn, alternative),
    slot_counts: [],
    last_element_index: -1,
    last_slot_id: None,
    pending_children,
  }
  match cst_builder_flush_pending_children(atn, nodes, tokens, child_frame) {
    Ok(_) => Ok(node_id)
    Err(error) => Err(error)
  }
}

///|
fn cst_builder_project_left_prefix(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  frame : BuilderRuleFrame,
  target_alternative : CstAlternativeRef,
  self_slot : @antlr.GrammarSlotSymbol,
) -> Result[BuilderRuleFrame, String] {
  let current_rule_node = cst_rule_node_or_abort(nodes, frame.node_id)
  let promoted_child_id = if current_rule_node.children.length() > 0 {
    let current_alternative = match frame.alternative {
      Some(value) => value
      None =>
        return Err(
          "missing current alternative while promoting left-recursive prefix of `" +
          frame.rule.rule_name +
          "`",
        )
    }
    cst_push_node(
      nodes,
      Rule({
        rule: frame.rule,
        alternative: Some(current_alternative),
        span: cst_span_for_attached_children(
          nodes,
          tokens,
          current_rule_node.children,
          current_rule_node.span,
        ),
        children: current_rule_node.children,
        recovered: current_rule_node.recovered,
      }),
    )
  } else {
    match
      cst_builder_materialize_pending_subtree(
        atn,
        nodes,
        tokens,
        frame,
        current_rule_node.span,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  }
  cst_store_rule_node(nodes, frame.node_id, {
    rule: current_rule_node.rule,
    alternative: Some(target_alternative),
    span: current_rule_node.span,
    children: [],
    recovered: false,
  })
  let reset_frame = {
    node_id: frame.node_id,
    rule: frame.rule,
    alternative: Some(target_alternative),
    ordered_slots: cst_public_slots_for_alternative(atn, target_alternative),
    slot_counts: [],
    last_element_index: -1,
    last_slot_id: None,
    pending_children: [],
  }
  cst_builder_attach_child_with_slot_symbol(
    atn,
    nodes,
    reset_frame,
    self_slot,
    promoted_child_id,
    cst_node_recovered(nodes, promoted_child_id),
  )
}

///|
fn cst_builder_finalize_pending_frame(
  atn : @antlr.GrammarAtn,
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  frame : BuilderRuleFrame,
) -> Result[BuilderRuleFrame, String] {
  if frame.pending_children.length() == 0 {
    return Ok(frame)
  }
  let alternative = match frame.alternative {
    Some(value) => value
    None =>
      match
        cst_infer_pending_alternative(
          atn,
          frame.rule,
          nodes,
          tokens,
          frame.pending_children,
        ) {
        Some(value) => value
        None =>
          return Err(
            "failed to infer original alternative for pending CST children of `" +
            frame.rule.rule_name +
            "`",
          )
      }
  }
  let prepared = cst_builder_apply_alternative(atn, frame, alternative)
  let rule_node = cst_rule_node_or_abort(nodes, frame.node_id)
  cst_store_rule_node(nodes, frame.node_id, {
    rule: rule_node.rule,
    alternative: Some(alternative),
    span: rule_node.span,
    children: rule_node.children,
    recovered: rule_node.recovered,
  })
  cst_builder_flush_pending_children(atn, nodes, tokens, prepared)
}

///|
fn cst_builder_project_recovery_kind(
  kind : @antlr_runtime.ParserRecoveryProjectionKind,
) -> CstErrorKind {
  match kind {
    @antlr_runtime.InsertedTokenProjection => InsertedToken
    @antlr_runtime.UnexpectedTokenProjection => UnexpectedToken
    @antlr_runtime.MissingSubtreeProjection => MissingSubtree
    @antlr_runtime.RecoveryFenceProjection => RecoveryFence
  }
}

///|
fn cst_append_synthetic_token(
  tokens : Array[CstTokenRecord],
  projection : @antlr_runtime.ParserRecoveryProjection,
) -> CstTokenId {
  let token_id = CstTokenId(tokens.length())
  tokens.push({
    id: token_id,
    token_kind_id: -1,
    symbolic_name: projection.token_name,
    literal_name: None,
    channel: 0,
    channel_name: "DEFAULT_TOKEN_CHANNEL",
    mode: None,
    lexeme: "",
    span: projection.span,
    synthetic: true,
    implicit_literal: false,
    eof: false,
  })
  token_id
}

///|
fn cst_optional_token_id(
  token_index : Int?,
  tokens : Array[CstTokenRecord],
) -> CstTokenId? {
  match token_index {
    Some(index) =>
      if 0 <= index && index < tokens.length() {
        Some(CstTokenId(index))
      } else {
        None
      }
    None => None
  }
}

///|
fn cst_builder_add_recovery_nodes(
  nodes : Array[CstNode],
  tokens : Array[CstTokenRecord],
  result : @antlr_runtime.ParserRunResult,
) -> Array[CstRecoveryEvent] {
  let recovery_events : Array[CstRecoveryEvent] = []
  for
    projection in @antlr_runtime.project_parser_recoveries(
      result.recovery_events,
    ) {
    let token_id = if projection.requires_synthetic_token {
      Some(cst_append_synthetic_token(tokens, projection))
    } else {
      cst_optional_token_id(projection.token_index, tokens)
    }
    let node_id = cst_push_node(
      nodes,
      Error({
        kind: cst_builder_project_recovery_kind(projection.public_kind),
        span: projection.span,
        message: Some(projection.message),
        expected: [],
      }),
    )
    recovery_events.push({
      kind: cst_builder_project_recovery_kind(projection.public_kind),
      detail_kind: projection.detail_kind,
      span: projection.span,
      node: Some(node_id),
      token: token_id,
      visible_offset: projection.visible_offset,
      message: Some(projection.message),
    })
  }
  if recovery_events.length() == 0 && result.diagnostics.length() > 0 {
    for diagnostic in result.diagnostics {
      let node_id = cst_push_node(
        nodes,
        Error({
          kind: MissingSubtree,
          span: diagnostic.span,
          message: Some(diagnostic.message),
          expected: [],
        }),
      )
      recovery_events.push({
        kind: MissingSubtree,
        detail_kind: "diagnostic",
        span: diagnostic.span,
        node: Some(node_id),
        token: None,
        visible_offset: 0,
        message: Some(diagnostic.message),
      })
    }
  }
  recovery_events
}

///|
/// Build one versioned generic CST document from the stable Phase 1 ATN contract and one Phase 3 parser run.
///
/// Example:
/// let result = @antlr_runtime.parse_with_atn(atn, lexer_result.tokens, @antlr_runtime.ParserHostHooks::empty())
/// let document = build_cst_document(atn, result)
/// inspect(document is Ok(_), content="true")
///
/// Notes:
/// - The builder consumes only public grammar metadata plus parser events/recovery records; it does not inspect parser-internal stacks.
/// - The returned document always preserves the full token table, even when parse recovery or diagnostics are present.
pub fn build_cst_document(
  atn : @antlr.GrammarAtn,
  result : @antlr_runtime.ParserRunResult,
) -> Result[CstDocument, String] {
  let nodes : Array[CstNode] = []
  let tokens = cst_build_token_records(atn, result.tokens)
  let frames : Array[BuilderRuleFrame] = []
  let mut open_count = 0
  let mut root_id : CstNodeId? = None
  for event in result.events {
    match event.kind {
      @antlr_runtime.EnterRule => {
        let depth = event.depth
        let rule_id = match event.rule_id {
          Some(value) => value
          None => return Err("missing rule id on enter-rule event")
        }
        let rule_ref = match cst_public_rule_ref(atn, rule_id) {
          Some(value) => value
          None =>
            return Err(
              "missing public rule metadata for rule id " + rule_id.to_string(),
            )
        }
        let node_id = cst_push_node(
          nodes,
          Rule({
            rule: rule_ref,
            alternative: None,
            span: event.span,
            children: [],
            recovered: event.recovered,
          }),
        )
        if depth == 0 {
          root_id = Some(node_id)
        } else {
          if depth - 1 >= open_count {
            return Err(
              "invalid CST builder depth while entering `" +
              rule_ref.rule_name +
              "`",
            )
          }
          let parent_frame = frames[depth - 1]
          match parent_frame.alternative {
            Some(_) =>
              match
                cst_builder_attach_rule_child(
                  atn,
                  nodes,
                  parent_frame,
                  node_id,
                  rule_ref.rule_name,
                  event.recovered,
                ) {
                Ok(updated_parent) => frames[depth - 1] = updated_parent
                Err(error) => return Err(error)
              }
            None =>
              frames[depth - 1] = cst_builder_buffer_child(
                parent_frame,
                node_id,
                event.recovered,
              )
          }
        }
        let frame = {
          node_id,
          rule: rule_ref,
          alternative: None,
          ordered_slots: [],
          slot_counts: [],
          last_element_index: -1,
          last_slot_id: None,
          pending_children: [],
        }
        if depth < frames.length() {
          frames[depth] = frame
        } else {
          frames.push(frame)
        }
        open_count = depth + 1
      }
      @antlr_runtime.CommitAlternative => {
        let depth = event.depth
        if depth >= open_count {
          return Err("invalid commit-alt depth " + depth.to_string())
        }
        let alternative_index = match event.alternative_index {
          Some(value) => value
          None => return Err("missing alternative index on commit-alt event")
        }
        let frame = frames[depth]
        let alternative = match
          cst_public_alternative_ref(atn, frame.rule, alternative_index) {
          Some(value) => value
          None =>
            return Err(
              "missing public alternative metadata for rule `" +
              frame.rule.rule_name +
              "` alt " +
              alternative_index.to_string(),
            )
        }
        let rule_node = cst_rule_node_or_abort(nodes, frame.node_id)
        let ordered_slots = cst_public_slots_for_alternative(atn, alternative)
        match cst_left_recursive_self_slot(frame, ordered_slots) {
          Some(self_slot) =>
            if frame.pending_children.length() > 0 ||
              (frame.alternative is Some(_) && rule_node.children.length() > 0) {
              match
                cst_builder_project_left_prefix(
                  atn, nodes, tokens, frame, alternative, self_slot,
                ) {
                Ok(updated_frame) => frames[depth] = updated_frame
                Err(error) => return Err(error)
              }
            } else {
              let prepared_frame = {
                node_id: frame.node_id,
                rule: frame.rule,
                alternative: Some(alternative),
                ordered_slots,
                slot_counts: frame.slot_counts,
                last_element_index: frame.last_element_index,
                last_slot_id: frame.last_slot_id,
                pending_children: frame.pending_children,
              }
              cst_store_rule_node(nodes, frame.node_id, {
                rule: rule_node.rule,
                alternative: Some(alternative),
                span: rule_node.span,
                children: rule_node.children,
                recovered: rule_node.recovered,
              })
              match
                cst_builder_flush_pending_children(
                  atn, nodes, tokens, prepared_frame,
                ) {
                Ok(updated_frame) => frames[depth] = updated_frame
                Err(error) => return Err(error)
              }
            }
          None => {
            let prepared_frame = {
              node_id: frame.node_id,
              rule: frame.rule,
              alternative: Some(alternative),
              ordered_slots,
              slot_counts: frame.slot_counts,
              last_element_index: frame.last_element_index,
              last_slot_id: frame.last_slot_id,
              pending_children: frame.pending_children,
            }
            cst_store_rule_node(nodes, frame.node_id, {
              rule: rule_node.rule,
              alternative: Some(alternative),
              span: rule_node.span,
              children: rule_node.children,
              recovered: rule_node.recovered,
            })
            match
              cst_builder_flush_pending_children(
                atn, nodes, tokens, prepared_frame,
              ) {
              Ok(updated_frame) => frames[depth] = updated_frame
              Err(error) => return Err(error)
            }
          }
        }
      }
      @antlr_runtime.ConsumeToken => {
        let depth = event.depth
        if depth >= open_count {
          return Err("invalid consume-token depth " + depth.to_string())
        }
        let token_index = match event.token_index {
          Some(value) => value
          None => return Err("missing token index on consume-token event")
        }
        let token_id = cst_optional_token_id(Some(token_index), tokens)
        let actual_token_id = match token_id {
          Some(value) => value
          None =>
            return Err(
              "invalid token index " +
              token_index.to_string() +
              " on consume-token event",
            )
        }
        let frame = frames[depth]
        let with_alternative = match event.alternative_index {
          Some(alternative_index) =>
            match
              cst_builder_ensure_alternative_from_index(
                atn, frame, alternative_index,
              ) {
              Ok(value) => value
              Err(error) => return Err(error)
            }
          None => frame
        }
        let prepared_frame = if with_alternative.alternative is Some(_) &&
          with_alternative.pending_children.length() > 0 {
          match
            cst_builder_finalize_pending_frame(
              atn, nodes, tokens, with_alternative,
            ) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
        } else {
          with_alternative
        }
        let token_record = tokens[actual_token_id.0]
        let child_id = cst_push_node(
          nodes,
          Token({
            token: actual_token_id,
            span: token_record.span,
            implicit_literal: token_record.implicit_literal,
          }),
        )
        match prepared_frame.alternative {
          Some(_) =>
            match
              cst_builder_attach_token_child(
                atn,
                nodes,
                tokens,
                prepared_frame,
                event.slot_id,
                child_id,
                event.recovered,
              ) {
              Ok(updated_frame) => frames[depth] = updated_frame
              Err(error) => return Err(error)
            }
          None =>
            frames[depth] = cst_builder_buffer_child(
              prepared_frame,
              child_id,
              event.recovered,
            )
        }
      }
      @antlr_runtime.ExitRule => {
        let depth = event.depth
        if depth >= open_count {
          return Err("invalid exit-rule depth " + depth.to_string())
        }
        let frame = match
          cst_builder_finalize_pending_frame(atn, nodes, tokens, frames[depth]) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        frames[depth] = frame
        let rule_node = cst_rule_node_or_abort(nodes, frame.node_id)
        let recovered = rule_node.recovered || event.recovered
        cst_store_rule_node(nodes, frame.node_id, {
          rule: rule_node.rule,
          alternative: rule_node.alternative,
          span: event.span,
          children: rule_node.children,
          recovered,
        })
        if recovered && depth > 0 {
          cst_mark_parent_edge_recovered(
            nodes,
            frames[depth - 1].node_id,
            frame.node_id,
          )
        }
        open_count = depth
      }
      _ => ()
    }
  }
  let root = match root_id {
    Some(value) => value
    None => return Err("missing CST root rule node")
  }
  let recovery_events = cst_builder_add_recovery_nodes(nodes, tokens, result)
  if recovery_events.length() > 0 || result.diagnostics.length() > 0 {
    cst_mark_rule_node_recovered(nodes, root)
  }
  let start_rule = match cst_public_rule_ref(atn, result.start_rule_id) {
    Some(value) => value
    None =>
      return Err(
        "missing public start-rule metadata for rule id " +
        result.start_rule_id.to_string(),
      )
  }
  Ok({
    schema_version: cst_schema_version_v1,
    grammar: {
      grammar_name: atn.grammar_name,
      grammar_kind: atn.grammar_kind,
      start_rule,
      fingerprint: CstGrammarFingerprint(atn.grammar_fingerprint),
    },
    root,
    nodes,
    tokens,
    recovery_events,
  })
}
