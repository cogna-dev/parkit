///|
fn first_present_token(
  candidates : Array[@antlr_tcst.TerminalToken?],
) -> @antlr_tcst.TerminalToken? {
  for candidate in candidates {
    match candidate {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn last_present_token(
  candidates : Array[@antlr_tcst.TerminalToken?],
) -> @antlr_tcst.TerminalToken? {
  let mut index = candidates.length() - 1
  while candidates.length() > 0 && index >= 0 {
    match candidates[index] {
      Some(value) => return Some(value)
      None => ()
    }
    if index == 0 {
      break
    }
    index = index - 1
  }
  None
}

///|
fn lower_expr_add(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[ExprNode, LoweringError] {
  let expr_1_slot_values = match
    @antlr_tcst.rule_children_for_slot(document, handle, 0, "expr") {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let expr_1_node_id = match
    @antlr_tcst.required_value(
      expr_1_slot_values,
      "expr",
      0,
      "expr_1",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let expr_1 = match lower_expr_node(document, expr_1_node_id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let plus_token_slot_values = match
    @antlr_tcst.token_children_for_slot(document, handle, 1, None, Some("'+'")) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let plus_token = match
    @antlr_tcst.required_value(
      plus_token_slot_values,
      "expr",
      1,
      "plus_token",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let expr_2_slot_values = match
    @antlr_tcst.rule_children_for_slot(document, handle, 2, "expr") {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let expr_2_node_id = match
    @antlr_tcst.required_value(
      expr_2_slot_values,
      "expr",
      2,
      "expr_2",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let expr_2 = match lower_expr_node(document, expr_2_node_id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let span = @antlr_cst.node_span(document, handle.node_id)
  let first_token = first_present_token([
    expr_1.first_token(),
    Some(plus_token),
    expr_2.first_token(),
  ])
  let last_token = last_present_token([
    expr_1.last_token(),
    Some(plus_token),
    expr_2.last_token(),
  ])
  Ok(Add({ span, first_token, last_token, expr_1, plus_token, expr_2 }))
}

///|
fn lower_expr_atom(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[ExprNode, LoweringError] {
  let int_token_slot_values = match
    @antlr_tcst.token_children_for_slot(document, handle, 0, Some("INT"), None) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let int_token = match
    @antlr_tcst.required_value(
      int_token_slot_values,
      "expr",
      0,
      "int_token",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let span = @antlr_cst.node_span(document, handle.node_id)
  let first_token = first_present_token([Some(int_token)])
  let last_token = last_present_token([Some(int_token)])
  Ok(Atom({ span, first_token, last_token, int_token }))
}

///|
fn lower_expr_node_from_handle(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[ExprNode, LoweringError] {
  match @antlr_tcst.checked_alternative(handle, [1, 2]) {
    Ok(1) => lower_expr_add(document, handle)
    Ok(2) => lower_expr_atom(document, handle)
    Ok(_) => abort("unexpected typed alternative dispatch")
    Err(error) => Err(error)
  }
}

///|
/// Lower one `expr` rule node from the generic CST document into `ExprNode`.
///
/// Example:
/// let lowered = lower_expr_node(document, document.root)
/// inspect(lowered is Ok(_), content="true")
///
/// Notes:
/// - The node id must refer to a rule node from the same `CstDocument`.
/// - Strict lowering rejects schema drift and recovery artifacts before constructing typed values.
fn lower_expr_node(
  document : @antlr_cst.CstDocument,
  node_id : @antlr_cst.CstNodeId,
) -> Result[ExprNode, LoweringError] {
  match @antlr_tcst.checked_rule(document, node_id, "expr") {
    Ok(handle) => lower_expr_node_from_handle(document, handle)
    Err(error) => Err(error)
  }
}

///|
/// Check whether one generic CST document matches this generated typed package.
///
/// Example:
/// inspect(document_matches(document), content="true")
///
/// Notes:
/// - The probe checks grammar identity and schema version only.
/// - Strict lowering still rejects recovery artifacts even when this probe returns `true`.
fn document_matches(document : @antlr_cst.CstDocument) -> Bool {
  @antlr_tcst.typed_document_matches(document, typed_grammar_info)
}

///|
/// Lower the start rule of one matching generic CST document into the generated root type.
///
/// Example:
/// let lowered = lower_root(document)
/// inspect(lowered is Ok(_), content="true")
///
/// Notes:
/// - The function enforces strict lowering and fails on schema drift or recovery artifacts.
/// - The returned root type always matches the grammar start rule captured in `typed_grammar_info`.
fn lower_root(
  document : @antlr_cst.CstDocument,
) -> Result[RootNode, LoweringError] {
  match @antlr_tcst.checked_root_rule(document, typed_grammar_info) {
    Ok(handle) => lower_expr_node_from_handle(document, handle)
    Err(error) => Err(error)
  }
}
