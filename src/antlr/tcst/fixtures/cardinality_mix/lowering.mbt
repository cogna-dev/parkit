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
fn lower_root_alt1(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[RootNode, LoweringError] {
  let maybe_slot_values = match
    @antlr_tcst.token_children_for_slot(
      document,
      handle,
      0,
      Some("MAYBE"),
      None,
    ) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let maybe = match
    @antlr_tcst.optional_value(
      maybe_slot_values,
      "root",
      0,
      "maybe",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let many_slot_values = match
    @antlr_tcst.token_children_for_slot(document, handle, 1, Some("ITEM"), None) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let many = many_slot_values
  let some_slot_values = match
    @antlr_tcst.token_children_for_slot(document, handle, 2, Some("REQ"), None) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  let some = match
    @antlr_tcst.non_empty_value(
      some_slot_values,
      "root",
      2,
      "some",
      handle.node_id,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let span = @antlr_cst.node_span(document, handle.node_id)
  let first_token = first_present_token([
    maybe,
    if many.length() > 0 {
      Some(many[0])
    } else {
      None
    },
    Some(some.head),
  ])
  let last_token = last_present_token([
    maybe,
    if many.length() > 0 {
      Some(many[many.length() - 1])
    } else {
      None
    },
    if some.tail.length() > 0 {
      Some(some.tail[some.tail.length() - 1])
    } else {
      Some(some.head)
    },
  ])
  Ok(Alt1({ span, first_token, last_token, maybe, many, some }))
}

///|
fn lower_root_node_from_handle(
  document : @antlr_cst.CstDocument,
  handle : @antlr_tcst.TypedRuleHandle,
) -> Result[RootNode, LoweringError] {
  match @antlr_tcst.checked_alternative(handle, [1]) {
    Ok(1) => lower_root_alt1(document, handle)
    Ok(_) => abort("unexpected typed alternative dispatch")
    Err(error) => Err(error)
  }
}

///|
/// Lower one `root` rule node from the generic CST document into `RootNode`.
///
/// Example:
/// let lowered = lower_root_node(document, document.root)
/// inspect(lowered is Ok(_), content="true")
///
/// Notes:
/// - The node id must refer to a rule node from the same `CstDocument`.
/// - Strict lowering rejects schema drift and recovery artifacts before constructing typed values.
fn lower_root_node(
  document : @antlr_cst.CstDocument,
  node_id : @antlr_cst.CstNodeId,
) -> Result[RootNode, LoweringError] {
  match @antlr_tcst.checked_rule(document, node_id, "root") {
    Ok(handle) => lower_root_node_from_handle(document, handle)
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
    Ok(handle) => lower_root_node_from_handle(document, handle)
    Err(error) => Err(error)
  }
}
