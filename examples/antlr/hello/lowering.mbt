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
fn lower_r_alt1(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[RNode, LoweringError] {
  let hello_token_slot_values = match
    @antlr_tcst.token_children_for_slot(
      document,
      handle,
      0,
      None,
      Some("'hello'"),
    ) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let hello_token = match
    @antlr_tcst.required_value(
      hello_token_slot_values,
      "r",
      0,
      "hello_token",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let id_token_slot_values = match
    @antlr_tcst.token_children_for_slot(document, handle, 1, Some("ID"), None) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let id_token = match
    @antlr_tcst.required_value(
      id_token_slot_values,
      "r",
      1,
      "id_token",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let span = @antlr_cst.node_span(document, handle.node_id)
  let first_token = first_present_token([Some(hello_token), Some(id_token)])
  let last_token = last_present_token([Some(hello_token), Some(id_token)])
  Ok(Alt1({ span, first_token, last_token, hello_token, id_token }))
}

///|
fn lower_r_node_from_handle(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[RNode, LoweringError] {
  match @antlr_tcst.checked_alternative(handle, [1]) {
    Ok(1) => lower_r_alt1(document, handle)
    Ok(_) => abort("unexpected typed alternative dispatch")
    Err(error) => Err(error)
  }
}

///|
/// Lower one `r` rule node from the generic CST document into `RNode`.
///
/// Example:
/// let lowered = lower_r_node(document, document.root)
/// inspect(lowered is Ok(_), content="true")
///
/// Notes:
/// - The node id must refer to a rule node from the same `CstDocument`.
/// - Strict lowering rejects schema drift and recovery artifacts before constructing typed values.
fn lower_r_node(
  document : @antlr_cst.CstDocument,
  node_id : @antlr_cst.CstNodeId,
) -> Result[RNode, LoweringError] {
  match @antlr_tcst.checked_rule(document, node_id, "r") {
    Ok(handle) => lower_r_node_from_handle(document, handle)
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
    Ok(handle) => lower_r_node_from_handle(document, handle)
    Err(error) => Err(error)
  }
}
