///|
/// Checked rule handle shared by generated typed CST lowerings.
pub(all) struct TypedRuleHandle {
  node_id : @antlr_cst.CstNodeId
  rule_node : @antlr_cst.CstRuleNode
}

///|
fn typed_same_grammar_kind(
  left : @antlr.GrammarKind,
  right : @antlr.GrammarKind,
) -> Bool {
  match left {
    @antlr.Combined =>
      match right {
        @antlr.Combined => true
        _ => false
      }
    @antlr.Lexer =>
      match right {
        @antlr.Lexer => true
        _ => false
      }
    @antlr.Parser =>
      match right {
        @antlr.Parser => true
        _ => false
      }
  }
}

///|
fn typed_node_kind_name(node : @antlr_cst.CstNode) -> String {
  match node {
    @antlr_cst.Rule(rule_node) => "rule:" + rule_node.rule.rule_name
    @antlr_cst.Token(_) => "token"
    @antlr_cst.Error(_) => "error"
  }
}

///|
fn typed_token_name(record : @antlr_cst.CstTokenRecord) -> String? {
  match record.literal_name {
    Some(value) => Some(value)
    None => record.symbolic_name
  }
}

///|
fn typed_expected_token_name(
  symbolic_name : String?,
  literal_name : String?,
) -> String {
  match literal_name {
    Some(value) => value
    None =>
      match symbolic_name {
        Some(value) => value
        None => "token"
      }
  }
}

///|
fn typed_contains_int(values : Array[Int], wanted : Int) -> Bool {
  for value in values {
    if value == wanted {
      return true
    }
  }
  false
}

///|
fn typed_document_has_recovery(document : @antlr_cst.CstDocument) -> Bool {
  document.recovery_events.length() > 0
}

///|
/// Check whether one generic CST document matches the grammar identity of a generated typed package.
///
/// Example:
/// let ok = typed_document_matches(document, grammar_info)
/// inspect(ok, content="true")
///
/// Notes:
/// - The probe checks schema version, grammar name, grammar kind, start rule, and fingerprint.
/// - Recovery artifacts are intentionally ignored here; strict lowering reports them separately.
pub fn typed_document_matches(
  document : @antlr_cst.CstDocument,
  grammar_info : TypedGrammarInfo,
) -> Bool {
  document.schema_version.0 == grammar_info.cst_schema_version &&
  document.grammar.grammar_name == grammar_info.grammar_name &&
  typed_same_grammar_kind(
    document.grammar.grammar_kind,
    grammar_info.grammar_kind,
  ) &&
  document.grammar.start_rule.rule_name == grammar_info.start_rule_name &&
  document.grammar.fingerprint.0 == grammar_info.grammar_fingerprint
}

///|
/// Validate one CST document against generated grammar metadata and return its checked root rule.
///
/// Example:
/// let handle = checked_root_rule(document, grammar_info)
/// inspect(handle is Ok(_), content="true")
///
/// Notes:
/// - The helper enforces schema version, fingerprint, and start-rule identity before strict lowering starts.
/// - Recovery artifacts on the document or root rule are rejected immediately.
pub fn checked_root_rule(
  document : @antlr_cst.CstDocument,
  grammar_info : TypedGrammarInfo,
) -> Result[TypedRuleHandle, TcstLoweringError] {
  if document.schema_version.0 != grammar_info.cst_schema_version {
    return Err(
      SchemaVersionMismatch(
        grammar_info.cst_schema_version,
        document.schema_version.0,
      ),
    )
  }
  if document.grammar.fingerprint.0 != grammar_info.grammar_fingerprint {
    return Err(
      GrammarFingerprintMismatch(
        grammar_info.grammar_fingerprint,
        document.grammar.fingerprint.0,
      ),
    )
  }
  if !typed_same_grammar_kind(
      document.grammar.grammar_kind,
      grammar_info.grammar_kind,
    ) {
    return Err(
      RootRuleMismatch(
        grammar_info.start_rule_name,
        document.grammar.start_rule.rule_name,
      ),
    )
  }
  if document.grammar.start_rule.rule_name != grammar_info.start_rule_name {
    return Err(
      RootRuleMismatch(
        grammar_info.start_rule_name,
        document.grammar.start_rule.rule_name,
      ),
    )
  }
  match @antlr_cst.node(document, document.root) {
    @antlr_cst.Rule(rule_node) => {
      if rule_node.rule.rule_name != grammar_info.start_rule_name {
        return Err(
          RootRuleMismatch(
            grammar_info.start_rule_name,
            rule_node.rule.rule_name,
          ),
        )
      }
      if typed_document_has_recovery(document) || rule_node.recovered {
        return Err(
          RecoveryArtifactPresent(grammar_info.start_rule_name, document.root),
        )
      }
      Ok({ node_id: document.root, rule_node })
    }
    node =>
      Err(
        NodeKindMismatch(
          "rule:" + grammar_info.start_rule_name,
          typed_node_kind_name(node),
          document.root,
        ),
      )
  }
}

///|
/// Validate one CST node id as an exact rule node for strict typed lowering.
///
/// Example:
/// let handle = checked_rule(document, document.root, "expr")
/// inspect(handle is Ok(_), content="true")
///
/// Notes:
/// - The node id must come from the same `CstDocument`.
/// - Any recovery artifact on the document, edge set, or target rule is treated as a strict-lowering failure.
pub fn checked_rule(
  document : @antlr_cst.CstDocument,
  node_id : @antlr_cst.CstNodeId,
  expected_rule_name : String,
) -> Result[TypedRuleHandle, TcstLoweringError] {
  match @antlr_cst.node(document, node_id) {
    @antlr_cst.Rule(rule_node) => {
      if rule_node.rule.rule_name != expected_rule_name {
        return Err(
          NodeKindMismatch(
            "rule:" + expected_rule_name,
            "rule:" + rule_node.rule.rule_name,
            node_id,
          ),
        )
      }
      if typed_document_has_recovery(document) || rule_node.recovered {
        return Err(RecoveryArtifactPresent(expected_rule_name, node_id))
      }
      Ok({ node_id, rule_node })
    }
    node =>
      Err(
        NodeKindMismatch(
          "rule:" + expected_rule_name,
          typed_node_kind_name(node),
          node_id,
        ),
      )
  }
}

///|
/// Validate the active alternative on one checked rule handle.
///
/// Example:
/// let alternative = checked_alternative(handle, [1, 2])
/// inspect(alternative is Ok(_), content="true")
///
/// Notes:
/// - Generated typed packages use this helper to dispatch onto one original grammar alternative.
/// - Missing alternative metadata is reported as structured drift instead of being guessed.
pub fn checked_alternative(
  handle : TypedRuleHandle,
  expected_alternatives : Array[Int],
) -> Result[Int, TcstLoweringError] {
  match handle.rule_node.alternative {
    Some(alternative) =>
      if typed_contains_int(
          expected_alternatives,
          alternative.alternative_index,
        ) {
        Ok(alternative.alternative_index)
      } else {
        Err(
          AlternativeMismatch(
            handle.rule_node.rule.rule_name,
            expected_alternatives,
            Some(alternative.alternative_index),
            handle.node_id,
          ),
        )
      }
    None =>
      Err(
        AlternativeMismatch(
          handle.rule_node.rule.rule_name,
          expected_alternatives,
          None,
          handle.node_id,
        ),
      )
  }
}

///|
/// Collect typed terminal tokens from one checked slot on a rule node.
///
/// Example:
/// let tokens = token_children_for_slot(document, handle, 0, Some("ID"), None)
/// inspect(tokens is Ok(_), content="true")
///
/// Notes:
/// - Synthetic tokens and error nodes are rejected as recovery artifacts under strict lowering.
/// - When `expected_literal_name` is present, it takes precedence over symbolic-name matching.
pub fn token_children_for_slot(
  document : @antlr_cst.CstDocument,
  handle : TypedRuleHandle,
  slot_id : Int,
  expected_symbolic_name : String?,
  expected_literal_name : String?,
) -> Result[Array[TerminalToken], TcstLoweringError] {
  let tokens : Array[TerminalToken] = []
  for edge in @antlr_cst.children_by_slot(document, handle.node_id, slot_id) {
    if edge.recovered {
      return Err(
        RecoveryArtifactPresent(handle.rule_node.rule.rule_name, handle.node_id),
      )
    }
    match @antlr_cst.node(document, edge.child) {
      @antlr_cst.Token(token_node) => {
        let record = @antlr_cst.token(document, token_node.token)
        if record.synthetic {
          return Err(
            RecoveryArtifactPresent(
              handle.rule_node.rule.rule_name,
              handle.node_id,
            ),
          )
        }
        let expected_name = typed_expected_token_name(
          expected_symbolic_name, expected_literal_name,
        )
        let matches = match expected_literal_name {
          Some(literal_name) => record.literal_name == Some(literal_name)
          None =>
            match expected_symbolic_name {
              Some(symbolic_name) => record.symbolic_name == Some(symbolic_name)
              None => true
            }
        }
        if !matches {
          return Err(
            TokenKindMismatch(
              expected_name,
              typed_token_name(record),
              edge.child,
            ),
          )
        }
        tokens.push(terminal_token_from_record(record))
      }
      @antlr_cst.Rule(rule_node) =>
        return Err(
          NodeKindMismatch(
            "token",
            "rule:" + rule_node.rule.rule_name,
            edge.child,
          ),
        )
      @antlr_cst.Error(_) =>
        return Err(
          RecoveryArtifactPresent(
            handle.rule_node.rule.rule_name,
            handle.node_id,
          ),
        )
    }
  }
  Ok(tokens)
}

///|
/// Collect child rule node ids from one checked slot on a rule node.
///
/// Example:
/// let children = rule_children_for_slot(document, handle, 0, "expr")
/// inspect(children is Ok(_), content="true")
///
/// Notes:
/// - Error nodes and recovered edges are rejected under strict lowering.
/// - Each child must already expose the expected original public rule name.
pub fn rule_children_for_slot(
  document : @antlr_cst.CstDocument,
  handle : TypedRuleHandle,
  slot_id : Int,
  expected_rule_name : String,
) -> Result[Array[@antlr_cst.CstNodeId], TcstLoweringError] {
  let child_nodes : Array[@antlr_cst.CstNodeId] = []
  for edge in @antlr_cst.children_by_slot(document, handle.node_id, slot_id) {
    if edge.recovered {
      return Err(
        RecoveryArtifactPresent(handle.rule_node.rule.rule_name, handle.node_id),
      )
    }
    match @antlr_cst.node(document, edge.child) {
      @antlr_cst.Rule(rule_node) => {
        if rule_node.rule.rule_name != expected_rule_name {
          return Err(
            NodeKindMismatch(
              "rule:" + expected_rule_name,
              "rule:" + rule_node.rule.rule_name,
              edge.child,
            ),
          )
        }
        child_nodes.push(edge.child)
      }
      @antlr_cst.Token(_) =>
        return Err(
          NodeKindMismatch("rule:" + expected_rule_name, "token", edge.child),
        )
      @antlr_cst.Error(_) =>
        return Err(
          RecoveryArtifactPresent(
            handle.rule_node.rule.rule_name,
            handle.node_id,
          ),
        )
    }
  }
  Ok(child_nodes)
}

///|
/// Require exactly one lowered value for one strict typed field.
///
/// Example:
/// let value = required_value(values, "expr", 0, "left", handle.node_id)
/// inspect(value is Ok(_), content="true")
///
/// Notes:
/// - Zero values report `RequiredChildMissing`.
/// - More than one value reports `CardinalityViolation`.
pub fn[T] required_value(
  values : Array[T],
  rule_name : String,
  slot_id : Int,
  field_name : String,
  node_id : @antlr_cst.CstNodeId,
) -> Result[T, TcstLoweringError] {
  if values.length() == 0 {
    return Err(RequiredChildMissing(rule_name, slot_id, field_name, node_id))
  }
  if values.length() != 1 {
    return Err(
      CardinalityViolation(
        rule_name,
        slot_id,
        "required",
        values.length(),
        node_id,
      ),
    )
  }
  Ok(values[0])
}

///|
/// Require zero or one lowered value for one strict typed field.
///
/// Example:
/// let value = optional_value(values, "expr", 0, "operand", handle.node_id)
/// inspect(value is Ok(_), content="true")
///
/// Notes:
/// - Empty arrays become `Ok(None)`.
/// - More than one value reports `CardinalityViolation`.
pub fn[T] optional_value(
  values : Array[T],
  rule_name : String,
  slot_id : Int,
  field_name : String,
  node_id : @antlr_cst.CstNodeId,
) -> Result[T?, TcstLoweringError] {
  ignore(field_name)
  if values.length() == 0 {
    return Ok(None)
  }
  if values.length() != 1 {
    return Err(
      CardinalityViolation(
        rule_name,
        slot_id,
        "optional",
        values.length(),
        node_id,
      ),
    )
  }
  Ok(Some(values[0]))
}

///|
/// Require at least one lowered value and wrap the result in `NonEmpty[T]`.
///
/// Example:
/// let value = non_empty_value(values, "expr", 0, "operands", handle.node_id)
/// inspect(value is Ok(_), content="true")
///
/// Notes:
/// - Empty arrays report `RequiredChildMissing`.
/// - The helper preserves source order through the returned `NonEmpty[T]` value.
pub fn[T] non_empty_value(
  values : Array[T],
  rule_name : String,
  slot_id : Int,
  field_name : String,
  node_id : @antlr_cst.CstNodeId,
) -> Result[NonEmpty[T], TcstLoweringError] {
  match non_empty_from_array(values) {
    Some(value) => Ok(value)
    None => Err(RequiredChildMissing(rule_name, slot_id, field_name, node_id))
  }
}
